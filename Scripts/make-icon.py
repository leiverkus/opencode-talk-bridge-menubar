#!/usr/bin/env python3
"""Draw the master app icon (1024x1024) to Resources/AppIcon-candidate.png.

The motif echoes the menu-bar polling glyph (`dot.radiowaves.left.and.right`):
a centred dot with symmetric radio waves, on a teal→indigo squircle. Run
make-icon.sh afterwards to derive the .iconset and .icns.
"""
from __future__ import annotations
import math
import os
from PIL import Image, ImageDraw

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Resources", "AppIcon-candidate.png",
)

TOP = (31, 182, 201)     # teal  #1FB6C9
BOTTOM = (45, 84, 200)    # indigo #2D54C8
CORNER_RADIUS = int(SIZE * 0.2237)  # Apple-ish continuous corner


def vertical_gradient(size: int, top: tuple[int, int, int],
                      bottom: tuple[int, int, int]) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel((0, y), tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
        ))
    return grad.resize((size, size))


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_waves(img: Image.Image) -> None:
    d = ImageDraw.Draw(img)
    cx = cy = SIZE / 2
    white = (255, 255, 255, 255)

    # centre dot
    r_dot = SIZE * 0.072
    d.ellipse([cx - r_dot, cy - r_dot, cx + r_dot, cy + r_dot], fill=white)

    # symmetric waves: right opens right, left opens left
    width = int(SIZE * 0.05)
    for radius_frac in (0.16, 0.255, 0.35):
        r = SIZE * radius_frac
        box = [cx - r, cy - r, cx + r, cy + r]
        d.arc(box, start=-52, end=52, fill=white, width=width)     # right
        d.arc(box, start=128, end=232, fill=white, width=width)    # left


def main() -> None:
    base = vertical_gradient(SIZE, TOP, BOTTOM).convert("RGBA")
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(base, (0, 0), rounded_mask(SIZE, CORNER_RADIUS))
    draw_waves(icon)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    icon.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
