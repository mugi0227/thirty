"""Reuse a distribution identity. Create only matching App Store profiles."""
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import secrets
import shlex
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

from cryptography import x509
from cryptography.hazmat.primitives import hashes
import jwt
import yaml

TEAM = '572NVCGLGQ'
CERTIFICATE_ID = 'C88N5HN296'
FINGERPRINT = '4FD79A6E11CC148375A255FA7FCBD9D9B26641B0'
API = 'https://api.appstoreconnect.apple.com'
TARGETS = [('Thirty', 'jp.mugilab.thirty', 'Thirty CI App Store'),
           ('ThirtyWidgets', 'jp.mugilab.thirty.widgets', 'Thirty Widgets CI App Store')]


def main():
    password = os.environ['THIRTY_SIGNING_PASSWORD']
    keychain_password = secrets.token_urlsafe(32)
    temp = Path(os.environ['RUNNER_TEMP'])

    def run(args):
        result = subprocess.run(args, text=True, capture_output=True, check=False)
        if result.returncode:
            message = result.stderr.replace(password, '***').replace(keychain_password, '***')
            raise RuntimeError(args[0] + ' failed: ' + message)
        return result.stdout

    now = int(time.time())
    token = jwt.encode({'iss': os.environ['ASC_ISSUER_ID'], 'iat': now,
                        'exp': now + 600, 'aud': 'appstoreconnect-v1'},
        Path(os.environ['ASC_KEY_PATH']).read_text(), algorithm='ES256',
        headers={'kid': os.environ['ASC_KEY_ID'], 'typ': 'JWT'})

    def api(path, data=None):
        assert path.startswith('/v1/')
        request = urllib.request.Request(API + path,
            data=json.dumps(data).encode() if data is not None else None,
            headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    certificate = api('/v1/certificates/' + CERTIFICATE_ID)['data']['attributes']
    certificate_bytes = base64.b64decode(certificate['certificateContent'])
    cert = x509.load_der_x509_certificate(certificate_bytes)
    assert cert.fingerprint(hashes.SHA1()).hex().upper() == FINGERPRINT
    assert cert.not_valid_after_utc > datetime.now(timezone.utc)

    keychain = temp / 'thirty-distribution.keychain-db'
    previous_keychains = shlex.split(run(['security', 'list-keychains', '-d', 'user']))
    run(['security', 'create-keychain', '-p', keychain_password, str(keychain)])
    with Path(os.environ['GITHUB_ENV']).open('a') as output:
        output.write('THIRTY_SIGNING_KEYCHAIN=' + str(keychain) + '\n')
    run(['security', 'set-keychain-settings', '-lut', '21600', str(keychain)])
    run(['security', 'unlock-keychain', '-p', keychain_password, str(keychain)])
    with tempfile.NamedTemporaryFile(dir=temp, suffix='.p12', delete=False) as output:
        output.write(base64.b64decode(os.environ['THIRTY_SIGNING_P12'], validate=True))
        p12_path = Path(output.name)
    try:
        run(['security', 'import', str(p12_path), '-k', str(keychain), '-P', password,
             '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'])
    finally:
        p12_path.unlink(missing_ok=True)
    run(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:',
         '-s', '-k', keychain_password, str(keychain)])
    run(['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *previous_keychains])
    intermediate = temp / 'AppleWWDRCAG3.cer'
    with urllib.request.urlopen('https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer', timeout=30) as response:
        intermediate.write_bytes(response.read())
    run(['security', 'import', str(intermediate), '-k', str(keychain)])
    assert FINGERPRINT in run(['security', 'find-identity', '-v', '-p', 'codesigning', str(keychain)])

    project_path = Path('ios/project.yml')
    project = yaml.safe_load(project_path.read_text())
    export_profiles = {}
    for target, identifier, profile_name in TARGETS:
        query = urllib.parse.urlencode({'filter[identifier]': identifier})
        bundles = api('/v1/bundleIds?' + query)['data']
        bundle = next(item for item in bundles if item['attributes']['identifier'] == identifier)
        if target == 'Thirty':
            capabilities = api('/v1/bundleIds/' + bundle['id'] + '/bundleIdCapabilities')['data']
            assert any(item['attributes']['capabilityType'] == 'IN_APP_PURCHASE' for item in capabilities)
        profiles = []
        path = '/v1/bundleIds/' + bundle['id'] + '/profiles?limit=200'
        while path:
            page = api(path)
            profiles.extend(page['data'])
            link = page.get('links', {}).get('next')
            assert not link or link.startswith(API + '/v1/')
            path = link[len(API):] if link else None
        profile = next((item for item in profiles if item['attributes']['name'] == profile_name
                        and item['attributes']['profileState'] == 'ACTIVE'
                        and item['attributes']['profileType'] == 'IOS_APP_STORE'), None)
        if profile is None:
            profile = api('/v1/profiles', {'data': {'type': 'profiles', 'attributes': {
                'name': profile_name, 'profileType': 'IOS_APP_STORE'}, 'relationships': {
                'bundleId': {'data': {'type': 'bundleIds', 'id': bundle['id']}},
                'certificates': {'data': [{'type': 'certificates', 'id': CERTIFICATE_ID}]}}}})['data']
        attributes = profile['attributes']
        if not attributes.get('profileContent'):
            attributes = api('/v1/profiles/' + profile['id'])['data']['attributes']
        assert attributes['profileState'] == 'ACTIVE' and attributes['profileType'] == 'IOS_APP_STORE'
        raw = base64.b64decode(attributes['profileContent'])
        profile_path = temp / (attributes['uuid'] + '.mobileprovision')
        profile_path.write_bytes(raw)
        decoded = plistlib.loads(run(['security', 'cms', '-D', '-i', str(profile_path)]).encode())
        entitlements = decoded['Entitlements']
        assert entitlements['application-identifier'] == TEAM + '.' + identifier
        assert not entitlements.get('get-task-allow')
        assert entitlements.get('beta-reports-active') is True
        assert any(x509.load_der_x509_certificate(value).fingerprint(hashes.SHA1()).hex().upper() == FINGERPRINT
                   for value in decoded['DeveloperCertificates'])
        assert decoded['ExpirationDate'].replace(tzinfo=timezone.utc) > datetime.now(timezone.utc)
        for directory in [Path.home() / 'Library/MobileDevice/Provisioning Profiles',
                          Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles']:
            directory.mkdir(parents=True, exist_ok=True)
            (directory / profile_path.name).write_bytes(raw)
        project['targets'][target]['settings']['base'].update({
            'CODE_SIGN_STYLE': 'Manual', 'CODE_SIGN_IDENTITY': FINGERPRINT,
            'DEVELOPMENT_TEAM': TEAM, 'PROVISIONING_PROFILE_SPECIFIER': attributes['name']})
        export_profiles[identifier] = attributes['name']
        print(identifier + ': App Store distribution profile verified')
    project_path.write_text(yaml.safe_dump(project, allow_unicode=True, sort_keys=False))
    options = {'method': 'app-store-connect', 'destination': os.environ['DESTINATION'],
        'signingStyle': 'manual', 'teamID': TEAM, 'signingCertificate': FINGERPRINT,
        'provisioningProfiles': export_profiles, 'uploadSymbols': True,
        'manageAppVersionAndBuildNumber': False}
    with (temp / 'Thirty-ExportOptions.plist').open('wb') as output:
        plistlib.dump(options, output)
    print('Reusable distribution signing installed; no certificate created or revoked')


if __name__ == '__main__':
    main()
