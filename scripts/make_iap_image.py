"""Draw the 1024x1024 promotional image for the Thirty+ in-app purchase.

Requirements (App Store Connect): JPG or PNG, 1024 x 1024, RGB, flattened,
no rounded corners. Six columns show the skins; the name sits below.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
fonts = root / "scripts/fonts"
skins = [  # (lcd, ink) for Classic, Paper, Mint, Amber, Night Blue, Ruby
    ("#b8c1aa", "#1c231d"), ("#ecebe6", "#222220"), ("#d3ebdd", "#123a2c"),
    ("#130d06", "#ffb33c"), ("#07111f", "#7cc4ff"), ("#0e0405", "#ff4b3e"),
]
size = 1024
image = Image.new("RGB", (size, size), "#141614")
draw = ImageDraw.Draw(image)
panel_top, panel_bottom, margin, gap = 96, 640, 72, 14
width = (size - 2 * margin - gap * (len(skins) - 1)) / len(skins)
for index, (lcd, ink) in enumerate(skins):
    left = margin + index * (width + gap)
    draw.rectangle((left, panel_top, left + width, panel_bottom), fill=lcd)
    slats, inner = 18, 18
    pitch = (panel_bottom - panel_top - 2 * inner) / slats
    lit = 18 - index * 2  # each column a little further along
    for slat in range(slats):
        y = panel_top + inner + slat * pitch
        on = slats - 1 - slat < lit
        color = ink if on else lcd
        if not on:  # faint unlit slat
            r, g, b = Image.new("RGB", (1, 1), ink).getpixel((0, 0))
            lr, lg, lb = Image.new("RGB", (1, 1), lcd).getpixel((0, 0))
            color = (int(lr + (r - lr) * 0.1), int(lg + (g - lg) * 0.1), int(lb + (b - lb) * 0.1))
        draw.rectangle((left + 14, y, left + width - 14, y + pitch * 0.6), fill=color)
title = ImageFont.truetype(str(fonts / "ZenKakuGothicNew-Bold.ttf"), 150)
sub = ImageFont.truetype(str(fonts / "ZenKakuGothicNew-Medium.ttf"), 46)
draw.text((size / 2, 770), "Thirty+", font=title, fill="#cfe0bd", anchor="mm")
draw.text((size / 2, 900), "スキン・ロック画面・終了音", font=sub, fill="#9da199", anchor="mm")
out = root / "docs/release/store/iap-thirty-plus-1024.png"
image.save(out, optimize=True)
print(out, image.size, image.mode)
