"""Add App Store captions to raw Simulator captures.

usage: make_store_screenshots.py RAW_DIR OUT_DIR

Each output keeps the raw capture's pixel size, so a capture from the
iPhone 17 Simulator (1206x2622) fits the required "iPhone with Dynamic
Island (medium display)" class, iPhone 17 Pro Max (1320x2868) the large
class and iPad Pro 13-inch (2064x2752) the 13-inch iPad class.
Runs on the macOS runner, which has Hiragino Sans.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTIONS = {
    "01-running": ("とりあえず、30分！", "押したら、あとは減っていく棒を見るだけ"),
    "02-landscape": ("横にすれば、置き時計に", "物理タイマーのようなバー表示"),
    "03-guided-access": ("ほかのアプリに逃げられない", "iPhoneのアクセスガイドで画面を固定"),
    "04-finished": ("できても、できなくても", "終わったら「もう30分」か「おしまい」"),
    "05-skin-night": ("気分でスキンを選べる", "6種類のスキン（Thirty+）"),
    "06-dynamic-island": ("ロック画面でも、残りが見える", "Dynamic Island と StandBy に対応（Thirty+）"),
    "06-skins": ("気分でスキンを選べる", "購入前に試着できます（Thirty+）"),
}
BACKGROUND = (184, 193, 170)
INK = (28, 35, 29)

FONT_CANDIDATES = {
    "bold": ["/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc",
             "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"],
    "regular": ["/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc",
                "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"],
}


def font(kind, size):
    for path in FONT_CANDIDATES[kind]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise SystemExit(f"No Japanese {kind} font found")


def fit(draw, text, kind, size, max_width):
    while size > 10:
        candidate = font(kind, size)
        if draw.textlength(text, font=candidate) <= max_width:
            return candidate
        size -= 2
    return font(kind, size)


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    out = Image.new("RGBA", image.size)
    out.paste(image, (0, 0), mask)
    return out


def compose(raw_path, out_path):
    raw = Image.open(raw_path).convert("RGB")
    width, height = raw.size
    # Landscape captures come back in portrait pixel order; turn them upright.
    # A landscape capture becomes a landscape store image (e.g. 2868x1320).
    if "landscape" in raw_path.stem:
        raw = raw.rotate(90, expand=True)
        width, height = height, width
    title, subtitle = CAPTIONS[raw_path.stem]
    canvas = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    scale = min(width, height) / 1320
    title_font = fit(draw, title, "bold", int(96 * scale), width * 0.88)
    sub_font = fit(draw, subtitle, "regular", int(52 * scale), width * 0.88)
    top = int(170 * scale)
    draw.text((width / 2, top), title, font=title_font, fill=INK, anchor="mt")
    draw.text((width / 2, top + int(150 * scale)), subtitle, font=sub_font, fill=(62, 72, 62), anchor="mt")

    area_top = top + int(270 * scale)
    margin = int(90 * scale)
    max_w, max_h = width - 2 * margin, height - area_top - margin
    ratio = min(max_w / raw.width, max_h / raw.height)
    shot = raw.resize((int(raw.width * ratio), int(raw.height * ratio)), Image.LANCZOS)
    radius = int(min(shot.size) * 0.07)
    framed = rounded(shot, radius)
    x = (width - shot.width) // 2
    y = area_top + (max_h - shot.height) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y + int(24 * scale), x + shot.width, y + shot.height + int(24 * scale)),
                                             radius=radius, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(40 * scale)))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    border = int(10 * scale)
    ImageDraw.Draw(canvas).rounded_rectangle((x - border, y - border, x + shot.width + border, y + shot.height + border),
                                             radius=radius + border, fill=INK)
    canvas.alpha_composite(framed, (x, y))
    canvas.convert("RGB").save(out_path, optimize=True)  # App Store rejects alpha channels
    print(out_path, canvas.size)


def main():
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    for raw_path in sorted(raw_dir.glob("*.png")):
        if raw_path.stem in CAPTIONS:
            compose(raw_path, out_dir / raw_path.name)


if __name__ == "__main__":
    main()
