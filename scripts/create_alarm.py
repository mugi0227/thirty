"""Generate one short PCM chime for foreground audio and local notifications."""
import math
from pathlib import Path
import struct
import wave

root = Path(__file__).resolve().parents[1]
rate = 22050
duration = 2.4
notes = [(0.0, 880), (0.3, 1108.73), (0.6, 1318.51), (1.2, 880), (1.5, 1108.73), (1.8, 1318.51)]
samples = []
for i in range(int(rate * duration)):
    t = i / rate
    value = 0.0
    for onset, frequency in notes:
        age = t - onset
        if 0 <= age < 0.6:
            attack = min(1, age / 0.008)
            release = min(1, (0.6 - age) / 0.06)
            value += 0.22 * attack * release * math.exp(-6 * age) * math.sin(2 * math.pi * frequency * age)
    samples.append(struct.pack('<h', round(max(-1, min(1, value)) * 32767)))
for target in [root / 'ios/Thirty/alarm.wav', root / 'preview/alarm.wav']:
    with wave.open(str(target), 'wb') as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(rate)
        sound.writeframes(b''.join(samples))
    print(target)
