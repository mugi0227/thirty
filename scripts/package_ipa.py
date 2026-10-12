"""Package and verify an unsigned ARM64 app for local AltStore testing."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import struct
from zipfile import ZIP_DEFLATED, ZipFile

parser = argparse.ArgumentParser()
parser.add_argument("app", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
app = args.app.resolve()
if app.name != "Thirty.app" or not app.is_dir():
    raise SystemExit("Expected the built Thirty.app directory")
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == "jp.mugilab.thirty"
assert info["CFBundleDisplayName"] == "Thirty"
assert info["CFBundleDisplayName"].isascii()
executable = app / info["CFBundleExecutable"]
with executable.open("rb") as source:
    header = source.read(8)
assert len(header) == 8 and struct.unpack("<II", header) == (0xFEEDFACF, 0x0100000C), "Expected a thin ARM64 Mach-O"
args.output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(args.output, "w", compression=ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob("*")):
        if path.is_file():
            archive.write(path, "Payload/Thirty.app/" + path.relative_to(app).as_posix())
with ZipFile(args.output) as archive:
    assert archive.testzip() is None, "Invalid ZIP CRC"
    assert "Payload/Thirty.app/" + info["CFBundleExecutable"] in archive.namelist()
with args.output.open("rb") as output_file:
    sha256 = hashlib.file_digest(output_file, "sha256").hexdigest()
record = {
    "ipa": str(args.output.resolve()),
    "bytes": args.output.stat().st_size,
    "sha256": sha256,
    "bundle_id": info["CFBundleIdentifier"],
    "display_name": info["CFBundleDisplayName"],
    "version": info["CFBundleShortVersionString"],
    "build": info["CFBundleVersion"],
    "arm64": True,
    "zip_crc": "passed",
    "signed": False,
    "device_verified": False,
}
args.output.with_suffix(".verification.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps(record, indent=2))
