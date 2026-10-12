"""Generate the end-of-timer sounds as short mono PCM files.

alarm.wav is the free chime; the others are Thirty+ choices. Each stays well
under the 30-second limit for notification sounds.
"""
import math
from pathlib import Path
import struct
import wave

root = Path(__file__).resolve().parents[1]
rate = 22050


def render(duration, voice):
    samples = []
    for i in range(int(rate * duration)):
        value = max(-1, min(1, voice(i / rate)))
        samples.append(struct.pack('<h', round(value * 32767)))
    return b''.join(samples)


def envelope(age, length, attack=0.008, release=0.06):
    if not 0 <= age < length:
        return 0.0
    return min(1, age / attack) * min(1, (length - age) / release)


def chime(t):
    notes = [(0.0, 880), (0.3, 1108.73), (0.6, 1318.51), (1.2, 880), (1.5, 1108.73), (1.8, 1318.51)]
    return sum(0.22 * envelope(t - onset, 0.6) * math.exp(-6 * (t - onset)) * math.sin(2 * math.pi * f * (t - onset))
               for onset, f in notes)


def beep(t):
    # Kitchen-timer style: four quick beeps, twice.
    value = 0.0
    for group in (0.0, 1.2):
        for k in range(4):
            onset = group + k * 0.16
            age = t - onset
            value += 0.28 * envelope(age, 0.09, 0.003, 0.01) * (1 if math.sin(2 * math.pi * 2048 * age) > 0 else -1) * 0.6
    return value


def bell(t):
    # A struck bell: inharmonic partials with long decay, struck twice.
    partials = [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12)]
    value = 0.0
    for onset in (0.0, 1.4):
        age = t - onset
        if age >= 0:
            value += sum(0.16 * a * min(1, age / 0.004) * math.exp(-3.2 * age * r ** 0.4) * math.sin(2 * math.pi * 523.25 * r * age)
                         for r, a in partials)
    return value


def soft(t):
    # Two low, slow notes for a quiet room.
    notes = [(0.0, 392.0), (0.7, 523.25)]
    return sum(0.3 * envelope(t - onset, 1.6, 0.12, 0.6) * math.sin(2 * math.pi * f * (t - onset)) for onset, f in notes)


sounds = {'alarm': (2.4, chime), 'beep': (2.4, beep), 'bell': (2.8, bell), 'soft': (2.4, soft)}
for name, (duration, voice) in sounds.items():
    frames = render(duration, voice)
    targets = [root / f'ios/Thirty/{name}.wav']
    if name == 'alarm':
        targets.append(root / 'preview/alarm.wav')
    for target in targets:
        with wave.open(str(target), 'wb') as sound:
            sound.setnchannels(1)
            sound.setsampwidth(2)
            sound.setframerate(rate)
            sound.writeframes(frames)
        print(target)
