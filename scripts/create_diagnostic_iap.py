"""Prepare a separate sandbox comparison product; writes require --apply.

Only the fixed diagnostic product may be created/configured. Existing Thirty+
metadata is read before and after the operation. No review submission is made.
The product ID remains reserved by Apple even if the product is later deleted.
"""
import argparse
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import time
from urllib.parse import urlsplit

import requests

from asc_metadata import API, Client


APP_ID = "6822135223"
SOURCE_PRODUCT = "jp.mugilab.thirty.plus"
PRODUCT = "jp.mugilab.thirty.diagnostic"
NAME = "Thirty Sandbox Diagnostic"
NOTE = "Sandbox catalog diagnosis only. Not used by the app or submitted for review."
LOCALIZATION = {"locale": "ja", "name": "Thirty 診断用",
                "description": "商品情報の取得確認用です。通常の購入には使いません。"}


class DiagnosticClient(Client):
    diagnostic_id = None
    review_screenshot_id = None

    def post(self, path, body):
        if path == "/v2/inAppPurchases":
            if body != create_payload():
                raise RuntimeError("Refusing an unexpected product creation")
        else:
            keys = {"/v1/inAppPurchaseLocalizations": "inAppPurchaseV2",
                    "/v1/inAppPurchaseAvailabilities": "inAppPurchase",
                    "/v1/inAppPurchasePriceSchedules": "inAppPurchase",
                    "/v1/inAppPurchaseAppStoreReviewScreenshots": "inAppPurchaseV2"}
            key = keys.get(path)
            if not key or not self.diagnostic_id:
                raise RuntimeError("Write endpoint is not allowed")
            if body["data"]["relationships"][key] != relationship("inAppPurchases", self.diagnostic_id):
                raise RuntimeError("Refusing to configure a different product")
            for item in body.get("included", []):
                if item["relationships"]["inAppPurchaseV2"] != relationship("inAppPurchases", self.diagnostic_id):
                    raise RuntimeError("Refusing a price for a different product")
        return super().post(path, body)

    def patch(self, path, body):
        expected = f"/v1/inAppPurchaseAppStoreReviewScreenshots/{self.review_screenshot_id}"
        attributes = body.get("data", {}).get("attributes", {})
        if (not self.review_screenshot_id or path != expected
                or body["data"].get("id") != self.review_screenshot_id
                or body["data"].get("type") != "inAppPurchaseAppStoreReviewScreenshots"
                or set(attributes) != {"uploaded", "sourceFileChecksum"}
                or attributes["uploaded"] is not True):
            raise RuntimeError("Only the diagnostic screenshot upload may be completed")
        return super().patch(path, body)

    def delete(self, *args, **kwargs):
        raise RuntimeError("DELETE is not allowed")


def relationship(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def create_payload():
    return {"data": {"type": "inAppPurchases", "attributes": {
        "name": NAME, "productId": PRODUCT, "inAppPurchaseType": "NON_CONSUMABLE",
        "reviewNote": NOTE, "familySharable": False},
        "relationships": {"app": relationship("apps", APP_ID)}}}


def setup_payloads(identifier, territories, new_territories, points):
    purchase = relationship("inAppPurchases", identifier)
    prices = []
    for territory, point in sorted(points.items()):
        prices.append({"type": "inAppPurchasePrices", "id": "${diagnostic-" + territory.lower() + "}",
            "attributes": {"startDate": None, "endDate": None}, "relationships": {
                "inAppPurchaseV2": purchase,
                "inAppPurchasePricePoint": relationship("inAppPurchasePricePoints", point)}})
    return {
        "/v1/inAppPurchaseLocalizations": {"data": {"type": "inAppPurchaseLocalizations",
            "attributes": LOCALIZATION, "relationships": {"inAppPurchaseV2": purchase}}},
        "/v1/inAppPurchaseAvailabilities": {"data": {"type": "inAppPurchaseAvailabilities",
            "attributes": {"availableInNewTerritories": new_territories}, "relationships": {
                "inAppPurchase": purchase, "availableTerritories": {"data": [
                    {"type": "territories", "id": x} for x in sorted(territories)]}}}},
        "/v1/inAppPurchasePriceSchedules": {"data": {"type": "inAppPurchasePriceSchedules",
            "relationships": {"inAppPurchase": purchase, "baseTerritory": relationship("territories", "JPN"),
                "manualPrices": {"data": [{"type": p["type"], "id": p["id"]} for p in prices]}}},
            "included": prices},
    }


def list_all(client, path, **params):
    result = client.get(path, **params)
    items = result["data"]
    if not isinstance(items, list):
        raise RuntimeError("Expected a collection: " + path)
    while result.get("links", {}).get("next"):
        url = result["links"]["next"]
        if not url.startswith(API + "/"):
            raise RuntimeError("Unexpected pagination origin")
        result = client.get(url[len(API):])
        items.extend(result["data"])
    return items


def optional(client, path):
    try:
        return client.get(path).get("data")
    except requests.HTTPError as error:
        if error.response.status_code == 404:
            return None
        raise


def source_snapshot(client, identifier):
    purchase = client.get(f"/v2/inAppPurchases/{identifier}")["data"]
    locales = list_all(client, f"/v2/inAppPurchases/{identifier}/inAppPurchaseLocalizations")
    availability = client.get(f"/v2/inAppPurchases/{identifier}/inAppPurchaseAvailability")["data"]
    territories = list_all(client,
        f"/v1/inAppPurchaseAvailabilities/{availability['id']}/availableTerritories", limit=200)
    schedule = client.get(f"/v2/inAppPurchases/{identifier}/iapPriceSchedule")["data"]
    return {"attributes": purchase["attributes"],
        "localizations": sorted((x["attributes"] for x in locales), key=lambda x: x["locale"]),
        "availableInNewTerritories": availability["attributes"]["availableInNewTerritories"],
        "territories": sorted(x["id"] for x in territories),
        "price_schedule_id": schedule["id"]}


def prices(client, schedule):
    output = {}
    for kind in ("manualPrices", "automaticPrices"):
        # At most two filtered current prices; keep dates to reject future prices.
        result = client.get(f"/v1/inAppPurchasePriceSchedules/{schedule}/{kind}",
            include="inAppPurchasePricePoint,territory", **{"filter[territory]": "JPN,USA", "limit": 200})
        if result.get("links", {}).get("next"):
            raise RuntimeError("Unexpected multi-page pricing history; inspect before creating")
        points = {x["id"]: x["attributes"]["customerPrice"] for x in result.get("included", [])
                  if x["type"] == "inAppPurchasePricePoints"}
        for entry in result["data"]:
            if entry["attributes"].get("startDate") or entry["attributes"].get("endDate"):
                raise RuntimeError("Dated pricing requires manual inspection")
            relations = entry["relationships"]
            territory = relations["territory"]["data"]["id"]
            if territory in output:
                raise RuntimeError("Ambiguous current price for " + territory)
            output[territory] = points[relations["inAppPurchasePricePoint"]["data"]["id"]]
    return output


def complete_review_screenshot(client, source_id, identifier):
    """Copy the existing app screenshot so both products have complete metadata.

    This is a reference image of Thirty+, not a new app purchase flow. The
    diagnostic product's review note explicitly states it isn't used by the app.
    """
    endpoint = f"/v2/inAppPurchases/{identifier}/appStoreReviewScreenshot"
    screenshot = optional(client, endpoint)
    if screenshot and screenshot["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE":
        return
    source = client.get(f"/v2/inAppPurchases/{source_id}/appStoreReviewScreenshot")["data"]
    if source["attributes"].get("assetDeliveryState", {}).get("state") != "COMPLETE":
        raise RuntimeError("Reference screenshot is not ready")
    image = source["attributes"]["imageAsset"]
    url = image["templateUrl"].replace("{w}", str(image["width"])).replace("{h}", str(image["height"])).replace("{f}", "png")
    host = urlsplit(url).hostname or ""
    if urlsplit(url).scheme != "https" or not (host.endswith(".mzstatic.com") or host.endswith(".apple.com")):
        raise RuntimeError("Unexpected Apple image origin")
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    data = response.content
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError("Reference image was not returned as PNG")
    if not screenshot:
        screenshot = client.post("/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {
                "fileName": "thirty-existing-app-reference.png", "fileSize": len(data)},
            "relationships": {"inAppPurchaseV2": relationship("inAppPurchases", identifier)}}})["data"]
    operations = screenshot["attributes"].get("uploadOperations") or []
    if not operations:
        raise RuntimeError("Diagnostic screenshot has no upload operations")
    client.review_screenshot_id = screenshot["id"]
    for operation in operations:
        headers = {x["name"]: x["value"] for x in operation.get("requestHeaders", [])}
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        requests.request(operation["method"], operation["url"], headers=headers, data=chunk, timeout=60).raise_for_status()
    client.patch(f"/v1/inAppPurchaseAppStoreReviewScreenshots/{screenshot['id']}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": screenshot["id"], "attributes": {
            "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    for _ in range(15):
        current = client.get(endpoint)["data"]["attributes"].get("assetDeliveryState", {}).get("state")
        if current == "COMPLETE":
            return
        if current == "FAILED":
            raise RuntimeError("Diagnostic screenshot processing failed")
        time.sleep(2)
    raise RuntimeError("Diagnostic screenshot is still processing; rerun after it finishes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    client = DiagnosticClient(False)
    app = client.get(f"/v1/apps/{APP_ID}")["data"]
    if app["attributes"]["bundleId"] != "jp.mugilab.thirty":
        raise RuntimeError("Wrong app")
    purchases = list_all(client, f"/v1/apps/{APP_ID}/inAppPurchasesV2", limit=200)
    source = next(x for x in purchases if x["attributes"]["productId"] == SOURCE_PRODUCT)
    before = source_snapshot(client, source["id"])
    source_prices = prices(client, before["price_schedule_id"])
    if (before["attributes"]["inAppPurchaseType"] != "NON_CONSUMABLE"
            or [x["locale"] for x in before["localizations"]] != ["ja"]
            or not {"JPN", "USA"}.issubset(before["territories"])
            or {k: Decimal(v) for k, v in source_prices.items()} != {"JPN": Decimal(500), "USA": Decimal("2.99")}):
        raise RuntimeError("Reference product changed; inspect the comparison plan again")
    existing = [x for x in purchases if x["attributes"]["productId"] == PRODUCT]
    target = existing[0] if existing else None
    if target and any(target["attributes"].get(k) != v for k, v in create_payload()["data"]["attributes"].items()):
        raise RuntimeError("Diagnostic ID already belongs to a different configuration")
    plan = {"app_id": APP_ID, "source_product_id": SOURCE_PRODUCT, "product_id": PRODUCT,
        "existing_diagnostic_id": target["id"] if target else None,
        "territory_count": len(before["territories"]), "prices": source_prices,
        "product_id_cannot_be_reused": True, "create": create_payload(),
        "configure": setup_payloads("NEW_DIAGNOSTIC_ID", before["territories"],
            before["availableInNewTerritories"], {k: "NEW_" + k + "_PRICE_POINT" for k in source_prices})}
    Path("diagnostic-iap-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2))
    print(json.dumps({k: v for k, v in plan.items() if k not in ("create", "configure")}, ensure_ascii=False))
    if not args.apply:
        print("GET-only plan completed. No product was created.")
        return
    if target is None:
        target = client.post("/v2/inAppPurchases", create_payload())["data"]
        print("Created diagnostic product: " + target["id"], flush=True)
    identifier = target["id"]
    if identifier == source["id"]:
        raise RuntimeError("Refusing to configure the reference product")
    client.diagnostic_id = identifier
    point_ids = {}
    for territory, amount in source_prices.items():
        matches = [p for p in list_all(client, f"/v2/inAppPurchases/{identifier}/pricePoints",
            **{"filter[territory]": territory, "limit": 200})
            if Decimal(p["attributes"]["customerPrice"]) == Decimal(amount)]
        if len(matches) != 1:
            raise RuntimeError("No unique price point for " + territory)
        point_ids[territory] = matches[0]["id"]
    payloads = setup_payloads(identifier, before["territories"], before["availableInNewTerritories"], point_ids)
    locales = list_all(client, f"/v2/inAppPurchases/{identifier}/inAppPurchaseLocalizations")
    if locales:
        attrs = [{k: x["attributes"].get(k) for k in LOCALIZATION} for x in locales]
        if attrs != [LOCALIZATION]:
            raise RuntimeError("Existing diagnostic localization differs")
    else:
        client.post("/v1/inAppPurchaseLocalizations", payloads["/v1/inAppPurchaseLocalizations"])
    if not optional(client, f"/v2/inAppPurchases/{identifier}/inAppPurchaseAvailability"):
        client.post("/v1/inAppPurchaseAvailabilities", payloads["/v1/inAppPurchaseAvailabilities"])
    schedule = optional(client, f"/v2/inAppPurchases/{identifier}/iapPriceSchedule")
    # Apple exposes a schedule resource even before the new product has prices.
    # Its existence alone does not mean a price has been configured.
    current_prices = prices(client, schedule["id"]) if schedule else {}
    if not current_prices:
        client.post("/v1/inAppPurchasePriceSchedules", payloads["/v1/inAppPurchasePriceSchedules"])
    elif {k: Decimal(v) for k, v in current_prices.items()} != {k: Decimal(v) for k, v in source_prices.items()}:
        raise RuntimeError("Existing diagnostic prices differ; refusing to overwrite them")
    complete_review_screenshot(client, source["id"], identifier)
    after = source_snapshot(client, identifier)
    actual_prices = prices(client, after["price_schedule_id"])
    if after["territories"] != before["territories"] or after["availableInNewTerritories"] != before["availableInNewTerritories"]:
        raise RuntimeError("Diagnostic availability does not match")
    if {k: Decimal(v) for k, v in actual_prices.items()} != {k: Decimal(v) for k, v in source_prices.items()}:
        raise RuntimeError("Diagnostic prices do not match: " + json.dumps(actual_prices))
    if source_snapshot(client, source["id"]) != before or prices(client, before["price_schedule_id"]) != source_prices:
        raise RuntimeError("Reference changed during operation; inspect before testing")
    Path("diagnostic-iap-result.json").write_text(json.dumps({"diagnostic": after,
        "prices": actual_prices, "source_unchanged": True}, ensure_ascii=False, indent=2))
    print(json.dumps({"product_id": PRODUCT, "id": identifier, "state": after["attributes"]["state"],
        "prices": actual_prices, "territories": len(after["territories"]), "source_unchanged": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
