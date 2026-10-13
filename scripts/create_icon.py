"""Draw the app icons: the timer screen itself, slats over a "30".

AppIcon is the default (Classic). The AppIcon-<Skin> sets are alternate icons
that Thirty+ owners can pick to match a skin. Pure Pillow, no fonts needed.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "ios/Thirty/Assets.xcassets"
icons = {
    "AppIcon": ("#b8c1aa", "#1c231d"),
    "AppIcon-Paper": ("#ecebe6", "#222220"),
    "AppIcon-Mint": ("#d3ebdd", "#123a2c"),
    "AppIcon-Amber": ("#130d06", "#ffb33c"),
    "AppIcon-Night": ("#07111f", "#7cc4ff"),
    "AppIcon-Ruby": ("#0e0405", "#ff4b3e"),
}
# Seven-segment outlines on a 22 x 40 grid whose x axis starts at -2 (as in the app).
SEGMENTS = [
    [(3, 0), (15, 0), (17, 2), (15, 4), (3, 4), (1, 2)],
    [(0, 3), (2, 5), (2, 17), (0, 19), (-2, 17), (-2, 5)],
    [(18, 3), (20, 5), (20, 17), (18, 19), (16, 17), (16, 5)],
    [(3, 18), (15, 18), (17, 20), (15, 22), (3, 22), (1, 20)],
    [(0, 21), (2, 23), (2, 35), (0, 37), (-2, 35), (-2, 23)],
    [(18, 21), (20, 23), (20, 35), (18, 37), (16, 35), (16, 23)],
    [(3, 36), (15, 36), (17, 38), (15, 40), (3, 40), (1, 38)],
]
DIGITS = {3: [0, 2, 3, 5, 6], 0: [0, 1, 2, 4, 5, 6]}


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def draw_icon(lcd_hex, ink_hex):
    lcd, ink = rgb(lcd_hex), rgb(ink_hex)
    ghost = mix(lcd, ink, 0.1)
    image = Image.new("RGB", (1024, 1024), lcd)
    draw = ImageDraw.Draw(image)
    top, bottom, left, right, count = 150, 560, 170, 854, 9
    pitch = (bottom - top) / count
    for index in range(count):  # the top three have run out
        y = top + index * pitch
        draw.rounded_rectangle((left, y, right, y + pitch * 0.58), radius=6, fill=ink if index >= 3 else ghost)
    draw.rectangle((left, 610, right, 618), fill=mix(lcd, ink, 0.18))
    height = 250
    width = height * 0.55
    space = height * 0.18
    x0, y0 = (1024 - (2 * width + space)) / 2, 665
    for position, value in enumerate((3, 0)):
        x = x0 + position * (width + space)
        for index, outline in enumerate(SEGMENTS):
            points = [(x + (px + 2) * width / 22, y0 + py * height / 40) for px, py in outline]
            draw.polygon(points, fill=ink if index in DIGITS[value] else ghost)
    return image


for name, (lcd, ink) in icons.items():
    target = root / f"{name}.appiconset"
    target.mkdir(parents=True, exist_ok=True)
    draw_icon(lcd, ink).save(target / f"{name}.png")
    (target / "Contents.json").write_text(json.dumps({"images": [{"filename": f"{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
    print(target / f"{name}.png")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
