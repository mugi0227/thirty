"""Inspect existing App Store Connect resources without changing anything."""
import json
from pathlib import Path

from asc_metadata import API, Client, ROOT

client = Client(False)
config = json.loads((ROOT / 'release/metadata-ja.json').read_text(encoding='utf-8'))
app = client.get('/v1/apps', **{'filter[bundleId]': config['bundle_id']})['data'][0]
app_id = app['id']
report = {'app': {k: app['attributes'].get(k) for k in ('name', 'bundleId', 'contentRightsDeclaration')}, 'errors': []}

def get(path, **params):
    try:
        return client.get(path, **params)
    except Exception as error:
        response = getattr(error, 'response', None)
        report['errors'].append({'path': path, 'status': response.status_code if response is not None else None,
                                 'exception': type(error).__name__})
        return {}

def related(resource, name):
    relation = resource.get('relationships', {}).get(name, {})
    url = relation.get('links', {}).get('related')
    if isinstance(url, dict):
        url = url.get('href')
    if url and url.startswith(API + '/'):
        return get(url[len(API):])
    return {}

version = next(v for v in get(f'/v1/apps/{app_id}/appStoreVersions', **{'filter[platform]': 'IOS', 'limit': 10})['data']
               if v['attributes']['versionString'] == '1.0')
report['version'] = {k: version['attributes'].get(k) for k in ('versionString', 'appStoreState', 'releaseType', 'copyright')}
report['version_relationships'] = list(version.get('relationships', {}))
build = get(f"/v1/appStoreVersions/{version['id']}/build").get('data')
if build:
    report['build'] = {k: build['attributes'].get(k) for k in ('version', 'processingState', 'expired', 'usesNonExemptEncryption')}
detail = get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get('data')
if detail:
    attributes = detail['attributes']
    report['review_contact_fields_present'] = {k: bool(attributes.get(k)) for k in
        ('contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail')}
    report['review_notes_present'] = bool(attributes.get('notes'))
    report['demo_account_required'] = attributes.get('demoAccountRequired')
localizations = get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations").get('data', [])
report['version_localizations'] = [{k: item['attributes'].get(k) for k in
    ('locale', 'description', 'keywords', 'promotionalText', 'supportUrl', 'marketingUrl')} for item in localizations]
infos = get(f'/v1/apps/{app_id}/appInfos').get('data', [])
report['app_infos'] = []
for info in infos:
    locales = get(f"/v1/appInfos/{info['id']}/appInfoLocalizations").get('data', [])
    age = get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration").get('data')
    report['app_infos'].append({'state': info['attributes'].get('appStoreState'),
        'localizations': [item['attributes'] for item in locales],
        'age_rating': age['attributes'] if age else None})

purchases = get(f'/v1/apps/{app_id}/inAppPurchasesV2', limit=50).get('data', [])
report['purchases'] = []
for purchase in purchases:
    item = {'attributes': purchase['attributes'], 'relationships': list(purchase.get('relationships', {}))}
    for name in ('inAppPurchaseLocalizations', 'appStoreReviewScreenshot', 'inAppPurchaseAvailability',
                 'priceSchedule', 'inAppPurchasePriceSchedule', 'inAppPurchaseVersions'):
        result = related(purchase, name)
        if result:
            data = result.get('data')
            objects = data if isinstance(data, list) else [data] if data else []
            item[name] = [{'type': obj.get('type'), 'attributes': obj.get('attributes'),
                           'relationships': list(obj.get('relationships', {}))} for obj in objects]
    # Review screenshot is documented even if Apple omits its related link.
    if 'appStoreReviewScreenshot' not in item:
        shot = get(f"/v2/inAppPurchases/{purchase['id']}/appStoreReviewScreenshot").get('data')
        item['appStoreReviewScreenshot'] = shot['attributes'] if shot else None
    report['purchases'].append(item)

for name in ('inAppPurchases', 'inAppPurchasesV2', 'inAppPurchaseVersions'):
    data = related(version, name)
    if data:
        report['version_' + name] = [{'type': obj.get('type'), 'attributes': obj.get('attributes')} for obj in data.get('data', [])]

report['app_relationships'] = list(app.get('relationships', {}))
availability = related(app, 'appAvailabilityV2') or related(app, 'appAvailability')
if availability:
    report['app_availability'] = availability.get('data', {}).get('attributes')
Path('app-review-readiness.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps({'version': report.get('version'), 'build': report.get('build'),
                  'review_contact_fields_present': report.get('review_contact_fields_present'),
                  'review_notes_present': report.get('review_notes_present'),
                  'purchases': [p['attributes'] for p in report['purchases']], 'errors': report['errors']}, ensure_ascii=False))
