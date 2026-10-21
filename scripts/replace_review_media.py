"""Withdraw the approved Thirty submission and restore its exact selection.

Media upload and final submission reuse the existing upload/submit helpers.
This helper never changes product metadata, prices, builds or release options.
"""
import argparse
import hashlib
import json
import time
from pathlib import Path

from submit_app_review import require, validate_selection

APP_ID = "6822135223"
BUILD = "22"
SKU = "jp.mugilab.thirty.diagnostic"
PURCHASE_VERSION = "9582d94e-37e0-4c6b-8f21-347d7b877804"
ROOT = Path(__file__).resolve().parents[1]
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED"}
ACTIVE = {"WAITING_FOR_REVIEW", "IN_REVIEW"}


def items(client, submission_id):
    return client.get(f"/v1/reviewSubmissions/{submission_id}/items",
                      include="appStoreVersion,inAppPurchaseVersion", limit=200)["data"]


def validate_target(build, expected_build, selection, version_id):
    require(expected_build == BUILD, "Only the approved build 22 is supported")
    validate_selection(build, expected_build, selection, version_id, {PURCHASE_VERSION})


def context(client, expected_build, submission_id):
    require(expected_build == BUILD, "Only the approved build 22 is supported")
    apps = client.get("/v1/apps", **{"filter[bundleId]": "jp.mugilab.thirty"})["data"]
    require(len(apps) == 1 and apps[0]["id"] == APP_ID, "Expected the Thirty app")
    versions = client.get(f"/v1/apps/{APP_ID}/appStoreVersions",
                          **{"filter[platform]": "IOS", "limit": 50})["data"]
    matches = [v for v in versions if v["attributes"]["versionString"] == "1.0"]
    require(len(matches) == 1, "Expected the approved version 1.0")
    version = matches[0]
    require(version["attributes"]["releaseType"] == "AFTER_APPROVAL", "Release option changed")
    build = client.get(f"/v1/appStoreVersions/{version['id']}/build")["data"]
    require(build and build["attributes"]["version"] == expected_build and
            build["attributes"]["processingState"] == "VALID" and
            not build["attributes"].get("expired"), "Selected build is not the approved valid build 22")
    submissions = client.get(f"/v1/apps/{APP_ID}/reviewSubmissions", limit=200)["data"]
    selected = next((s for s in submissions if s["id"] == submission_id), None)
    require(selected is not None, "The specified submission does not belong to Thirty")
    purchases = client.get(f"/v1/apps/{APP_ID}/inAppPurchasesV2", limit=200)["data"]
    purchase = next((p for p in purchases if p["attributes"]["productId"] == SKU), None)
    require(purchase is not None, "The approved Thirty+ product is missing")
    versions = client.get(f"/v2/inAppPurchases/{purchase['id']}/versions", limit=200)["data"]
    require(any(v["id"] == PURCHASE_VERSION for v in versions), "The approved Thirty+ version is missing")
    return version, build, selected, submissions


def cancel_once(client, submission_id, version_id):
    path = f"/v1/reviewSubmissions/{submission_id}"
    current = client.get(path)["data"]
    if current["attributes"]["state"] in ACTIVE:
        try:
            client.patch(path, {"data": {"type": "reviewSubmissions", "id": submission_id,
                                        "attributes": {"canceled": True}}})
        except Exception:
            current = client.get(path)["data"]
            if current["attributes"]["state"] in ACTIVE and not current["attributes"].get("canceled"):
                raise
    for _ in range(30):
        current = client.get(path)["data"]
        version = client.get(f"/v1/appStoreVersions/{version_id}")["data"]
        if version["attributes"]["appStoreState"] in EDITABLE and current["attributes"]["state"] not in ACTIVE:
            return current, version
        time.sleep(5)
    raise RuntimeError("Cancellation is not confirmed; inspect before continuing")


def validate_partial(selection, version_id):
    seen = set()
    for item in selection:
        if item.get("attributes", {}).get("removed"):
            continue
        links = item.get("relationships", {})
        version = (links.get("appStoreVersion", {}).get("data") or {}).get("id")
        purchase = (links.get("inAppPurchaseVersion", {}).get("data") or {}).get("id")
        kind = "app" if version == version_id and not purchase else (
            "purchase" if purchase == PURCHASE_VERSION and not version else None)
        require(kind is not None and kind not in seen, "Draft contains an unexpected or duplicate item")
        seen.add(kind)
    return seen


def ready_drafts(submissions):
    drafts = [s for s in submissions if s["attributes"]["state"] == "READY_FOR_REVIEW"
              and not s["attributes"].get("submittedDate")]
    require(len(drafts) <= 1, "Multiple unsubmitted drafts exist; nothing created")
    return drafts


def restore_items(client, version_id, submissions):
    drafts = ready_drafts(submissions)
    if drafts:
        draft = drafts[0]
        seen = validate_partial(items(client, draft["id"]), version_id)
    else:
        try:
            draft = client.post("/v1/reviewSubmissions", {"data": {
                "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
        except Exception:
            drafts = ready_drafts(client.get(f"/v1/apps/{APP_ID}/reviewSubmissions", limit=200)["data"])
            if not drafts:
                raise
            draft = drafts[0]
        seen = validate_partial(items(client, draft["id"]), version_id)
    # A first IAP requires the app version to be in the draft before adding it.
    for name, kind, identifier, marker in [
        ("appStoreVersion", "appStoreVersions", version_id, "app"),
        ("inAppPurchaseVersion", "inAppPurchaseVersions", PURCHASE_VERSION, "purchase"),
    ]:
        if marker in seen:
            continue
        try:
            client.post("/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": draft["id"]}},
                name: {"data": {"type": kind, "id": identifier}}}}})
        except Exception:
            seen = validate_partial(items(client, draft["id"]), version_id)
            if marker not in seen:
                raise
        seen.add(marker)
    return draft["id"]


def verify_media(client, version_id, config):
    locales = client.get(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    matches = [v for v in locales if v["attributes"]["locale"] == config["locale"]]
    require(len(matches) == 1, "Expected the approved Japanese localization")
    locale_id = matches[0]["id"]
    report = []
    for collection, field, assets, expected in [
        ("appScreenshotSets", "screenshotDisplayType", "appScreenshots", config["screenshots"]),
        ("appPreviewSets", "previewType", "appPreviews", config["previews"]),
    ]:
        sets = client.get(f"/v1/appStoreVersionLocalizations/{locale_id}/{collection}")["data"]
        for display, location in expected.items():
            matching = [s for s in sets if s["attributes"][field] == display]
            require(len(matching) == 1, f"Expected one media set for {display}")
            remote = client.get(f"/v1/{collection}/{matching[0]['id']}/{assets}")["data"]
            files = sorted((ROOT / location).glob("*.png")) if assets == "appScreenshots" else [ROOT / location]
            local = {p.name: p for p in files}
            require(len(remote) == len(local) and {r["attributes"]["fileName"] for r in remote} == set(local),
                    f"{display}: filenames or counts do not match the approved media")
            for item in remote:
                attributes = item["attributes"]
                path = local[attributes["fileName"]]
                require(attributes.get("assetDeliveryState", {}).get("state") == "COMPLETE",
                        f"{display}/{path.name}: media is not processed")
                require(attributes["fileSize"] == path.stat().st_size, f"{path.name}: file size differs")
                checksum = attributes.get("sourceFileChecksum")
                if checksum:
                    require(checksum.lower() == hashlib.md5(path.read_bytes()).hexdigest(), f"{path.name}: checksum differs")
                report.append({"display": display, "file": path.name, "id": item["id"],
                               "state": "COMPLETE", "checksum_verified": bool(checksum)})
    require(len(report) == 27, "Expected exactly the approved 26 screenshots and one preview")
    return report


def upload_media(client, version, config, replace):
    require(version["attributes"]["appStoreState"] in EDITABLE, "The version is not editable")
    locales = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    matches = [v for v in locales if v["attributes"]["locale"] == config["locale"]]
    require(len(matches) == 1, "Expected the approved Japanese localization")
    replace(client, matches[0]["id"], config)


def main():
    from asc_metadata import Client, check_media_files, replace_media
    from prepare_listing_draft import wait_for_media

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["withdraw", "upload", "restore", "verify"])
    parser.add_argument("--build", required=True)
    parser.add_argument("--submission", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    report = {"action": args.action, "build": args.build, "submission_id": args.submission, "dry_run": args.dry_run}
    try:
        config = json.loads((ROOT / "release/metadata-ja.json").read_text())
        check_media_files(config)
        client = Client(args.dry_run)
        version, build, selected, submissions = context(client, args.build, args.submission)
        report.update({"version_id": version["id"], "version_state": version["attributes"]["appStoreState"],
                       "submission_state": selected["attributes"]["state"], "product": SKU})
        print(json.dumps({"preflight": report}, ensure_ascii=False), flush=True)
        if args.action == "withdraw":
            if version["attributes"]["appStoreState"] in EDITABLE and selected["attributes"]["state"] not in ACTIVE:
                report["already_editable"] = True
            else:
                require(version["attributes"]["appStoreState"] in ACTIVE and selected["attributes"]["state"] in ACTIVE,
                        "The approved submission is no longer in a cancellable review state")
                validate_target(build, args.build, items(client, selected["id"]), version["id"])
                if not args.dry_run:
                    selected, version = cancel_once(client, selected["id"], version["id"])
                    report.update({"version_state": version["attributes"]["appStoreState"],
                                   "submission_state": selected["attributes"]["state"], "cancelled": True})
        elif args.action == "upload":
            upload_media(client, version, config, replace_media)
            report["uploaded"] = not args.dry_run
        elif args.action == "restore":
            require(version["attributes"]["appStoreState"] in EDITABLE, "The version is not editable")
            wait_for_media(client, version, config)
            report["media"] = verify_media(client, version["id"], config)
            drafts = ready_drafts(submissions)
            if drafts:
                validate_partial(items(client, drafts[0]["id"]), version["id"])
            if not args.dry_run:
                draft_id = restore_items(client, version["id"], submissions)
                validate_target(client.get(f"/v1/appStoreVersions/{version['id']}/build")["data"],
                                args.build, items(client, draft_id), version["id"])
                draft = client.get(f"/v1/reviewSubmissions/{draft_id}")["data"]
                require(draft["attributes"]["state"] == "READY_FOR_REVIEW" and
                        not draft["attributes"].get("submittedDate"), "The restored draft is not ready and unsubmitted")
                report.update({"submission_id": draft_id, "submission_state": "READY_FOR_REVIEW", "submitted": False})
        else:
            validate_target(build, args.build, items(client, selected["id"]), version["id"])
            report["media"] = verify_media(client, version["id"], config)
            report["submitted_date"] = selected["attributes"].get("submittedDate")
        print(json.dumps(report, ensure_ascii=False), flush=True)
    except Exception as error:
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        Path("review-media-operation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
