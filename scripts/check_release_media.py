"""Validate the complete generated App Store media bundle before uploading it."""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

SIZES = {
    "iphone-medium": (1206, 2622),
    "iphone-large": (1320, 2868),
    "ipad-13": (2064, 2752),
}
COMMON = {"01-running", "02-landscape", "03-guided-access", "04-finished",
          "05-skin-night", "08-break", "09-saved-sets"}


def check(root):
    for folder, size in SIZES.items():
        files = sorted((root / folder).glob("*.png"))
        expected = COMMON | ({"06-skins"} if folder == "ipad-13" else {"06-lock-screen", "07-dynamic-island"})
        if {f.stem for f in files} != expected:
            raise ValueError(f"Incomplete screenshots in {folder}: expected {sorted(expected)}, got {[f.stem for f in files]}")
        for path in files:
            with Image.open(path) as image:
                image.verify()
            with Image.open(path) as image:
                target = size[::-1] if "landscape" in path.stem else size
                if image.size != target or image.mode != "RGB":
                    raise ValueError(f"{path}: expected opaque RGB {target}, got {image.mode} {image.size}")
        print(f"{folder}: {len(files)} opaque screenshots, correct dimensions")
    video = root / "app-preview-iphone-6.9.mp4"
    result = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(video)],
                            capture_output=True, text=True, check=True)
    info = json.loads(result.stdout)
    visual = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    duration = float(info["format"]["duration"])
    numerator, denominator = map(int, visual["r_frame_rate"].split("/"))
    if (visual["width"], visual["height"], visual["codec_name"]) != (886, 1920, "h264"):
        raise ValueError("Preview must be 886×1920 H.264")
    if not 15 <= duration <= 30 or numerator / denominator > 30:
        raise ValueError(f"Preview duration/frame rate invalid: {duration}s, {visual['r_frame_rate']}")
    if audio["codec_name"] != "aac" or audio["channels"] != 2:
        raise ValueError("Preview must have stereo AAC audio")
    print(f"Preview: {duration:.2f}s, 886×1920 H.264, stereo AAC")


if __name__ == "__main__":
    check(Path(sys.argv[1]))
