"""Draw the code-native LCD icon; no image or font dependencies beyond Pillow."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "ios/Thirty/Assets.xcassets"
target = root / "AppIcon.appiconset"
target.mkdir(parents=True, exist_ok=True)
image = Image.new("RGB", (1024, 1024), "#f5f2eb")
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((105, 335, 919, 699), radius=42, fill="#d4d4c8")
draw.rounded_rectangle((105, 305, 919, 665), radius=42, fill="#fdfaf2")
draw.rectangle((140, 342, 884, 625), fill="#b3bda6")
for index in range(15):
    draw.rectangle((162 + index * 25, 363, 176 + index * 25, 604), fill="#202921")
masks = {3: [0, 2, 3, 5, 6], 0: [0, 1, 2, 4, 5, 6]}
for value, x in ((3, 586), (0, 730)):
    y, w, h, t = 390, 112, 182, 16
    pieces = [(x+t,y,x+w-t,y+t), (x,y+t,x+t,y+h//2-t//2),
              (x+w-t,y+t,x+w,y+h//2-t//2), (x+t,y+h//2-t//2,x+w-t,y+h//2+t//2),
              (x,y+h//2+t//2,x+t,y+h-t), (x+w-t,y+h//2+t//2,x+w,y+h-t),
              (x+t,y+h-t,x+w-t,y+h)]
    for index, box in enumerate(pieces):
        draw.rounded_rectangle(box, radius=4, fill="#202921" if index in masks[value] else "#a8b29b")
image.save(target / "AppIcon.png")
(target / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2), encoding="utf-8")
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}), encoding="utf-8")
print(target / "AppIcon.png")
