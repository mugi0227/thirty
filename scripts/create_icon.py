"""Draw the code-native LCD icons; no image or font dependencies beyond Pillow.

AppIcon is the default. The AppIcon-<Skin> sets are alternate icons that
Thirty+ owners can pick to match a skin.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "ios/Thirty/Assets.xcassets"
icons = {
    "AppIcon": dict(bg="#f5f2eb", lcd="#b3bda6", ink="#202921", ghost="#a8b29b"),
    "AppIcon-Paper": dict(bg="#f5f2eb", lcd="#ecebe6", ink="#222220", ghost="#dddcd6"),
    "AppIcon-Mint": dict(bg="#f5f2eb", lcd="#d3ebdd", ink="#123a2c", ghost="#c2dccd"),
    "AppIcon-Amber": dict(bg="#1c1a17", lcd="#130d06", ink="#ffb33c", ghost="#2a1d0c"),
    "AppIcon-Night": dict(bg="#1a1d22", lcd="#07111f", ink="#7cc4ff", ghost="#122236"),
    "AppIcon-Ruby": dict(bg="#1d1a1a", lcd="#0e0405", ink="#ff4b3e", ghost="#2a0c0c"),
}


def draw_icon(bg, lcd, ink, ghost):
    image = Image.new("RGB", (1024, 1024), bg)
    draw = ImageDraw.Draw(image)
    dark = sum(int(bg[i:i + 2], 16) for i in (1, 3, 5)) < 200
    draw.rounded_rectangle((105, 335, 919, 699), radius=42, fill="#0b0b0b" if dark else "#d4d4c8")
    draw.rounded_rectangle((105, 305, 919, 665), radius=42, fill="#2b2b2b" if dark else "#fdfaf2")
    draw.rectangle((140, 342, 884, 625), fill=lcd)
    for index in range(15):
        draw.rectangle((162 + index * 25, 363, 176 + index * 25, 604), fill=ink)
    masks = {3: [0, 2, 3, 5, 6], 0: [0, 1, 2, 4, 5, 6]}
    for value, x in ((3, 586), (0, 730)):
        y, w, h, t = 390, 112, 182, 16
        pieces = [(x+t,y,x+w-t,y+t), (x,y+t,x+t,y+h//2-t//2),
                  (x+w-t,y+t,x+w,y+h//2-t//2), (x+t,y+h//2-t//2,x+w-t,y+h//2+t//2),
                  (x,y+h//2+t//2,x+t,y+h-t), (x+w-t,y+h//2+t//2,x+w,y+h-t),
                  (x+t,y+h-t,x+w-t,y+h)]
        for index, box in enumerate(pieces):
            draw.rounded_rectangle(box, radius=4, fill=ink if index in masks[value] else ghost)
    return image


for name, colors in icons.items():
    target = root / f"{name}.appiconset"
    target.mkdir(parents=True, exist_ok=True)
    draw_icon(**colors).save(target / f"{name}.png")
    (target / "Contents.json").write_text(json.dumps({"images": [{"filename": f"{name}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
    print(target / f"{name}.png")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
