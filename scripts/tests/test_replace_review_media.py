import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from replace_review_media import PURCHASE_VERSION, cancel_once, restore_items, validate_partial, validate_target


def item(kind, identifier):
    return {"attributes": {}, "relationships": {kind: {"data": {"id": identifier}}}}


class CancelClient:
    def __init__(self, disconnect=False, confirm=True):
        self.state = "WAITING_FOR_REVIEW"
        self.disconnect, self.confirm = disconnect, confirm
        self.writes = []

    def get(self, path):
        if "/appStoreVersions/" in path:
            state = "DEVELOPER_REJECTED" if self.state == "COMPLETE" else "WAITING_FOR_REVIEW"
            return {"data": {"attributes": {"appStoreState": state}}}
        return {"data": {"attributes": {"state": self.state}}}

    def patch(self, path, body):
        self.writes.append((path, body))
        if self.confirm:
            self.state = "COMPLETE"
        if self.disconnect:
            raise TimeoutError("Lost cancellation response")


class DraftClient:
    def __init__(self, initial=None, disconnect=False):
        self.selection = initial or []
        self.disconnect = disconnect
        self.writes = []

    def get(self, path, **kwargs):
        return {"data": copy.deepcopy(self.selection)}

    def post(self, path, body):
        self.writes.append((path, body))
        if path == "/v1/reviewSubmissions":
            return {"data": {"id": "draft"}}
        links = body["data"]["relationships"]
        name = "appStoreVersion" if "appStoreVersion" in links else "inAppPurchaseVersion"
        self.selection.append(item(name, links[name]["data"]["id"]))
        if self.disconnect:
            raise TimeoutError("Lost attachment response")
        return {"data": {"id": "item"}}


class GuardTests(unittest.TestCase):
    def test_different_build_or_legacy_iap_cannot_pass_preflight(self):
        build = {"attributes": {"version": "22", "processingState": "VALID", "expired": False}}
        selection = [item("appStoreVersion", "version"), item("inAppPurchaseVersion", PURCHASE_VERSION)]
        validate_target(build, "22", selection, "version")
        with self.assertRaises(RuntimeError):
            validate_target(build, "23", selection, "version")
        selection[1] = item("inAppPurchaseVersion", "legacy")
        with self.assertRaises(RuntimeError):
            validate_target(build, "22", selection, "version")

    def test_unknown_and_duplicate_draft_items_are_rejected(self):
        for selection in [[item("appStoreVersion", "other")],
                          [item("appStoreVersion", "version"), item("appStoreVersion", "version")]]:
            with self.assertRaises(RuntimeError):
                validate_partial(selection, "version")

    def test_lost_cancellation_response_does_not_repeat_the_write(self):
        client = CancelClient(disconnect=True)
        cancel_once(client, "approved", "version")
        self.assertEqual(client.writes, [("/v1/reviewSubmissions/approved", {"data": {
            "type": "reviewSubmissions", "id": "approved", "attributes": {"canceled": True}}})])

    def test_unconfirmed_cancellation_stops_before_media_can_be_changed(self):
        client = CancelClient(confirm=False)
        with patch("replace_review_media.time.sleep"), self.assertRaises(RuntimeError):
            cancel_once(client, "approved", "version")
        self.assertEqual(len(client.writes), 1)

    def test_first_purchase_is_added_after_the_app_version(self):
        client = DraftClient()
        self.assertEqual(restore_items(client, "version", []), "draft")
        kinds = [next(k for k in body["data"]["relationships"] if k != "reviewSubmission")
                 for path, body in client.writes if path == "/v1/reviewSubmissionItems"]
        self.assertEqual(kinds, ["appStoreVersion", "inAppPurchaseVersion"])

    def test_existing_valid_draft_is_reused_without_duplicate_items(self):
        client = DraftClient([item("appStoreVersion", "version"), item("inAppPurchaseVersion", PURCHASE_VERSION)])
        restore_items(client, "version", [{"id": "draft", "attributes": {"state": "READY_FOR_REVIEW"}}])
        self.assertFalse(client.writes)

    def test_lost_attachment_responses_do_not_duplicate_items(self):
        client = DraftClient(disconnect=True)
        restore_items(client, "version", [])
        self.assertEqual(len(client.selection), 2)
        self.assertEqual(len(client.writes), 3)


if __name__ == "__main__":
    unittest.main()
