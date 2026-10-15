"""Make the device-verified product the official Thirty+. Default is GET-only."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

from asc_metadata import Client
from create_diagnostic_iap import relationship, list_all, source_snapshot, prices

PRODUCT_ID = "6823121323"
LEGACY_ID = "6822135374"
PRODUCT_SKU = "jp.mugilab.thirty.diagnostic"
REFERENCE_NAME = "Thirty+ Current"
TEXT = [
    {"locale": "ja", "name": "Thirty+", "description": "スキン、ロック画面表示、終了音などが使えます。買い切りです。"},
    {"locale": "en-US", "name": "Thirty+", "description": "Skins, Live Activities and sounds. One-time."},
]
NOTE = """Thirty+ is a one-time, non-consumable purchase. The timer itself is free and has no ads.

Where to find it: tap the palette icon (top right) or Settings > Thirty+. Locked items open the purchase sheet. Restore purchases restores verified purchases.

Unlocks: 5 extra skins; end sounds; break cycles; 60 slats; minutes-only display; alternate app icons; Live Activity on the Lock Screen, StandBy and Dynamic Island while a timer runs.

No account or app server is involved. The product ID is the existing device-verified catalog record jp.mugilab.thirty.diagnostic; its customer-facing name is Thirty+."""


class PromotionClient(Client):
    def __init__(self, apply=False):
        super().__init__(False)
        self.apply = apply
        self.allowed = {}

    def request(self, method, path, body=None, params=None, write=False):
        if method != "GET" and not (self.apply and write and (method, path) in self.allowed
                                      and body == self.allowed[(method, path)]):
            raise RuntimeError("Write is outside the exact metadata promotion plan")
        return super().request(method, path, body, params, write)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    client = PromotionClient(args.apply)
    before = source_snapshot(client, PRODUCT_ID)
    legacy = source_snapshot(client, LEGACY_ID)
    old_prices = prices(client, before["price_schedule_id"])
    legacy_prices = prices(client, legacy["price_schedule_id"])
    if (before["attributes"]["productId"] != PRODUCT_SKU
            or before["attributes"]["inAppPurchaseType"] != "NON_CONSUMABLE"
            or before["attributes"]["name"] not in ("Thirty Sandbox Diagnostic", REFERENCE_NAME)
            or set(old_prices) != {"JPN", "USA"}
            or float(old_prices["JPN"]) != 500 or float(old_prices["USA"]) != 2.99):
        raise RuntimeError("Product identity or prices changed")
    versions = list_all(client, f"/v2/inAppPurchases/{PRODUCT_ID}/versions", limit=200)
    drafts = [x for x in versions if x["attributes"]["state"] == "PREPARE_FOR_SUBMISSION"]
    if len(drafts) != 1:
        raise RuntimeError("Expected exactly one editable version; review state will not be changed")
    version = drafts[0]
    locales = list_all(client, f"/v1/inAppPurchaseVersions/{version['id']}/localizations", limit=200)
    operations = []
    parent_body = {"data": {"type": "inAppPurchases", "id": PRODUCT_ID,
        "attributes": {"name": REFERENCE_NAME, "reviewNote": NOTE}}}
    operations.append(("PATCH", f"/v2/inAppPurchases/{PRODUCT_ID}", parent_body))
    for text in TEXT:
        existing = next((x for x in locales if x["attributes"]["locale"] == text["locale"]), None)
        if existing:
            if any(existing["attributes"].get(k) != v for k, v in text.items()):
                body = {"data": {"type": "inAppPurchaseLocalizations", "id": existing["id"],
                    "attributes": {k: v for k, v in text.items() if k != "locale"}}}
                operations.append(("PATCH", f"/v2/inAppPurchaseLocalizations/{existing['id']}", body))
        else:
            body = {"data": {"type": "inAppPurchaseLocalizations", "attributes": text,
                "relationships": {"version": relationship("inAppPurchaseVersions", version["id"])}}}
            operations.append(("POST", "/v2/inAppPurchaseLocalizations", body))
    plan = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "product_id": PRODUCT_SKU,
        "metadata_version": {"id": version["id"], **version["attributes"]},
        "prices": old_prices, "territories": len(before["territories"]),
        "operations": [{"method": m, "path": p, "body": b} for m, p, b in operations]}
    Path("working-iap-promotion-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    print(json.dumps(plan, ensure_ascii=False))
    if not args.apply:
        print("GET-only plan completed. No product was changed.")
        return
    client.allowed = {(m, p): b for m, p, b in operations}
    for method, path, body in operations:
        client.request(method, path, body, write=True)
    after = source_snapshot(client, PRODUCT_ID)
    final = list_all(client, f"/v1/inAppPurchaseVersions/{version['id']}/localizations", limit=200)
    actual_text = sorted(({k: x["attributes"].get(k) for k in ("locale", "name", "description")}
                         for x in final), key=lambda x: x["locale"])
    stable_keys = ("territories", "availableInNewTerritories", "price_schedule_id")
    if (any(before[k] != after[k] for k in stable_keys)
            or prices(client, after["price_schedule_id"]) != old_prices
            or actual_text != sorted(TEXT, key=lambda x: x["locale"])
            or after["attributes"]["name"] != REFERENCE_NAME
            or after["attributes"]["reviewNote"] != NOTE
            or source_snapshot(client, LEGACY_ID) != legacy
            or prices(client, legacy["price_schedule_id"]) != legacy_prices):
        raise RuntimeError("Metadata or unchanged pricing/legacy settings did not read back correctly")
    result = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "product_id": PRODUCT_SKU,
        "state": after["attributes"]["state"], "localizations": actual_text, "prices": old_prices,
        "territories": len(after["territories"]), "legacy_unchanged": True}
    Path("working-iap-promotion-result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
