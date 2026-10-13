"""Read-only check of the uploaded build and the media for version 1.0."""
import hashlib
import json
import os
import time
from pathlib import Path

from asc_metadata import Client, ROOT, find_one

client = Client(False)
config = json.loads((ROOT / 'release/metadata-ja.json').read_text(encoding='utf-8'))
app = client.get('/v1/apps', **{'filter[bundleId]': config['bundle_id']})['data'][0]
app_id = app['id']
versions = client.get(f'/v1/apps/{app_id}/appStoreVersions', **{'filter[platform]': 'IOS', 'limit': 10})['data']
version = next(v for v in versions if v['attributes']['versionString'] == '1.0')
localizations = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")['data']
localization = find_one(localizations, config['locale'])
localization_id = localization['id']
require_attached = os.environ.get('REQUIRE_ATTACHED', 'false').lower() == 'true'

def media_snapshot():
    records = []
    sets = client.get(f'/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets')['data']
    for display, folder in config['screenshots'].items():
        selected = next(s for s in sets if s['attributes']['screenshotDisplayType'] == display)
        assets = client.get(f"/v1/appScreenshotSets/{selected['id']}/appScreenshots")['data']
        expected = {f.name: f for f in (ROOT / folder).glob('*.png')}
        assert {a['attributes']['fileName'] for a in assets} == set(expected), f'Unexpected screenshots for {display}'
        for asset in assets:
            attributes = asset['attributes']
            file = expected[attributes['fileName']]
            checksum = hashlib.md5(file.read_bytes()).hexdigest()
            records.append({'type': display, 'file': file.name,
                            'state': (attributes.get('assetDeliveryState') or {}).get('state'),
                            'checksum_matches': attributes.get('sourceFileChecksum') == checksum,
                            'source_checksum': attributes.get('sourceFileChecksum')})
    sets = client.get(f'/v1/appStoreVersionLocalizations/{localization_id}/appPreviewSets')['data']
    for display, path in config['previews'].items():
        selected = next(s for s in sets if s['attributes']['previewType'] == display)
        assets = client.get(f"/v1/appPreviewSets/{selected['id']}/appPreviews")['data']
        assert len(assets) == 1, f'Unexpected preview count for {display}'
        attributes = assets[0]['attributes']
        file = ROOT / path
        records.append({'type': display, 'file': attributes['fileName'],
                        'state': (attributes.get('assetDeliveryState') or {}).get('state'),
                        'checksum_matches': attributes.get('sourceFileChecksum') == hashlib.md5(file.read_bytes()).hexdigest(),
                        'source_checksum': attributes.get('sourceFileChecksum')})
    return records

for attempt in range(30):
    builds = client.get('/v1/builds', **{'filter[app]': app_id, 'sort': '-uploadedDate', 'limit': 20})['data']
    target = next((b for b in builds if b['attributes']['version'] == '5'), None)
    attached = client.get(f"/v1/appStoreVersions/{version['id']}/relationships/build").get('data')
    attached_build = next((b for b in builds if attached and b['id'] == attached['id']), None)
    media = media_snapshot()
    report = {
        'version': version['attributes']['versionString'],
        'version_state': version['attributes']['appStoreState'],
        'target_build': None if not target else {
            'number': target['attributes']['version'],
            'processing_state': target['attributes'].get('processingState'),
            'uploaded_date': target['attributes'].get('uploadedDate'),
        },
        'attached_build': attached_build['attributes']['version'] if attached_build else None,
        'media': media,
        'require_attached': require_attached,
        'attempt': attempt + 1,
    }
    ready = bool(target and target['attributes'].get('processingState') == 'VALID')
    complete = all(asset['state'] == 'COMPLETE' and asset['checksum_matches'] for asset in media)
    report['verified'] = ready and complete and (not require_attached or report['attached_build'] == '5')
    Path('store-reflection-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'attempt': attempt + 1, 'target_build': report['target_build'],
                      'attached_build': report['attached_build'], 'media_complete': complete,
                      'media_states': sorted({str(a['state']) for a in media}),
                      'checksums_match': all(a['checksum_matches'] for a in media)}))
    if report['verified']:
        print('Verified build 5 and all uploaded media.')
        break
    if target and target['attributes'].get('processingState') in ('FAILED', 'INVALID'):
        raise SystemExit('Apple rejected build 5 processing; see verification report.')
    if any(asset['state'] == 'FAILED' for asset in media):
        raise SystemExit('Apple rejected a media asset; see verification report.')
    time.sleep(20)
else:
    raise SystemExit('Processing did not finish within the verification window; see report.')
