#!/usr/bin/env python3
"""Makes the Expanded Library's surface detail textures (phase B polish).

Writes eight grey, tileable 512 px PNGs to maps/library/assets/textures/surface/:
terrazzo, plaster, wood_grain, wood_planks, carpet_weave, speckle, concrete and
stone_blocks. They are made here in code (fixed seeds, so the output is the same each
run; no third-party images). The shader multiplies a box's colour by them, divided by
their mean (make_surface_detail.gd lists the means), so only fine detail is added.

Usage (from the project folder; needs numpy and Pillow):
    python3 maps/library/tools/expansion/make_surface_textures.py
After changing a texture, update its mean in make_surface_detail.gd and run that tool.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 512
OUT = os.path.join("maps", "library", "assets", "textures", "surface")
Y, X = np.mgrid[0:N, 0:N].astype(np.float32)


def tile_noise(scale, seed):
    """Smooth value noise that tiles (a 3 × 3 copy scaled up, the middle cut out)."""
    r = np.random.default_rng(seed)
    n = N // scale
    g = np.tile(r.random((n, n)), (3, 3))
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((3 * N, 3 * N), Image.BICUBIC)
    return np.asarray(im, dtype=np.float32)[N:2 * N, N:2 * N] / 255.0


def fbm(seed, octaves=((64, .5), (32, .25), (16, .15), (8, .1))):
    return sum(w * tile_noise(s, seed + i) for i, (s, w) in enumerate(octaves))


def wood_planks():
    pw = N / 4
    plank = (X // pw).astype(int)
    off = (plank * 0.37 % 1) * N
    yy = (Y + off) % N
    grain = np.sin((X % pw) / pw * np.pi * 6 + 3 * fbm(1) * 6 + plank) * 0.5 + 0.5
    wood = 0.86 + 0.08 * grain * tile_noise(4, 2) + 0.05 * (tile_noise(128, 3) - .5)
    wood += (np.random.default_rng(4).random(4)[plank] - .5) * 0.10
    joint = ((X % pw) < 2) | ((yy % N) < 2) | (((yy + N / 2) % N < 2) & (plank % 2 == 0))
    wood[joint] = 0.62
    return wood


def terrazzo():
    base = 0.9 + 0.04 * (fbm(10) - .5)
    im = Image.fromarray(np.uint8(np.clip(base, 0, 1) * 255))
    d = ImageDraw.Draw(im)
    r = np.random.default_rng(11)
    for _ in range(1400):
        cx, cy = r.random(2) * N
        s = r.random() * 5 + 1.5
        v = int(255 * (0.62 + r.random() * 0.5))
        pts = [(cx + np.cos(a) * s * (0.6 + r.random() * .6), cy + np.sin(a) * s * (0.6 + r.random() * .6))
               for a in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                d.polygon([(p[0] + dx, p[1] + dy) for p in pts], fill=min(v, 255))
    t = np.asarray(im, dtype=np.float32) / 255
    t[((X % (N / 2)) < 1.5) | ((Y % (N / 2)) < 1.5)] *= 0.8
    return t


def plaster():
    return 0.93 + 0.06 * (fbm(20, ((128, .4), (64, .3), (16, .2), (4, .1))) - .5)


def stone_blocks():
    bh = N / 4
    row = (Y // bh).astype(int)
    bx = (X + np.where(row % 2 == 1, N / 4, 0)) % N
    bid = (bx // (N / 2)).astype(int) + row * 2
    stone = 0.86 + 0.07 * (fbm(30) - .5) + (np.random.default_rng(31).random(16)[bid % 16] - .5) * 0.08
    stone[((Y % bh) < 3) | ((bx % (N / 2)) < 3)] = 0.7
    return stone


def concrete():
    sp = np.random.default_rng(40).random((N, N)).astype(np.float32)
    c = 0.9 + 0.05 * (fbm(41) - .5) + 0.05 * (sp > 0.985) * -1 + 0.03 * (tile_noise(128, 42) - .5)
    c[(Y % (N / 2)) < 1.2] *= 0.9
    return c


def wood_grain():
    g = sum(w * tile_noise(s, 90 + i) for i, (s, w) in enumerate(((128, .4), (64, .3), (16, .2))))
    streak = np.sin(Y / N * 2 * np.pi * 14 + g * 9) * 0.5 + 0.5
    return 0.9 + 0.07 * (streak - .5) + 0.05 * (tile_noise(8, 95) - .5)


def carpet_weave():
    big = np.tile((np.random.default_rng(5).random((N, N)) * 255).astype(np.uint8), (3, 3))
    fine = np.asarray(Image.fromarray(big).filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float32)[N:2 * N, N:2 * N] / 255
    weave = (np.sin(X * np.pi / 4) * np.sin(Y * np.pi / 4)) * 0.5 + 0.5
    return 0.9 + 0.06 * (fine - .5) * 2 + 0.025 * (weave - .5) + 0.04 * (tile_noise(64, 6) - .5)


def speckle():
    r = np.random.default_rng(70)
    sp = np.full((N, N), 0.9, np.float32)
    pts = r.integers(0, N, (5000, 2))
    vals = r.choice([0.72, 0.8, 1.0], 5000)
    for (px, py), v in zip(pts, vals):
        sp[py, px] = v
        sp[py, (px + 1) % N] = v
    return sp + 0.04 * (tile_noise(64, 71) - .5)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in [("terrazzo", terrazzo), ("plaster", plaster), ("wood_grain", wood_grain),
                       ("wood_planks", wood_planks), ("carpet_weave", carpet_weave), ("speckle", speckle),
                       ("concrete", concrete), ("stone_blocks", stone_blocks)]:
        a = np.clip(make(), 0, 1)
        img = Image.fromarray(np.uint8(a * 255))
        img.save(os.path.join(OUT, name + ".png"))
        print("%s: mean %.4f" % (name, np.asarray(img, dtype=float).mean() / 255))


if __name__ == "__main__":
    main()
