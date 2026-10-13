"""Create missing app availability for the 175 currently configured Thirty+ territories.

Only the availability resource can be created; this never submits or releases an app.
Use --snapshot FILE to inspect the exact payload locally without credentials or writes.
"""
import argparse
import json
from pathlib import Path

PRODUCT_ID = 'jp.mugilab.thirty.plus'
EXPECTED_COUNT = 175

def payload(app_id, territories):
    territories = sorted(set(territories))
    if len(territories) != EXPECTED_COUNT or 'JPN' not in territories:
        raise ValueError('Expected the 175 approved territories, including JPN.')
    return {'data': {'type': 'appAvailabilities', 'attributes': {'availableInNewTerritories': False},
        'relationships': {'app': {'data': {'type': 'apps', 'id': app_id}},
            'territoryAvailabilities': {'data': [{'type': 'territoryAvailabilities', 'id': code} for code in territories]}}},
        'included': [{'type': 'territoryAvailabilities', 'id': code,
            'attributes': {'available': True, 'preOrderEnabled': False},
            'relationships': {'territory': {'data': {'type': 'territories', 'id': code}}}} for code in territories]}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--snapshot', type=Path)
    args = parser.parse_args()
    if args.snapshot:
        source = json.loads(args.snapshot.read_text(encoding='utf-8'))
        purchase = next(item for item in source['purchases'] if item['attributes']['productId'] == PRODUCT_ID)
        body = payload(source['app']['id'], [item['id'] for item in purchase['territories']['data']])
        output = args.snapshot.parent / 'app-availability-proposed.json'
        output.write_text(json.dumps(body, indent=2), encoding='utf-8')
        print(json.dumps({'file': str(output), 'territory_count': len(body['included']),
            'japan_included': True, 'preorder': False, 'automatic_new_territories': False}))
        return

    from asc_metadata import API, Client, ROOT
    client = Client(False)
    report = {'created': False, 'requested_territories': [], 'verified_territories': []}
    output = Path('app-availability-verification.json')
    def save():
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    def all_data(path, **params):
        response = client.get(path, **params)
        result = response.get('data', [])
        next_url = response.get('links', {}).get('next')
        while next_url:
            if not next_url.startswith(API + '/'):
                raise ValueError('Unexpected pagination origin.')
            response = client.get(next_url[len(API):])
            result.extend(response.get('data', []))
            next_url = response.get('links', {}).get('next')
        return result
    config = json.loads((ROOT / 'release/metadata-ja.json').read_text(encoding='utf-8'))
    app = client.get('/v1/apps', **{'filter[bundleId]': config['bundle_id']})['data'][0]
    app_id = app['id']
    report['app'] = {'id': app_id, 'bundleId': app['attributes']['bundleId']}
    def version_state():
        versions = all_data(f'/v1/apps/{app_id}/appStoreVersions', **{'filter[platform]': 'IOS', 'limit': 10})
        version = next(item for item in versions if item['attributes']['versionString'] == '1.0')
        return version['attributes']['appStoreState']
    report['state_before'] = version_state()
    if report['state_before'] != 'PREPARE_FOR_SUBMISSION':
        save()
        raise SystemExit('Unexpected app state; refusing to change availability.')
    purchase = next(item for item in all_data(f'/v1/apps/{app_id}/inAppPurchasesV2', limit=50)
                    if item['attributes']['productId'] == PRODUCT_ID)
    purchase_availability = client.get(f"/v2/inAppPurchases/{purchase['id']}/inAppPurchaseAvailability")['data']
    territories = [item['id'] for item in all_data(
        f"/v1/inAppPurchaseAvailabilities/{purchase_availability['id']}/availableTerritories", limit=200)]
    body = payload(app_id, territories)
    report['requested_territories'] = sorted(territories)
    report['proposed_payload'] = body
    save()
    try:
        availability = client.get(f'/v1/apps/{app_id}/appAvailabilityV2')['data']
    except Exception as error:
        response = getattr(error, 'response', None)
        errors = response.json().get('errors', []) if response is not None else []
        if response is None or response.status_code != 404 or not any(
                item.get('code') == 'NOT_FOUND' and 'appAvailabilities' in item.get('detail', '') for item in errors):
            raise
        availability = None
        report['missing_before'] = True
    if availability is None:
        if not args.apply:
            print('Availability is missing. Dry run only.')
            return
        created = client.post('/v2/appAvailabilities', body)['data']
        report['created'] = True
        report['created_id'] = created['id']
        save()
        availability = client.get(f'/v1/apps/{app_id}/appAvailabilityV2')['data']
    actual = all_data(f"/v2/appAvailabilities/{availability['id']}/territoryAvailabilities", include='territory', limit=200)
    records = [{'territory': item['relationships']['territory']['data']['id'], 'attributes': item['attributes']} for item in actual]
    report['territory_records'] = records
    report['verified_territories'] = sorted(item['territory'] for item in records if item['attributes']['available'])
    report['japan_available'] = 'JPN' in report['verified_territories']
    report['no_preorders'] = all(not item['attributes'].get('preOrderEnabled') for item in records)
    report['state_after'] = version_state()
    report['verified'] = (report['verified_territories'] == report['requested_territories'] and
        report['no_preorders'] and report['state_after'] == 'PREPARE_FOR_SUBMISSION')
    save()
    print(json.dumps({key: report[key] for key in ('created', 'japan_available', 'no_preorders', 'state_after', 'verified')}))
    if not report['verified']:
        raise SystemExit('Read-back differs from approved configuration; inspect the report.')

if __name__ == '__main__':
    main()
