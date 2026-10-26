"""Create the original K17 relay, radio and gate cues; no external samples."""
from pathlib import Path
import math
import random
import struct
import wave

out = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
out.mkdir(parents=True, exist_ok=True)
rate = 22050
rng = random.Random(1704)
for name, duration in [('relay', .3), ('radio', 1.6), ('gate_motor', .9)]:
    samples = []
    smooth = 0.0
    for i in range(round(duration * rate)):
        t = i / rate
        noise = rng.uniform(-1, 1)
        smooth = .82 * smooth + .18 * noise
        fade = min(1, t / .015, (duration - t) / .04)
        if name == 'radio':
            sample = (.5 * (noise - smooth) + .12 * math.sin(2 * math.pi * 730 * t)) * (.65 + .35 * math.sin(2 * math.pi * 18 * t))
        elif name == 'relay':
            pulse = math.exp(-55 * t) + (.65 * math.exp(-65 * (t - .12)) if t >= .12 else 0)
            sample = pulse * (.5 * noise + .3 * math.sin(2 * math.pi * 1200 * t))
        else:
            sample = .2 * math.sin(2 * math.pi * (105 * t + 35 * t * t)) + .35 * smooth + .25 * noise * math.exp(-30 * t)
        samples.append(struct.pack('<h', round(max(-1, min(1, sample * fade * .6)) * 32767)))
    with wave.open(str(out / (name + '.wav')), 'wb') as stream:
        stream.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        stream.writeframes(b''.join(samples))
print('K17 AUDIO: 3 original synthesized mono cues at 22050 Hz')
