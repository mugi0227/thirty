"""Fill in the App Store Connect listing through the App Store Connect API.

usage: asc_metadata.py [--dry-run] [--skip-media] release/metadata-ja.json

Sets the app name, subtitle, privacy policy URL, categories, description,
keywords, promotional text, support and marketing URLs, copyright and the
review notes, then replaces the screenshots and the app preview.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 (the .p8 text) in the
environment. The app record must already exist in App Store Connect.
Left to the web page: price, App Privacy, age rating, review contact,
attaching the in-app purchase and the build, and pressing "Submit".
"""
import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
ROOT = Path(__file__).resolve().parents[1]


class Client:
    def __init__(self, dry_run):
        self.dry_run = dry_run
        self.session = requests.Session()
        self.token_time = 0
        self.token = None

    def headers(self):
        if time.time() - self.token_time > 600:
            now = int(time.time())
            self.token = jwt.encode(
                {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
            self.token_time = time.time()
        return {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"}

    def request(self, method, path, body=None, params=None, write=False):
        if write and self.dry_run:
            print(f"  [dry-run] {method} {path} {json.dumps(body, ensure_ascii=False)[:300] if body else ''}")
            return {"data": {"id": "dry-run", "attributes": {"uploadOperations": []}}}
        response = self.session.request(method, API + path, headers=self.headers(), json=body, params=params, timeout=60)
        if response.status_code >= 400:
            print(f"!! {method} {path} -> {response.status_code}\n{response.text[:2000]}", file=sys.stderr)
            response.raise_for_status()
        return response.json() if response.text else {}

    def get(self, path, **params):
        return self.request("GET", path, params=params or None)

    def patch(self, path, body):
        return self.request("PATCH", path, body, write=True)

    def post(self, path, body):
        return self.request("POST", path, body, write=True)

    def delete(self, path):
        return self.request("DELETE", path, write=True)


def find_one(items, locale):
    return next((item for item in items if item["attributes"].get("locale") == locale), None)


def update_app_info(client, app_id, config, locale):
    infos = client.get(f"/v1/apps/{app_id}/appInfos")["data"]
    # The editable one is the info that is not live yet.
    info = next((i for i in infos if i["attributes"].get("appStoreState") != "READY_FOR_SALE"), infos[0])
    print(f"appInfo {info['id']} ({info['attributes'].get('appStoreState') or info['attributes'].get('state')})")
    attributes = {"name": config["name"], "subtitle": config["subtitle"], "privacyPolicyUrl": config["privacy_policy_url"]}
    localizations = client.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
    current = find_one(localizations, locale)
    if current:
        client.patch(f"/v1/appInfoLocalizations/{current['id']}",
                     {"data": {"type": "appInfoLocalizations", "id": current["id"], "attributes": attributes}})
    else:
        client.post("/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": locale, **attributes},
                    "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
    print("  name, subtitle, privacy policy URL")
    client.patch(f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": config["primary_category"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": config["secondary_category"]}},
    }}})
    print(f"  categories {config['primary_category']} / {config['secondary_category']}")


def editable_version(client, app_id):
    versions = client.get(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": "IOS", "limit": 10})["data"]
    editable = [v for v in versions if v["attributes"].get("appStoreState") in
                ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")]
    if not editable:
        sys.exit("No editable iOS version. Create one in App Store Connect first.")
    version = editable[0]
    print(f"version {version['attributes']['versionString']} ({version['attributes']['appStoreState']})")
    return version


def update_version(client, version, config, locale):
    text = lambda key: (ROOT / config[key]).read_text(encoding="utf-8").strip()
    client.patch(f"/v1/appStoreVersions/{version['id']}", {"data": {"type": "appStoreVersions", "id": version["id"],
                 "attributes": {"copyright": config["copyright"]}}})
    attributes = {"description": text("description_file"), "keywords": config["keywords"],
                  "promotionalText": config["promotional_text"], "supportUrl": config["support_url"],
                  "marketingUrl": config["marketing_url"]}
    assert len(config["keywords"]) <= 100, "keywords are over 100 characters"
    localizations = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    current = find_one(localizations, locale)
    if current:
        client.patch(f"/v1/appStoreVersionLocalizations/{current['id']}",
                     {"data": {"type": "appStoreVersionLocalizations", "id": current["id"], "attributes": attributes}})
    else:
        current = client.post("/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations",
                              "attributes": {"locale": locale, **attributes},
                              "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})["data"]
    print("  description, keywords, promotional text, URLs, copyright")

    notes = text("review_notes_file")
    detail = client.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if detail:
        client.patch(f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {"type": "appStoreReviewDetails", "id": detail["id"],
                     "attributes": {"notes": notes, "demoAccountRequired": False}}})
    else:
        client.post("/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails",
                    "attributes": {"notes": notes, "demoAccountRequired": False},
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print("  review notes")
    return current["id"]


def upload(client, kind, set_type, set_id, path, extra):
    data = path.read_bytes()
    created = client.post(f"/v1/{kind}", {"data": {"type": kind, "attributes": {"fileName": path.name, "fileSize": len(data), **extra},
                          "relationships": {set_type[:-1] if set_type.endswith("s") else set_type:
                                            {"data": {"type": set_type, "id": set_id}}}}})["data"]
    for operation in created["attributes"].get("uploadOperations") or []:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        requests.request(operation["method"], operation["url"], headers=headers, data=chunk, timeout=120).raise_for_status()
    client.patch(f"/v1/{kind}/{created['id']}", {"data": {"type": kind, "id": created["id"], "attributes": {
                 "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return created["id"]


def replace_media(client, localization_id, config):
    sets = client.get(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")["data"]
    for display_type, folder in config["screenshots"].items():
        files = sorted((ROOT / folder).glob("*.png"))
        existing = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
        if existing:
            for shot in client.get(f"/v1/appScreenshotSets/{existing['id']}/appScreenshots")["data"]:
                client.delete(f"/v1/appScreenshots/{shot['id']}")
            set_id = existing["id"]
        else:
            set_id = client.post("/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                                 "attributes": {"screenshotDisplayType": display_type},
                                 "relationships": {"appStoreVersionLocalization": {"data": {
                                     "type": "appStoreVersionLocalizations", "id": localization_id}}}}})["data"]["id"]
        ids = [upload(client, "appScreenshots", "appScreenshotSets", set_id, f, {}) for f in files]
        client.patch(f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
                     {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        print(f"  {display_type}: {len(ids)} screenshots from {folder}")

    preview_sets = client.get(f"/v1/appStoreVersionLocalizations/{localization_id}/appPreviewSets")["data"]
    for preview_type, file in config.get("previews", {}).items():
        existing = next((s for s in preview_sets if s["attributes"]["previewType"] == preview_type), None)
        if existing:
            for preview in client.get(f"/v1/appPreviewSets/{existing['id']}/appPreviews")["data"]:
                client.delete(f"/v1/appPreviews/{preview['id']}")
            set_id = existing["id"]
        else:
            set_id = client.post("/v1/appPreviewSets", {"data": {"type": "appPreviewSets",
                                 "attributes": {"previewType": preview_type},
                                 "relationships": {"appStoreVersionLocalization": {"data": {
                                     "type": "appStoreVersionLocalizations", "id": localization_id}}}}})["data"]["id"]
        upload(client, "appPreviews", "appPreviewSets", set_id, ROOT / file, {"mimeType": "video/mp4"})
        print(f"  {preview_type}: app preview {file}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-media", action="store_true")
    args = parser.parse_args()
    config = json.loads((ROOT / args.config).read_text(encoding="utf-8"))
    client = Client(args.dry_run)
    apps = client.get("/v1/apps", **{"filter[bundleId]": config["bundle_id"]})["data"]
    if not apps:
        sys.exit(f"No app with bundle ID {config['bundle_id']}. Create it in App Store Connect first.")
    app_id = apps[0]["id"]
    print(f"app {apps[0]['attributes']['name']} ({app_id})")
    update_app_info(client, app_id, config["app_info"], config["locale"])
    version = editable_version(client, app_id)
    localization_id = update_version(client, version, config["version"], config["locale"])
    if not args.skip_media:
        replace_media(client, localization_id, config)
    print("done")


if __name__ == "__main__":
    main()
