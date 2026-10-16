import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from submit_app_review import submit, validate_selection


def item(kind, identifier, removed=False):
    return {"attributes": {"removed": removed},
            "relationships": {kind: {"data": {"id": identifier}}}}


class Client:
    def __init__(self, state="READY_FOR_REVIEW", disconnect=False, confirm=True):
        self.data = {"id": "draft", "attributes": {"state": state}}
        self.writes = []
        self.disconnect = disconnect
        self.confirm = confirm

    def get(self, path):
        return {"data": copy.deepcopy(self.data)}

    def patch(self, path, body):
        self.writes.append((path, body))
        if self.confirm:
            self.data["attributes"] = {"state": "WAITING_FOR_REVIEW", "submittedDate": "2026-10-16T01:00:00Z"}
        if self.disconnect:
            raise TimeoutError("The accepted response was lost")


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.build = {"attributes": {"version": "22", "processingState": "VALID", "expired": False}}
        self.items = [item("appStoreVersion", "version"), item("inAppPurchaseVersion", "current")]

    def check(self):
        validate_selection(self.build, "22", self.items, "version", {"current"})

    def test_wrong_build_is_rejected(self):
        self.build["attributes"]["version"] = "23"
        with self.assertRaises(RuntimeError):
            self.check()

    def test_expired_build_is_rejected(self):
        self.build["attributes"]["expired"] = True
        with self.assertRaises(RuntimeError):
            self.check()

    def test_legacy_product_is_rejected(self):
        self.items[1] = item("inAppPurchaseVersion", "legacy")
        with self.assertRaises(RuntimeError):
            self.check()

    def test_additional_review_item_is_rejected(self):
        self.items.append(item("appStoreVersion", "other"))
        with self.assertRaises(RuntimeError):
            self.check()

    def test_duplicate_app_and_missing_product_are_rejected(self):
        self.items[1] = item("appStoreVersion", "version")
        with self.assertRaises(RuntimeError):
            self.check()

    def test_removed_legacy_item_is_ignored(self):
        self.items.append(item("inAppPurchaseVersion", "legacy", removed=True))
        self.check()


class SubmissionTests(unittest.TestCase):
    def test_submit_once_and_read_back(self):
        client = Client()
        result = submit(client, "draft")
        self.assertEqual(result["attributes"]["state"], "WAITING_FOR_REVIEW")
        self.assertEqual(client.writes, [("/v1/reviewSubmissions/draft", {
            "data": {"type": "reviewSubmissions", "id": "draft", "attributes": {"submitted": True}}})])

    def test_already_submitted_is_read_only(self):
        client = Client(state="IN_REVIEW")
        submit(client, "draft")
        self.assertFalse(client.writes)

    def test_lost_response_is_read_back_without_second_write(self):
        client = Client(disconnect=True)
        result = submit(client, "draft")
        self.assertEqual(result["attributes"]["state"], "WAITING_FOR_REVIEW")
        self.assertEqual(len(client.writes), 1)

    def test_unresolved_submission_is_not_reported_as_accepted(self):
        client = Client(state="UNRESOLVED_ISSUES")
        client.data["attributes"]["submittedDate"] = "2026-10-15T00:00:00Z"
        with self.assertRaises(RuntimeError):
            submit(client, "draft")
        self.assertFalse(client.writes)

    def test_unconfirmed_request_is_not_blindly_repeated(self):
        client = Client(confirm=False)
        with patch("submit_app_review.time.sleep"), self.assertRaises(RuntimeError):
            submit(client, "draft")
        self.assertEqual(len(client.writes), 1)


if __name__ == "__main__":
    unittest.main()
