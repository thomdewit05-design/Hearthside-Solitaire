#!/usr/bin/env python3
"""Draws the app icon: a warmly lit house whose door is an ace of hearts, on evening blue.
No text. Output: Hearthside/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # supersample, downscale to 1024
BLUE, BLUE_DARK = (46, 58, 89), (24, 30, 52)
HONEY, RED, CREAM, WOOD, ROOF = (242, 165, 65), (200, 85, 61), (250, 243, 227), (122, 82, 54), (110, 59, 46)


def main():
    img = Image.new("RGB", (S, S), BLUE)
    d = ImageDraw.Draw(img)
    for y in range(S):  # vertical gradient
        t = y / S
        d.line([(0, y), (S, y)], fill=tuple(int(BLUE[i] * (1 - t) + BLUE_DARK[i] * t) for i in range(3)))
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse([S * .12, S * .2, S * .88, S * .95], fill=(150, 90, 30))
    img = Image.blend(img, Image.composite(glow, img, glow.convert("L")).filter(ImageFilter.GaussianBlur(S * .08)), 0.55)
    d = ImageDraw.Draw(img)
    # stars
    for x, y, r in [(.18, .16, 14), (.8, .12, 18), (.68, .26, 10), (.3, .08, 10), (.9, .3, 12)]:
        d.ellipse([S * x - r, S * y - r, S * x + r, S * y + r], fill=CREAM)
    # snowy ground
    d.ellipse([-S * .2, S * .78, S * 1.2, S * 1.3], fill=(225, 230, 240))
    # chimney + walls + roof
    d.rectangle([S * .62, S * .25, S * .7, S * .4], fill=(91, 70, 54))
    d.rectangle([S * .24, S * .45, S * .76, S * .82], fill=(217, 162, 115))
    d.polygon([(S * .16, S * .48), (S * .5, S * .2), (S * .84, S * .48)], fill=ROOF)
    d.polygon([(S * .16, S * .48), (S * .5, S * .2), (S * .84, S * .48), (S * .78, S * .48), (S * .5, S * .25), (S * .22, S * .48)],
              fill=(245, 248, 252))  # snow line on an insulated roof
    # glowing windows
    for x0 in (.29, .62):
        box = [S * x0, S * .52, S * (x0 + .09), S * .62]
        halo = Image.new("L", (S, S), 0)
        ImageDraw.Draw(halo).rectangle([box[0] - 60, box[1] - 60, box[2] + 60, box[3] + 60], fill=180)
        img.paste(Image.new("RGB", (S, S), HONEY), (0, 0), halo.filter(ImageFilter.GaussianBlur(80)))
        d = ImageDraw.Draw(img)
        d.rectangle(box, fill=(255, 205, 110))
        d.line([(box[0] + box[2]) / 2, box[1], (box[0] + box[2]) / 2, box[3]], fill=WOOD, width=24)
        d.line([box[0], (box[1] + box[3]) / 2, box[2], (box[1] + box[3]) / 2], fill=WOOD, width=24)
    # door = ace of hearts card
    card = [S * .42, S * .56, S * .58, S * .82]
    d.rounded_rectangle([card[0] + 30, card[1] + 40, card[2] + 30, card[3] + 40], radius=70, fill=(60, 40, 30))
    d.rounded_rectangle(card, radius=70, fill=CREAM, outline=(90, 60, 40), width=18)
    cx, cy, r = (card[0] + card[2]) / 2, card[1] + (card[3] - card[1]) * .5, S * .026
    d.ellipse([cx - r * 1.9, cy - r * 1.3, cx, cy + r * .6], fill=RED)
    d.ellipse([cx, cy - r * 1.3, cx + r * 1.9, cy + r * .6], fill=RED)
    d.polygon([(cx - r * 1.85, cy - r * .1), (cx + r * 1.85, cy - r * .1), (cx, cy + r * 2.1)], fill=RED)
    # small corner "A" mark drawn as strokes (no font dependency)
    ax, ay, h = card[0] + S * .022, card[1] + S * .02, S * .045
    d.line([(ax, ay + h), (ax + h * .35, ay), (ax + h * .7, ay + h)], fill=RED, width=22)
    d.line([(ax + h * .17, ay + h * .6), (ax + h * .53, ay + h * .6)], fill=RED, width=22)
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "Hearthside", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png")
    img.resize((1024, 1024), Image.LANCZOS).save(out)
    print("Wrote", out)


if __name__ == "__main__":
    main()
