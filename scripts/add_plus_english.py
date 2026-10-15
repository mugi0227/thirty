"""Add only the missing English Thirty+ localization. Default mode is GET-only."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

from asc_metadata import Client
from create_diagnostic_iap import APP_ID, SOURCE_PRODUCT, relationship, source_snapshot, prices


PLUS_ID = "6822135374"
ENGLISH = {"locale": "en-US", "name": "Thirty+",
           "description": "Skins, Live Activities and sounds. One-time."}


def payload():
    return {"data": {"type": "inAppPurchaseLocalizations", "attributes": ENGLISH,
        "relationships": {"inAppPurchaseV2": relationship("inAppPurchases", PLUS_ID)}}}


class LocalizationClient(Client):
    def __init__(self, apply=False):
        super().__init__(False)
        self.apply = apply

    def request(self, method, path, body=None, params=None, write=False):
        if method != "GET":
            if (not self.apply or method != "POST" or not write
                    or path != "/v1/inAppPurchaseLocalizations" or body != payload()):
                raise RuntimeError("Only the exact English localization addition is allowed")
        return super().request(method, path, body, params, write)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    client = LocalizationClient(args.apply)
    app = client.get(f"/v1/apps/{APP_ID}")["data"]
    if app["attributes"]["bundleId"] != "jp.mugilab.thirty":
        raise RuntimeError("Wrong app")
    before = source_snapshot(client, PLUS_ID)
    if (before["attributes"]["productId"] != SOURCE_PRODUCT
            or before["attributes"]["inAppPurchaseType"] != "NON_CONSUMABLE"):
        raise RuntimeError("Wrong product")
    old_prices = prices(client, before["price_schedule_id"])
    existing = next((x for x in before["localizations"] if x["locale"] == ENGLISH["locale"]), None)
    if existing and any(existing.get(k) != v for k, v in ENGLISH.items()):
        raise RuntimeError("English already exists with different text; refusing to overwrite it")
    plan = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "product_id": SOURCE_PRODUCT,
        "existing_locales": [x["locale"] for x in before["localizations"]],
        "already_present": existing is not None, "prices": old_prices,
        "territory_count": len(before["territories"]), "request": payload()}
    Path("plus-localization-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    print(json.dumps(plan, ensure_ascii=False))
    if not args.apply:
        print("GET-only plan completed. No localization was changed.")
        return
    if existing is None:
        client.post("/v1/inAppPurchaseLocalizations", payload())
    after = source_snapshot(client, PLUS_ID)
    old_other = {k: v for k, v in before.items() if k != "localizations"}
    new_other = {k: v for k, v in after.items() if k != "localizations"}
    original_locales = [x for x in before["localizations"] if x["locale"] != ENGLISH["locale"]]
    final_original_locales = [x for x in after["localizations"] if x["locale"] != ENGLISH["locale"]]
    final_english = [x for x in after["localizations"] if x["locale"] == ENGLISH["locale"]]
    if (old_other != new_other or original_locales != final_original_locales
            or prices(client, after["price_schedule_id"]) != old_prices
            or len(final_english) != 1
            or any(final_english[0].get(k) != v for k, v in ENGLISH.items())):
        raise RuntimeError("Readback did not match the intended single-localization addition")
    result = {"checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "action": "added" if existing is None else "already_present",
        "product_id": SOURCE_PRODUCT, "state": after["attributes"]["state"],
        "localizations": after["localizations"], "prices": old_prices,
        "territory_count": len(after["territories"]), "other_settings_unchanged": True}
    Path("plus-localization-result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
