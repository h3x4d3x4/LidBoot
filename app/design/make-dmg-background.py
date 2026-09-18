#!/usr/bin/env python3
"""Render the DMG window background at 1x and 2x.

Both scales are rasterised natively — text drawn at 2x and downsampled, or a 1x
image left for Finder to upscale, is what makes installer type look soft.
build-dmg.sh combines the two into a multi-representation TIFF with
`tiffutil -cathidpicheck`, which is the only thing Finder actually honours.

Light ground on purpose, though the icon is a dark slab: Finder draws the two
item names itself, in the system label colour, which is black in light mode —
on a dark background they're near invisible. Same model as GridPush.

Palette is the site's (site/README.md): the icon's stroke gradient as a wash
behind the icon, action blue for the arrow, the amber dot as the one accent.

    python3 design/make-dmg-background.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path

W, H = 640, 420                     # logical window size; matches build-dmg.sh
ICON_Y = 196                        # centre of the icon row
APP_X, APPS_X = 160, 480

GROUND_TOP = (255, 255, 255)
GROUND_BOTTOM = (240, 240, 245)     # --band #f5f5f7, a touch cooler at the foot
INK = (29, 29, 31)                  # --text
INK_DIM = (110, 110, 115)           # --text-2
INK_FAINT = (134, 134, 139)         # --text-3
LID_A = (148, 136, 255)             # --lid-a, violet
LID_B = (119, 156, 255)             # --lid-b, blue
BLUE = (61, 107, 243)               # --blue, dark enough for the arrow
DOT = (255, 174, 89)                # --dot, amber

FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight="Regular"):
    f = ImageFont.truetype(FONT, int(round(size)))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def render(scale):
    W_S, H_S = W * scale, H * scale
    s = lambda v: int(round(v * scale))

    def centred(d, y, text, fnt, fill):
        left, top, right, bottom = d.textbbox((0, 0), text, font=fnt)
        d.text(((W_S - (right - left)) // 2 - left, y), text, font=fnt, fill=fill)

    img = Image.new("RGB", (W_S, H_S))
    d = ImageDraw.Draw(img)
    for y in range(H_S):
        t = y / H_S
        d.line([(0, y), (W_S, y)],
               fill=tuple(int(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM)))

    # The icon's own gradient as a soft wash behind the app icon: violet at the
    # top, blue at the base, exactly like the stroke on the slab.
    wash = Image.new("RGBA", (W_S, H_S), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    wd.ellipse([s(APP_X - 150), s(ICON_Y - 165), s(APP_X + 150), s(ICON_Y + 15)], fill=LID_A + (70,))
    wd.ellipse([s(APP_X - 150), s(ICON_Y - 15), s(APP_X + 150), s(ICON_Y + 165)], fill=LID_B + (70,))
    img = Image.alpha_composite(img.convert("RGBA"),
                                wash.filter(ImageFilter.GaussianBlur(s(48)))).convert("RGB")
    d = ImageDraw.Draw(img)

    centred(d, s(38), "LidBoot", font(s(29), "Bold"), INK)
    centred(d, s(77), "Your lid is not a power button.", font(s(12.5)), INK_DIM)

    # Arrow, with the icon's amber dot where it starts.
    y = s(ICON_Y)
    x0a, x1a = s(APP_X + 92), s(APPS_X - 92)
    d.ellipse([x0a - s(4), y - s(4), x0a + s(4), y + s(4)], fill=DOT)
    d.line([(x0a + s(8), y), (x1a - s(11), y)], fill=BLUE, width=max(1, s(2)))
    head = s(10)
    d.polygon([(x1a, y), (x1a - head, y - head * 0.6), (x1a - head, y + head * 0.6)], fill=BLUE)

    # create-dmg's --window-size counts the title bar, so only ~390pt of the
    # 420 is content: keep everything above 380.
    centred(d, s(308), "Drag LidBoot into your Applications folder",
            font(s(13), "Semibold"), INK)
    centred(d, s(331), "Then eject this disk image — it can be deleted afterwards.",
            font(s(11)), INK_FAINT)
    centred(d, s(366), "lidboot.hexadexa.io", font(s(10.5)), INK_FAINT)

    d.line([(0, 0), (W_S, 0)], fill=(255, 255, 255), width=1)
    d.line([(0, H_S - 1), (W_S, H_S - 1)], fill=(222, 222, 228), width=1)
    return img


if __name__ == "__main__":
    out = Path(__file__).resolve().parent
    render(1).save(out / "dmg-background.png")
    render(2).save(out / "dmg-background@2x.png")
    print(f"  dmg-background.png       {W}x{H}")
    print(f"  dmg-background@2x.png    {W*2}x{H*2}")
