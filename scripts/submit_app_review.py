"""Submit the explicitly selected Thirty review draft through Apple's API.

The caller must supply the approved build and submission ID. Dry runs perform
the same checks using GET requests. No listing, product or release settings
are changed. API reference: /documentation/appstoreconnectapi/patch-v1-reviewsubmissions-_id_
"""
import argparse
import json
import re
import time
from pathlib import Path


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def validate_selection(build, expected_build, items, version_id, purchase_version_ids):
    require(build and build["attributes"]["version"] == expected_build,
            "The selected build differs from the approved build")
    require(build["attributes"]["processingState"] == "VALID" and not build["attributes"].get("expired"),
            "The approved build is not valid or has expired")
    active = [item for item in items if not item.get("attributes", {}).get("removed")]
    kinds = []
    for item in active:
        links = item.get("relationships", {})
        version = (links.get("appStoreVersion", {}).get("data") or {}).get("id")
        purchase = (links.get("inAppPurchaseVersion", {}).get("data") or {}).get("id")
        if version == version_id and not purchase:
            kinds.append("app")
        elif purchase in purchase_version_ids and not version:
            kinds.append("purchase")
        else:
            raise RuntimeError("The draft contains an unapproved review item")
    require(sorted(kinds) == ["app", "purchase"],
            "Expected exactly the approved app version and Thirty+ purchase")


def accepted(submission):
    attributes = submission["attributes"]
    return attributes["state"] in {
        "WAITING_FOR_REVIEW", "IN_REVIEW", "COMPLETING", "COMPLETE"}


def submit(client, submission_id):
    path = f"/v1/reviewSubmissions/{submission_id}"
    current = client.get(path)["data"]
    if accepted(current):
        return current
    require(current["attributes"]["state"] == "READY_FOR_REVIEW", "The selected draft is not ready")
    body = {"data": {"type": "reviewSubmissions", "id": submission_id,
                     "attributes": {"submitted": True}}}
    try:
        client.patch(path, body)
    except Exception:
        # A disconnected response can follow an accepted request. Read back
        # once; never blindly repeat the submission write.
        current = client.get(path)["data"]
        if accepted(current):
            return current
        raise
    for _ in range(12):
        current = client.get(path)["data"]
        if accepted(current):
            return current
        time.sleep(10)
    raise RuntimeError("Submission was requested but not yet confirmed; inspect before retrying")


def main():
    from asc_metadata import Client, ROOT
    from prepare_listing_draft import items, wait_for_media

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True)
    parser.add_argument("--submission", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    require(args.build.isdigit() and bool(args.submission.strip()), "An exact build and draft ID are required")
    config = json.loads((ROOT / "release/metadata-ja.json").read_text())
    client = Client(args.dry_run)
    apps = client.get("/v1/apps", **{"filter[bundleId]": config["bundle_id"]})["data"]
    require(len(apps) == 1 and apps[0]["id"] == "6822135223", "Expected the Thirty app")
    app = apps[0]
    versions = client.get(f"/v1/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "IOS", "limit": 10})["data"]
    matching = [v for v in versions if v["attributes"]["versionString"] == "1.0"]
    require(len(matching) == 1, "Cannot identify the approved version 1.0")
    version = matching[0]
    submissions = client.get(f"/v1/apps/{app['id']}/reviewSubmissions", limit=50)["data"]
    draft = next((s for s in submissions if s["id"] == args.submission), None)
    require(draft is not None, "The specified draft does not belong to Thirty")
    sku = re.search(r'purchaseID\s*=\s*"([^"]+)"', (ROOT / "ios/Thirty/PlusProducts.swift").read_text()).group(1)
    require(sku == "jp.mugilab.thirty.diagnostic", "The current purchase differs from the approved Thirty+")
    purchases = client.get(f"/v1/apps/{app['id']}/inAppPurchasesV2", limit=200)["data"]
    purchase = next(p for p in purchases if p["attributes"]["productId"] == sku)
    purchase_ids = {p["id"] for p in client.get(f"/v2/inAppPurchases/{purchase['id']}/versions", limit=200)["data"]}
    approved_purchase = "9582d94e-37e0-4c6b-8f21-347d7b877804"
    require(approved_purchase in purchase_ids, "Cannot identify the approved Thirty+ review version")
    purchase_ids = {approved_purchase}
    build = client.get(f"/v1/appStoreVersions/{version['id']}/build")["data"]
    validate_selection(build, args.build, items(client, draft["id"]), version["id"], purchase_ids)
    plan = {"app_id": app["id"], "version": "1.0", "build": args.build,
            "product": sku, "submission_id": draft["id"],
            "release_type": version["attributes"]["releaseType"], "dry_run": args.dry_run}
    if not accepted(draft):
        require(version["attributes"]["appStoreState"] == "READY_FOR_REVIEW" and
                draft["attributes"]["state"] == "READY_FOR_REVIEW", "The approved draft is not ready for review")
        require(build["attributes"].get("usesNonExemptEncryption") is False, "Export compliance is incomplete")
        locales = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
        locale = next(l for l in locales if l["attributes"]["locale"] == config["locale"])
        require(locale["attributes"]["description"].strip() ==
                (ROOT / config["version"]["description_file"]).read_text().strip(), "The listing differs from the approved copy")
        detail = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail")["data"]["attributes"]
        require(all(detail.get(k) for k in ["contactFirstName", "contactLastName", "contactPhone", "contactEmail", "notes"]),
                "Review contact or notes are incomplete")
        wait_for_media(client, version, config)
        # Recheck mutable selection immediately before the sole submission write.
        validate_selection(client.get(f"/v1/appStoreVersions/{version['id']}/build")["data"], args.build,
                           items(client, draft["id"]), version["id"], purchase_ids)
    print(json.dumps({"preflight": "passed", **plan}, ensure_ascii=False), flush=True)
    if args.dry_run:
        result = {**plan, "submitted": accepted(draft), "state": draft["attributes"]["state"]}
    else:
        final = submit(client, draft["id"])
        updated = client.get(f"/v1/appStoreVersions/{version['id']}")["data"]
        result = {**plan, "submitted": True, "state": final["attributes"]["state"],
                  "submitted_date": final["attributes"].get("submittedDate"),
                  "version_state": updated["attributes"]["appStoreState"]}
    Path("app-review-submission.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
