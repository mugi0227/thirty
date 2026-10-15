"""Reopen and prepare Thirty's existing unsubmitted App Review draft.

No operation submits a review or cancels a submitted review. Reopening is
needed because Apple disallows editing images/video in READY_FOR_REVIEW.
"""
import argparse
import json
import re
import time

from asc_metadata import Client, ROOT


def relation(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def linked(item, name):
    return (item.get("relationships", {}).get(name, {}).get("data") or {}).get("id")


def items(client, submission_id):
    return client.get(f"/v1/reviewSubmissions/{submission_id}/items",
                      include="appStoreVersion,inAppPurchaseVersion", limit=200)["data"]


def remove(client, item):
    client.patch(f"/v1/reviewSubmissionItems/{item['id']}", {"data": {
        "type": "reviewSubmissionItems", "id": item["id"], "attributes": {"removed": True}}})


def add(client, submission_id, name, kind, identifier):
    return client.post("/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": relation("reviewSubmissions", submission_id),
            name: relation(kind, identifier)}}})["data"]


def wait_for_media(client, version, config):
    locales = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    locale = next(x for x in locales if x["attributes"]["locale"] == config["locale"])
    deadline = time.monotonic() + 480
    while True:
        states = []
        for collection, field, assets in [("appScreenshotSets", "screenshotDisplayType", "appScreenshots"),
                                           ("appPreviewSets", "previewType", "appPreviews")]:
            sets = client.get(f"/v1/appStoreVersionLocalizations/{locale['id']}/{collection}")["data"]
            expected = config["screenshots"] if assets == "appScreenshots" else config["previews"]
            for display in expected:
                media_set = next(x for x in sets if x["attributes"][field] == display)
                media = client.get(f"/v1/{collection}/{media_set['id']}/{assets}")["data"]
                expected_count = (8 if "IPAD" in display else 9) if assets == "appScreenshots" else 1
                if len(media) != expected_count:
                    raise RuntimeError(f"{display}: expected {expected_count} assets, found {len(media)}")
                states.extend(x["attributes"].get("assetDeliveryState", {}).get("state") for x in media)
        print("Media processing:", {state: states.count(state) for state in set(states)}, flush=True)
        if all(state == "COMPLETE" for state in states):
            return
        if "FAILED" in states or time.monotonic() >= deadline:
            raise RuntimeError("Media is not ready; the version stays editable and unsubmitted")
        time.sleep(15)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["inspect", "reopen", "finish"])
    parser.add_argument("--build", default="")
    args = parser.parse_args()
    config = json.loads((ROOT / "release/metadata-ja.json").read_text())
    client = Client(False)
    app = client.get("/v1/apps", **{"filter[bundleId]": config["bundle_id"]})["data"][0]
    versions = client.get(f"/v1/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS", "limit": 10})["data"]
    version = next(x for x in versions if x["attributes"]["versionString"] == "1.0")
    submissions = client.get(f"/v1/apps/{app['id']}/reviewSubmissions", limit=50)["data"]
    drafts = [x for x in submissions if x["attributes"]["state"] == "READY_FOR_REVIEW"
              and not x["attributes"].get("submittedDate")]
    if len(drafts) != 1:
        raise RuntimeError("Expected exactly one existing unsubmitted draft; nothing changed")
    draft = drafts[0]
    current = items(client, draft["id"])
    print(json.dumps({"version_state": version["attributes"]["appStoreState"],
        "draft": draft, "items": current}, ensure_ascii=False), flush=True)
    if args.action == "inspect":
        return
    if args.action == "reopen":
        state = version["attributes"]["appStoreState"]
        if state == "PREPARE_FOR_SUBMISSION":
            print("Already editable; nothing changed")
            return
        if state != "READY_FOR_REVIEW":
            raise RuntimeError(f"Will not reopen version in state {state}")
        matches = [x for x in current if linked(x, "appStoreVersion") == version["id"]]
        if len(matches) != 1:
            raise RuntimeError("Cannot identify this app version's draft item; nothing changed")
        remove(client, matches[0])
        updated = client.get(f"/v1/appStoreVersions/{version['id']}")["data"]
        if updated["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
            raise RuntimeError("Version did not become editable; inspect before continuing")
        print("Unsubmitted app version is editable; no review was submitted or cancelled")
        return

    if version["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
        raise RuntimeError("Finish expects an editable version")
    if not args.build.isdigit():
        raise RuntimeError("An exact tested build number is required")
    wait_for_media(client, version, config)
    builds = client.get("/v1/builds", **{"filter[app]": app["id"], "filter[version]": args.build,
                                        "filter[processingState]": "VALID", "limit": 10})["data"]
    if len(builds) != 1 or builds[0]["attributes"].get("expired"):
        raise RuntimeError("Expected one valid, unexpired build; nothing selected")
    build = builds[0]
    prerelease = client.get(f"/v1/builds/{build['id']}/preReleaseVersion")["data"]
    def normal(text):
        parts = [int(x) for x in text.split(".")]
        while len(parts) > 1 and parts[-1] == 0:
            parts.pop()
        return tuple(parts)
    if normal(prerelease["attributes"]["version"]) != normal(version["attributes"]["versionString"]):
        raise RuntimeError("Build marketing version does not match the app version")
    product_source = (ROOT / "ios/Thirty/PlusProducts.swift").read_text()
    sku = re.search(r'purchaseID\s*=\s*"([^"]+)"', product_source).group(1)
    legacy = re.search(r'legacyID\s*=\s*"([^"]+)"', product_source).group(1)
    purchases = client.get(f"/v1/apps/{app['id']}/inAppPurchasesV2", limit=200)["data"]
    purchase = next(x for x in purchases if x["attributes"]["productId"] == sku)
    purchase_versions = client.get(f"/v2/inAppPurchases/{purchase['id']}/versions", limit=200)["data"]
    candidates = [x for x in purchase_versions if x["attributes"]["state"] in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW")]
    if len(candidates) != 1:
        raise RuntimeError("Cannot identify the working product's review version")
    purchase_version = candidates[0]
    legacy_purchase = next(x for x in purchases if x["attributes"]["productId"] == legacy)
    legacy_ids = {x["id"] for x in client.get(f"/v2/inAppPurchases/{legacy_purchase['id']}/versions", limit=200)["data"]}
    client.patch(f"/v1/appStoreVersions/{version['id']}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
    if not any(linked(x, "inAppPurchaseVersion") == purchase_version["id"] for x in current):
        add(client, draft["id"], "inAppPurchaseVersion", "inAppPurchaseVersions", purchase_version["id"])
    # Add the verified replacement before removing only the old product's item.
    for item in current:
        if linked(item, "inAppPurchaseVersion") in legacy_ids:
            remove(client, item)
    add(client, draft["id"], "appStoreVersion", "appStoreVersions", version["id"])
    selected = client.get(f"/v1/appStoreVersions/{version['id']}/build")["data"]
    final_items = items(client, draft["id"])
    if selected["id"] != build["id"] or not any(linked(x, "inAppPurchaseVersion") == purchase_version["id"] for x in final_items):
        raise RuntimeError("Draft selection did not read back correctly")
    final_draft = client.get(f"/v1/reviewSubmissions/{draft['id']}")["data"]
    if final_draft["attributes"].get("submittedDate"):
        raise RuntimeError("Unexpected submittedDate: inspect the submission")
    print(json.dumps({"selected_build": args.build, "selected_product": sku,
                      "state": final_draft["attributes"]["state"], "submitted": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
