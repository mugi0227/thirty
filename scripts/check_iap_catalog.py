"""Read only: inspect live product pricing and app/territory availability."""
import json
import base64
import plistlib
from datetime import datetime, timezone
from pathlib import Path

from asc_metadata import API, Client, ROOT

client = Client(False)
report = {'checked_at_utc': datetime.now(timezone.utc).isoformat(), 'errors': []}

def get(path, **params):
    try:
        result = client.get(path, **params)
        next_url = result.get('links', {}).get('next')
        while next_url and next_url.startswith(API + '/'):
            page = client.get(next_url[len(API):])
            result.setdefault('data', []).extend(page.get('data', []))
            result.setdefault('included', []).extend(page.get('included', []))
            next_url = page.get('links', {}).get('next')
        return result
    except Exception as error:
        response = getattr(error, 'response', None)
        report['errors'].append({'path': path, 'status': response.status_code if response is not None else None,
                                'detail': response.json().get('errors', []) if response is not None else type(error).__name__})
        return {}

config = json.loads((ROOT / 'release/metadata-ja.json').read_text(encoding='utf-8'))
app = get('/v1/apps', **{'filter[bundleId]': config['bundle_id']})['data'][0]
app_id = app['id']
report['app'] = {'id': app_id, 'bundleId': app['attributes']['bundleId']}
report['signing_configuration'] = []
for bundle in get('/v1/bundleIds', **{'filter[identifier]': config['bundle_id'], 'limit': 10}).get('data', []):
    if bundle['attributes']['identifier'] != config['bundle_id']:
        continue
    entry = {'identifier': bundle['attributes']['identifier'], 'platform': bundle['attributes'].get('platform')}
    entry['capabilities'] = [item['attributes']['capabilityType'] for item in
        get(f"/v1/bundleIds/{bundle['id']}/bundleIdCapabilities").get('data', [])]
    entry['profiles'] = []
    profiles = get(f"/v1/bundleIds/{bundle['id']}/profiles", limit=200).get('data', [])
    for profile in profiles:
        attrs = profile['attributes']
        if attrs.get('profileType') != 'IOS_APP_STORE':
            continue
        summary = {k: attrs.get(k) for k in ('profileType', 'profileState', 'expirationDate')}
        encoded = attrs.get('profileContent')
        if encoded:
            try:
                data = base64.b64decode(encoded)
                start = data.index(b'<?xml')
                end = data.index(b'</plist>', start) + len(b'</plist>')
                decoded = plistlib.loads(data[start:end])
                entitlements = decoded.get('Entitlements', {})
                summary['application_identifier'] = entitlements.get('application-identifier')
                summary['team_identifier'] = entitlements.get('com.apple.developer.team-identifier')
                summary['get_task_allow'] = entitlements.get('get-task-allow')
                summary['beta_reports_active'] = entitlements.get('beta-reports-active')
            except Exception as error:
                summary['decode_error'] = type(error).__name__
        entry['profiles'].append(summary)
    report['signing_configuration'].append(entry)
report['app_availability'] = get(f'/v1/apps/{app_id}/appAvailabilityV2', include='territoryAvailabilities')
availability = report['app_availability'].get('data')
if availability:
    report['app_territories'] = get(f"/v2/appAvailabilities/{availability['id']}/territoryAvailabilities",
        include='territory', **{'fields[territoryAvailabilities]': 'available,releaseDate,contentStatuses,territory', 'limit': 200})
report['app_price_schedule'] = get(f'/v1/apps/{app_id}/appPriceSchedule')
schedule = report['app_price_schedule'].get('data')
if schedule:
    report['app_prices_jpn'] = get(f"/v1/appPriceSchedules/{schedule['id']}/manualPrices",
        include='appPricePoint,territory', **{'filter[territory]': 'JPN', 'limit': 200})
report['purchases'] = []
for purchase in get(f'/v1/apps/{app_id}/inAppPurchasesV2', limit=50).get('data', []):
    pid = purchase['id']
    item = {'id': pid, 'attributes': purchase['attributes']}
    item['localizations'] = get(f'/v2/inAppPurchases/{pid}/inAppPurchaseLocalizations')
    item['availability'] = get(f'/v2/inAppPurchases/{pid}/inAppPurchaseAvailability')
    availability = item['availability'].get('data')
    if availability:
        item['territories'] = get(f"/v1/inAppPurchaseAvailabilities/{availability['id']}/availableTerritories", limit=200)
    item['price_schedule'] = get(f'/v2/inAppPurchases/{pid}/iapPriceSchedule')
    schedule = item['price_schedule'].get('data')
    if schedule:
        for kind in ('manualPrices', 'automaticPrices'):
            item[kind] = get(f"/v1/inAppPurchasePriceSchedules/{schedule['id']}/{kind}",
                include='inAppPurchasePricePoint,territory', **{'filter[territory]': 'JPN,USA', 'limit': 200,
                'fields[inAppPurchasePrices]': 'startDate,endDate,manual,inAppPurchasePricePoint,territory',
                'fields[inAppPurchasePricePoints]': 'customerPrice,proceeds,territory',
                'fields[territories]': 'currency'})
    report['purchases'].append(item)

Path('iap-catalog-diagnosis.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'app': report['app'], 'app_availability_exists': bool(report['app_availability'].get('data')),
    'purchases': [p['attributes']['productId'] for p in report['purchases']], 'errors': report['errors']}, ensure_ascii=False))
