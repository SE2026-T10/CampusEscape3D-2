"""Deterministic, original game explosion cue. No downloaded samples."""
from pathlib import Path
import math
import random
import struct
import wave

output = Path(__file__).resolve().parents[1] / "assets/audio/sabotage_blast.wav"
rate = 22050
duration = 2.7
rng = random.Random(1705)
samples = bytearray()
smooth = 0.0
for i in range(round(rate * duration)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    smooth = .91 * smooth + .09 * noise
    attack = min(1.0, t / .008)
    burst = noise * .45 * math.exp(-18 * t)
    rumble = (.55 * smooth + .22 * math.sin(2 * math.pi * (53 * t - 4 * t * t))) * math.exp(-2.2 * t)
    value = max(-.85, min(.85, (burst + rumble) * attack))
    samples.extend(struct.pack("<h", round(value * 32767)))
with wave.open(str(output), "wb") as stream:
    stream.setparams((1, 2, rate, 0, "NONE", "not compressed"))
    stream.writeframes(samples)
print(f"K17 V5: original cue written to {output.name}")
