import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from media_state import delivery_state


class MediaStateTests(unittest.TestCase):
    def test_preview_accepts_current_complete_over_stale_upload_complete(self):
        self.assertEqual(delivery_state({"assetDeliveryState": {"state": "UPLOAD_COMPLETE"},
                                         "videoDeliveryState": {"state": "COMPLETE"}}, video=True), "COMPLETE")

    def test_preview_does_not_accept_stale_complete_when_current_is_failed(self):
        self.assertEqual(delivery_state({"assetDeliveryState": {"state": "COMPLETE"},
                                         "videoDeliveryState": {"state": "FAILED"}}, video=True), "FAILED")

    def test_preview_does_not_accept_stale_complete_when_current_is_processing(self):
        self.assertEqual(delivery_state({"assetDeliveryState": {"state": "COMPLETE"},
                                         "videoDeliveryState": {"state": "PROCESSING"}}, video=True), "PROCESSING")

    def test_preview_supports_older_responses(self):
        self.assertEqual(delivery_state({"assetDeliveryState": {"state": "COMPLETE"}}, video=True), "COMPLETE")

    def test_screenshots_use_image_state(self):
        self.assertEqual(delivery_state({"assetDeliveryState": {"state": "FAILED"},
                                         "videoDeliveryState": {"state": "COMPLETE"}}), "FAILED")


if __name__ == "__main__":
    unittest.main()
