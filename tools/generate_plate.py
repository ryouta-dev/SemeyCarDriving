#!/usr/bin/env python3
"""Generate a Kazakh-style licence plate texture for the Priora (CC0)."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "priora_plate.png"
FONT = "C:/Windows/Fonts/arialbd.ttf"


def load_font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def main():
    width, height = 512, 128
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, 0, width - 1, height - 1], outline="black", width=6)
    draw.rectangle([6, 6, 60, height - 7], fill=(0, 58, 145))
    draw.text((14, 84), "KZ", font=load_font(28), fill="white")
    draw.text((78, 18), "001 AA", font=load_font(66), fill="black")
    # Region code 18 stands for the Abai region, which Semey belongs to since 2022.
    draw.text((372, 34), "18", font=load_font(58), fill="black")
    OUT.parent.mkdir(exist_ok=True)
    image.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
