"""Generate the Neon Maze app icon and all platform sizes."""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2048  # supersampled working size
OUT = 1024

CYAN = (59, 242, 226)
MINT = (82, 255, 184)
MAGENTA = (180, 76, 255)
BG_TOP = (10, 17, 34)
BG_BOTTOM = (4, 6, 13)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_line(draw, p1, p2, width, fill):
    draw.line([p1, p2], fill=fill, width=width, joint="curve")
    for p in (p1, p2):
        r = width / 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)


def build_icon() -> Image.Image:
    # Base gradient.
    img = Image.new("RGB", (S, S), BG_BOTTOM)
    px = img.load()
    for y in range(S):
        t = y / (S - 1)
        base = lerp(BG_TOP, BG_BOTTOM, t**0.85)
        for x in range(0, S, 1):
            px[x, y] = base

    # Ambient colour wash.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-S * 0.25, -S * 0.30, S * 0.85, S * 0.62], fill=CYAN + (34,))
    gd.ellipse([S * 0.32, S * 0.10, S * 1.25, S * 0.95], fill=MAGENTA + (30,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.09))
    img = Image.alpha_composite(img.convert("RGBA"), glow)

    # Faint grid.
    grid = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gdd = ImageDraw.Draw(grid)
    step = S // 16
    for x in range(0, S, step):
        gdd.line([(x, 0), (x, S)], fill=(255, 255, 255, 7), width=2)
    for y in range(0, S, step):
        gdd.line([(0, y), (S, y)], fill=(255, 255, 255, 7), width=2)
    img = Image.alpha_composite(img, grid)

    # Maze geometry inside the safe zone.
    m = int(S * 0.185)
    w = int(S * 0.030)  # wall thickness
    x0, y0, x1, y1 = m, m, S - m, S - m
    cw = (x1 - x0) / 4

    def gx(i):
        return x0 + cw * i

    def gy(i):
        return y0 + cw * i

    walls = [
        # Outer frame.
        ((x0, y0), (x1, y0)),
        ((x1, y0), (x1, y1)),
        ((x1, y1), (x0, y1)),
        ((x0, y1), (x0, y0)),
        # Inner maze.
        ((gx(1), y0), (gx(1), gy(2))),
        ((gx(2), y0), (gx(2), gy(1))),
        ((gx(2), gy(1)), (gx(3), gy(1))),
        ((gx(3), gy(1)), (gx(3), gy(3))),
        ((gx(0), gy(2)), (gx(2), gy(2))),
        ((gx(1), gy(3)), (gx(1), gy(4))),
        ((gx(2), gy(2)), (gx(2), gy(3))),
        ((gx(2), gy(3)), (gx(4), gy(3))),
    ]

    maze = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    md = ImageDraw.Draw(maze)
    for a, b in walls:
        rounded_line(md, a, b, w, CYAN + (255,))

    # Glow pass under the crisp lines.
    halo = maze.filter(ImageFilter.GaussianBlur(S * 0.018))
    halo2 = maze.filter(ImageFilter.GaussianBlur(S * 0.045))
    img = Image.alpha_composite(img, Image.eval(halo2, lambda v: int(v * 0.55)))
    img = Image.alpha_composite(img, Image.eval(halo, lambda v: int(v * 0.75)))
    img = Image.alpha_composite(img, maze)

    # Exit pad.
    ex, ey, er = gx(3.55), gy(1.45), S * 0.055
    pad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pad)
    pd.ellipse([ex - er, ey - er, ex + er, ey + er], fill=MINT + (26,))
    pd.ellipse([ex - er * 0.62, ey - er * 0.62, ex + er * 0.62, ey + er * 0.62], fill=MINT + (230,))
    pad_glow = pad.filter(ImageFilter.GaussianBlur(S * 0.02))
    img = Image.alpha_composite(img, Image.eval(pad_glow, lambda v: int(v * 0.7)))
    img = Image.alpha_composite(img, pad)

    # Marble.
    mx, my = gx(1.55), gy(2.85)
    mr = S * 0.115
    orb = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(orb)
    od.ellipse([mx - mr * 1.9, my - mr * 1.9, mx + mr * 1.9, my + mr * 1.9], fill=CYAN + (40,))
    orb = orb.filter(ImageFilter.GaussianBlur(S * 0.03))
    img = Image.alpha_composite(img, orb)

    marble = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    md2 = ImageDraw.Draw(marble)
    steps = 90
    for i in range(steps, 0, -1):
        t = i / steps
        r = mr * t
        col = lerp((255, 255, 255), CYAN, min(1.0, (1 - t) * 1.5))
        col = lerp(col, (7, 22, 40), max(0.0, (t - 0.55) / 0.45))
        md2.ellipse([mx - r, my - r, mx + r, my + r], fill=col + (255,))
    # Rim + specular.
    md2.ellipse([mx - mr, my - mr, mx + mr, my + mr], outline=(230, 255, 255, 160), width=int(S * 0.004))
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse(
        [mx - mr * 0.55, my - mr * 0.72, mx + mr * 0.10, my - mr * 0.20],
        fill=(255, 255, 255, 235),
    )
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.006))
    marble = Image.alpha_composite(marble, hl)
    img = Image.alpha_composite(img, marble)

    # Soft floor shadow under the marble.
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([mx - mr * 1.2, my + mr * 0.75, mx + mr * 1.2, my + mr * 1.15], fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.02))
    img = Image.alpha_composite(shadow, img)

    return img.convert("RGB").resize((OUT, OUT), Image.LANCZOS)


def main() -> None:
    icon = build_icon()
    icon_dir = os.path.join(ROOT, "assets", "icon")
    os.makedirs(icon_dir, exist_ok=True)
    master = os.path.join(icon_dir, "icon-1024.png")
    icon.save(master)

    # Android launcher icons.
    android = {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }
    for bucket, size in android.items():
        path = os.path.join(ROOT, "android", "app", "src", "main", "res", f"mipmap-{bucket}")
        os.makedirs(path, exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(path, "ic_launcher.png"))

    # iOS icons.
    ios_dir = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
    }
    if os.path.isdir(ios_dir):
        for name, size in ios_sizes.items():
            icon.resize((size, size), Image.LANCZOS).save(os.path.join(ios_dir, name))

    # Web icons.
    web = os.path.join(ROOT, "web")
    if os.path.isdir(web):
        icon.resize((192, 192), Image.LANCZOS).save(os.path.join(web, "icons", "Icon-192.png"))
        icon.resize((512, 512), Image.LANCZOS).save(os.path.join(web, "icons", "Icon-512.png"))
        icon.resize((192, 192), Image.LANCZOS).save(os.path.join(web, "icons", "Icon-maskable-192.png"))
        icon.resize((512, 512), Image.LANCZOS).save(os.path.join(web, "icons", "Icon-maskable-512.png"))
        icon.resize((64, 64), Image.LANCZOS).save(os.path.join(web, "favicon.png"))

    print("wrote", master)


if __name__ == "__main__":
    main()
