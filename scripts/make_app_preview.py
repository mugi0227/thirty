"""Edit the raw App Preview recording into the store video.

usage: make_app_preview.py RAW_VIDEO OUT.mp4 [ISLAND_PNG]

RAW_VIDEO is the Simulator recording made by
StoreScreenshotTests/testPreviewVideo: the ready screen, a tap on Start,
a 30-minute session drained at 100x, and the finish screen. The script finds
the start and the finish in it, then lays the footage out in a phone frame
under captions, in the same style as the screenshots, and adds a soft
backing tone, the tap and the app's own end chime.

ISLAND_PNG is optional: a capture of the Dynamic Island over another app,
shown as its own scene.

Output: 886x1920, 30 fps, H.264 + stereo AAC (App Preview, 6.9-inch iPhone).
Needs ffmpeg, Pillow and numpy.
"""
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_store_screenshots import BACKGROUND, INK, font, rounded  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
W, H, FPS = 886, 1920, 30
SUB = (62, 72, 62)
SHOT_H = 1470
SHOT_TOP = 400
RATE = 48000


def probe_size(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "csv=p=0", str(path)], capture_output=True, text=True, check=True).stdout
    w, h = map(int, out.strip().split(","))
    return w, h


def read_frames(path, width, height):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"fps={FPS},scale={width}:{height}",
                          "-pix_fmt", "rgb24", "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, height, width, 3)


def find_events(frames):
    """Start = the first big change (the tap); finish = the first jump after the drain."""
    gray = frames[:, ::4, ::4].mean(axis=3)
    diff = np.abs(np.diff(gray, axis=0)).mean(axis=(1, 2))
    start = next(i for i in range(FPS, len(diff)) if diff[i] > 10) + 1
    finish = next((i for i in range(start + 8 * FPS, len(diff)) if diff[i] > 4.5), None)
    if finish is None:
        sys.exit("The recording ends before the finish screen; record longer.")
    finish += 1
    return start / FPS, finish / FPS


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** 3


class Layout:
    def __init__(self, shot_w):
        self.shot_w = shot_w
        self.x = (W - shot_w) // 2
        self.y = SHOT_TOP
        self.radius = int(shot_w * 0.07)
        base = Image.new("RGBA", (W, H), BACKGROUND + (255,))
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((self.x, self.y + 16, self.x + shot_w, self.y + SHOT_H + 16),
                                                 radius=self.radius, fill=(0, 0, 0, 70))
        base = Image.alpha_composite(base, shadow.filter(ImageFilter.GaussianBlur(28)))
        ImageDraw.Draw(base).rounded_rectangle((self.x - 7, self.y - 7, self.x + shot_w + 7, self.y + SHOT_H + 7),
                                               radius=self.radius + 7, fill=INK)
        self.base = base
        self.mask = Image.new("L", (shot_w, SHOT_H), 0)
        ImageDraw.Draw(self.mask).rounded_rectangle((0, 0, shot_w, SHOT_H), radius=self.radius, fill=255)


def draw_caption(canvas, title, subtitle, t):
    """Slide up and fade in over the first 0.4 s of a scene."""
    k = ease(t / 0.4)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    offset = int((1 - k) * 30)
    alpha = int(255 * k)
    lines = title.split("\n")
    size = 66 if len(lines) == 1 else 58
    y = 140 if len(lines) == 1 else 110
    for line in lines:
        draw.text((W / 2, y + offset), line, font=font("bold", size), fill=INK + (alpha,), anchor="mt")
        y += int(size * 1.35)
    if subtitle:
        draw.text((W / 2, y + 30 + offset), subtitle, font=font("regular", 34), fill=SUB + (alpha,), anchor="mt")
    canvas.alpha_composite(layer)


def draw_badge(canvas, layout, text, alpha):
    if alpha <= 0:
        return
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    label = font("bold", 28)
    width = int(draw.textlength(text, font=label)) + 84
    x1 = layout.x + layout.shot_w - 22
    box = (x1 - width, layout.y + SHOT_H - 84, x1, layout.y + SHOT_H - 30)
    draw.rounded_rectangle(box, radius=27, fill=INK + (int(220 * alpha),))
    # The fonts have no ▶, so draw the fast-forward mark.
    color = BACKGROUND + (int(255 * alpha),)
    cy = (box[1] + box[3]) / 2
    left = box[0] + 22
    for dx in (0, 14):
        draw.polygon([(left + dx, cy - 9), (left + dx + 14, cy), (left + dx, cy + 9)], fill=color)
    draw.text((left + 40, cy), text, font=label, fill=color, anchor="lm")
    canvas.alpha_composite(layer)


def draw_tap(canvas, layout, t):
    """A fingertip ripple on the Start button."""
    if not 0 <= t < 0.6:
        return
    cx = layout.x + layout.shot_w * 0.5
    cy = layout.y + SHOT_H * 0.906
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    r = 34 + 50 * ease(t / 0.6)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 255, 255, int(230 * (1 - t / 0.6))), width=6)
    if t < 0.25:
        draw.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), fill=(255, 255, 255, 120))
    canvas.alpha_composite(layer)


def end_card(t):
    canvas = Image.new("RGBA", (W, H), BACKGROUND + (255,))
    k = ease(t / 0.5)
    icon = Image.open(ROOT / "ios/Thirty/Assets.xcassets/AppIcon.appiconset/AppIcon.png").convert("RGBA")
    size = int(300 * (0.92 + 0.08 * k))
    icon = rounded(icon.resize((size, size), Image.LANCZOS), int(size * 0.225))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(icon, ((W - size) // 2, 560 + (300 - size) // 2))
    draw = ImageDraw.Draw(layer)
    draw.text((W / 2, 960), "Thirty", font=font("bold", 96), fill=INK, anchor="mt")
    draw.text((W / 2, 1110), "とりあえず、30分！", font=font("bold", 56), fill=INK, anchor="mt")
    draw.text((W / 2, 1220), "無料・広告なし", font=font("regular", 36), fill=SUB, anchor="mt")
    faded = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    faded = Image.blend(faded, layer, k)
    canvas.alpha_composite(faded)
    return canvas


def tone(seconds, events):
    """A quiet two-chord pad, a soft tap and the app's own chime."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    pad = np.zeros(n)
    half = seconds / 2
    for start, chord in ((0, (196.0, 293.66, 392.0, 493.88)), (half, (220.0, 329.63, 392.0, 523.25))):
        part = (t >= start) & (t < start + half + 0.5)
        env = np.clip((t - start) / 1.2, 0, 1) * np.clip((start + half + 0.5 - t) / 1.0, 0, 1)
        for i, f in enumerate(chord):
            pad += part * env * np.sin(2 * np.pi * f * t + i) * (0.5 if i == 0 else 0.3)
    pad *= 0.035 * (1 + 0.15 * np.sin(2 * np.pi * 0.25 * t))
    pad *= np.clip((seconds - t) / 1.5, 0, 1)
    out = np.stack([pad, pad], axis=1)

    tap_at = events["tap"]
    k = np.arange(int(0.06 * RATE)) / RATE
    click = np.sin(2 * np.pi * 1400 * k) * np.exp(-k * 90) * 0.25
    i = int(tap_at * RATE)
    out[i:i + len(click)] += click[:, None]

    with wave.open(str(ROOT / "ios/Thirty/alarm.wav")) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float) / 32768
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
        if w.getframerate() != RATE:
            data = np.interp(np.arange(0, len(data), w.getframerate() / RATE), np.arange(len(data)), data)
    i = int(events["chime"] * RATE)
    chunk = data[:max(0, n - i)] * 0.5
    out[i:i + len(chunk)] += chunk[:, None]
    return (np.clip(out, -1, 1) * 32767).astype(np.int16)


def main():
    raw_path, out_path = Path(sys.argv[1]), Path(sys.argv[2])
    island_path = Path(sys.argv[3]) if len(sys.argv) > 3 and Path(sys.argv[3]).exists() else None
    src_w, src_h = probe_size(raw_path)
    shot_w = round(SHOT_H * src_w / src_h / 2) * 2
    frames = read_frames(raw_path, shot_w, SHOT_H)
    start, finish = find_events(frames)
    print(f"start {start:.2f}s, finish {finish:.2f}s, {len(frames)} frames")
    layout = Layout(shot_w)

    # (duration, source start, speed, title, subtitle, extras)
    scenes = [
        (2.6, start - 3.1, 1, "やるべきことがあるのに、\nSNSを1時間…", "", {}),
        (3.8, start - 0.5, 1, "とりあえず、30分！", "押したら、あとは置いておくだけ", {"tap": 0.05, "badge": 1.0}),
        ((finish - start - 3.5) / 2.2, start + 3.3, 2.2, "減っていく棒で、\n残りがひと目でわかる", "", {"badge": 0}),
    ]
    if island_path:
        scenes.append((3.0, None, 0, "ほかのアプリの最中も", "画面の上に残り時間（Thirty+）", {"still": island_path}))
    scenes.append((min(4.8, (len(frames) / FPS) - finish), finish - 0.2, 1, "できても、できなくても",
                   "終わったら「もう30分」か「おしまい」", {"chime": 0.2}))
    end_seconds = 2.8
    total = sum(s[0] for s in scenes) + end_seconds
    print(f"{total:.1f}s")

    still = None
    events = {}
    with tempfile.TemporaryDirectory() as tmp:
        video = Path(tmp) / "video.mp4"
        audio = Path(tmp) / "audio.wav"
        encoder = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                                    "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "slow", "-crf", "16",
                                    "-pix_fmt", "yuv420p", str(video)], stdin=subprocess.PIPE)
        clock = 0.0
        for duration, src, speed, title, subtitle, extras in scenes:
            if "tap" in extras:
                events["tap"] = clock + extras["tap"]
            if "chime" in extras:
                events["chime"] = clock + extras["chime"]
            if "still" in extras:
                still = Image.open(extras["still"]).convert("RGB")
            for f in range(round(duration * FPS)):
                t = f / FPS
                canvas = layout.base.copy()
                if "still" in extras:
                    zoom = 1 + 0.04 * t / duration
                    w, h = int(shot_w * zoom), int(SHOT_H * zoom)
                    image = still.resize((w, h), Image.LANCZOS).crop(((w - shot_w) // 2, 0, (w - shot_w) // 2 + shot_w, SHOT_H))
                else:
                    index = min(len(frames) - 1, max(0, round((src + t * speed) * FPS)))
                    image = Image.fromarray(frames[index])
                canvas.paste(image, (layout.x, layout.y), layout.mask)
                draw_caption(canvas, title, subtitle, t)
                if "tap" in extras:
                    draw_tap(canvas, layout, t - extras["tap"])
                if "badge" in extras:
                    draw_badge(canvas, layout, "早送り", ease((t - extras["badge"]) / 0.3))
                encoder.stdin.write(canvas.convert("RGB").tobytes())
            clock += duration
        for f in range(round(end_seconds * FPS)):
            encoder.stdin.write(end_card(f / FPS).convert("RGB").tobytes())
        encoder.stdin.close()
        encoder.wait()

        samples = tone(total, events)
        with wave.open(str(audio), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(samples.tobytes())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-i", str(audio),
                        "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-b:v", "10M", "-maxrate", "12M",
                        "-bufsize", "20M", "-pix_fmt", "yuv420p", "-r", str(FPS),
                        "-c:a", "aac", "-b:a", "256k", "-ar", str(RATE), "-ac", "2", "-shortest",
                        "-movflags", "+faststart", str(out_path)], check=True)
    print(out_path)


if __name__ == "__main__":
    main()
