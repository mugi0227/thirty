"""Check the bundled release fonts without making any network requests."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets/store-fonts"
EXPECTED = {
    "ZenKakuGothicNew-Bold.ttf": "0081cedabc4921982fcd061f845a005664ac7fb642af2dd34b4007bc63ccd235",
    "ZenKakuGothicNew-Medium.ttf": "651a3f7280b7f36262601ee76d8388a8dc4372dcc67aff025a608939a562b525",
    "ZenOldMincho-Bold.ttf": "d6b95c1ff45c8dac153d28961e4c37d7d03b648330c71f884d124dc652a13c0d",
    "ZenOldMincho-Regular.ttf": "4c051a78a21c4e8e9dccf1c754776d33f356b8cc6ef95d9b64761b9bae814b84",
}

if __name__ == "__main__":
    for name, expected in EXPECTED.items():
        data = (ROOT / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise SystemExit(f"Bundled font checksum mismatch: {name}")
        print(f"Verified {name}")
