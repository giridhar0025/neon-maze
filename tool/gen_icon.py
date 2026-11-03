"""Generate the Neon Maze app icon, adaptive foreground and all platform sizes.

The mark is a bold, rounded neon maze with a glass marble and a mint exit. It
is drawn in normalised coordinates on a supersampled canvas, then exported to
every target the project ships: Android (legacy + adaptive), iOS, macOS, the
web/PWA icons, the favicon and the Android launch mark.
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2048  # supersampled working size
OUT = 1024

CYAN = (64, 244, 228)
TEAL = (56, 214, 255)
VIOLET = (150, 92, 255)
MAGENTA = (224, 92, 255)
MINT = (92, 255, 186)
WHITE = (255, 255, 255)

BG_TOP = (10, 18, 38)
BG_MID = (6, 10, 22)
BG_BOTTOM = (3, 5, 12)


def lerp_color(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, stops, diagonal=True):
    """Return an RGB gradient image from [(position, colour), ...]."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1)) if diagonal else y / (size - 1)
            colour = stops[0][1]
            for i in range(1, len(stops)):
                p0, c0 = stops[i - 1]
                p1, c1 = stops[i]
                if t <= p1 or i == len(stops) - 1:
                    local = 0.0 if p1 == p0 else (t - p0) / (p1 - p0)
                    colour = lerp_color(c0, c1, max(0.0, min(1.0, local)))
                    break
            px[x, y] = colour
    return img


def rounded_line(draw, p1, p2, width, fill):
    draw.line([p1, p2], fill=fill, width=width, joint="curve")
    r = width / 2
    for p in (p1, p2):
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)


def build_background():
    bg = Image.new("RGB", (S, S), BG_BOTTOM)
    px = bg.load()
    for y in range(S):
        t = y / (S - 1)
        if t < 0.55:
            colour = lerp_color(BG_TOP, BG_MID, t / 0.55)
        else:
            colour = lerp_color(BG_MID, BG_BOTTOM, (t - 0.55) / 0.45)
        for x in range(S):
            px[x, y] = colour

    bg = bg.convert("RGBA")

    # Wide cyan / violet atmosphere.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-S * 0.30, -S * 0.36, S * 0.92, S * 0.66], fill=CYAN + (38,))
    gd.ellipse([S * 0.34, S * 0.08, S * 1.38, S * 1.02], fill=VIOLET + (36,))
    gd.ellipse([S * 0.56, S * 0.58, S * 1.10, S * 1.14], fill=MAGENTA + (22,))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.10))
    bg = Image.alpha_composite(bg, glow)

    # Faint technical grid.
    grid = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gdd = ImageDraw.Draw(grid)
    step = S // 24
    for x in range(0, S, step):
        gdd.line([(x, 0), (x, S)], fill=(255, 255, 255, 6), width=max(1, S // 1500))
    for y in range(0, S, step):
        gdd.line([(0, y), (S, y)], fill=(255, 255, 255, 6), width=max(1, S // 1500))
    bg = Image.alpha_composite(bg, grid)
    return bg


def build_art(canvas_size=S, art_scale=0.70):
    """Draw the transparent N-monogram/marble mark centred on a canvas."""
    art = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    side = int(canvas_size * art_scale)
    ox = (canvas_size - side) // 2
    oy = (canvas_size - side) // 2

    # The mark is an N built from rounded, axis-aligned maze walls. A stepped
    # diagonal keeps the letter unmistakably "maze" rather than a plain glyph.
    wall_w = int(side * 0.085)
    left, right = 0.22, 0.78
    top, bottom = 0.17, 0.83
    steps = 5

    def px(nx):
        return ox + side * nx

    def py(ny):
        return oy + side * ny

    walls = [
        ((px(left), py(top)), (px(left), py(bottom))),
        ((px(right), py(top)), (px(right), py(bottom))),
    ]
    step_x = (right - left) / steps
    step_y = (bottom - top) / steps
    for k in range(steps):
        x0 = left + step_x * k
        x1 = left + step_x * (k + 1)
        y0 = top + step_y * k
        y1 = top + step_y * (k + 1)
        walls.append(((px(x0), py(y0)), (px(x1), py(y0))))
        walls.append(((px(x1), py(y0)), (px(x1), py(y1))))

    # Wall mask: white lines, coloured with a cyan -> violet gradient.
    mask = Image.new("L", (canvas_size, canvas_size), 0)
    md = ImageDraw.Draw(mask)
    for a, b in walls:
        rounded_line(md, a, b, wall_w, 255)

    wall_gradient = gradient(
        canvas_size,
        [
            (0.0, CYAN),
            (0.34, TEAL),
            (0.68, VIOLET),
            (1.0, MAGENTA),
        ],
        diagonal=True,
    ).convert("RGBA")
    wall_gradient.putalpha(mask)

    # Layered bloom under the crisp neon.
    halo_far = wall_gradient.filter(ImageFilter.GaussianBlur(side * 0.035))
    halo_far.putalpha(halo_far.getchannel("A").point(lambda v: int(v * 0.55)))
    halo_near = wall_gradient.filter(ImageFilter.GaussianBlur(side * 0.013))
    halo_near.putalpha(halo_near.getchannel("A").point(lambda v: int(v * 0.85)))
    art = Image.alpha_composite(art, halo_far)
    art = Image.alpha_composite(art, halo_near)
    art = Image.alpha_composite(art, wall_gradient)

    # A thin specular edge on the walls makes the mark crisp at small sizes.
    highlight = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    for a, b in walls:
        rounded_line(hd, a, b, max(1, int(wall_w * 0.16)), (255, 255, 255, 64))
    highlight = highlight.filter(ImageFilter.GaussianBlur(side * 0.0025))
    art = Image.alpha_composite(art, highlight)

    # Junction bolts at wall ends.
    bolts = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bolts)
    seen = set()
    for a, b in walls:
        for p in (a, b):
            key = (round(p[0], 3), round(p[1], 3))
            if key in seen:
                continue
            seen.add(key)
            r = wall_w * 0.12
            bd.ellipse(
                [p[0] - r, p[1] - r, p[0] + r, p[1] + r],
                fill=(240, 255, 255, 74),
            )
    art = Image.alpha_composite(art, bolts)

    # Mint goal node at the foot of the right arm.
    ex, ey, er = px(right), py(bottom), side * 0.048
    node = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    nd = ImageDraw.Draw(node)
    nd.ellipse(
        [ex - er * 1.85, ey - er * 1.85, ex + er * 1.85, ey + er * 1.85],
        fill=MINT + (54,),
    )
    node = node.filter(ImageFilter.GaussianBlur(side * 0.024))
    art = Image.alpha_composite(art, node)

    node = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    nd = ImageDraw.Draw(node)
    nd.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(20, 70, 58, 210))
    nd.ellipse(
        [ex - er, ey - er, ex + er, ey + er],
        outline=MINT + (255,),
        width=max(2, int(side * 0.008)),
    )
    nd.ellipse(
        [ex - er * 0.46, ey - er * 0.46, ex + er * 0.46, ey + er * 0.46],
        fill=MINT + (255,),
    )
    art = Image.alpha_composite(art, node)

    # Glass marble accent in the N's open upper-right counter.
    mx = px(0.65)
    my = py(0.30)
    mr = side * 0.082

    shadow = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        [mx - mr * 1.20, my + mr * 0.58, mx + mr * 1.20, my + mr * 1.12],
        fill=(0, 0, 0, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(side * 0.020))
    art = Image.alpha_composite(art, shadow)

    halo = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    hd2 = ImageDraw.Draw(halo)
    hd2.ellipse(
        [mx - mr * 1.65, my - mr * 1.65, mx + mr * 1.65, my + mr * 1.65],
        fill=CYAN + (70,),
    )
    halo = halo.filter(ImageFilter.GaussianBlur(side * 0.030))
    art = Image.alpha_composite(art, halo)

    # Orbit arc.
    orbit = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    od = ImageDraw.Draw(orbit)
    orb_r = mr * 1.46
    od.arc(
        [mx - orb_r, my - orb_r, mx + orb_r, my + orb_r],
        start=205,
        end=315,
        fill=CYAN + (180,),
        width=max(2, int(side * 0.006)),
    )
    art = Image.alpha_composite(art, orbit)

    # Glass body: stepped radial rings give a smooth gradient without a shader.
    marble = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    md2 = ImageDraw.Draw(marble)
    steps = 120
    for i in range(steps, 0, -1):
        t = i / steps
        r = mr * t
        col = lerp_color(WHITE, (150, 255, 250), min(1.0, (1 - t) * 1.25))
        col = lerp_color(col, CYAN, max(0.0, (0.62 - t) / 0.62) * 0.55)
        col = lerp_color(col, (7, 20, 42), max(0.0, (t - 0.58) / 0.42))
        md2.ellipse([mx - r, my - r, mx + r, my + r], fill=col + (255,))
    md2.ellipse(
        [mx - mr, my - mr, mx + mr, my + mr],
        outline=(220, 255, 255, 185),
        width=max(2, int(side * 0.004)),
    )
    hl = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    hld = ImageDraw.Draw(hl)
    hld.ellipse(
        [mx - mr * 0.58, my - mr * 0.74, mx + mr * 0.08, my - mr * 0.20],
        fill=(255, 255, 255, 240),
    )
    hld.ellipse(
        [mx + mr * 0.10, my - mr * 0.58, mx + mr * 0.34, my - mr * 0.34],
        fill=(255, 255, 255, 170),
    )
    hl = hl.filter(ImageFilter.GaussianBlur(side * 0.005))
    marble = Image.alpha_composite(marble, hl)
    # Under-lit crescent.
    crescent = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(crescent)
    cd.arc(
        [mx - mr * 0.70, my - mr * 0.70, mx + mr * 0.70, my + mr * 0.70],
        start=200,
        end=330,
        fill=(255, 255, 255, 105),
        width=max(2, int(side * 0.005)),
    )
    marble = Image.alpha_composite(marble, crescent)
    art = Image.alpha_composite(art, marble)

    return art


def build_icon():
    background = build_background()
    art = build_art(S, art_scale=0.74)
    icon = Image.alpha_composite(background, art)

    # Vignette.
    vignette = Image.new("L", (S, S), 0)
    vd = ImageDraw.Draw(vignette)
    vd.ellipse([-S * 0.20, -S * 0.20, S * 1.20, S * 1.20], fill=255)
    vignette = ImageOps.invert(vignette).filter(ImageFilter.GaussianBlur(S * 0.10))
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(vignette.point(lambda v: int(v * 0.46)))
    icon = Image.alpha_composite(icon, shadow)
    return icon.convert("RGB").resize((OUT, OUT), Image.LANCZOS)


def build_mark(size):
    """Transparent launch mark (no background plate)."""
    art = build_art(S, art_scale=0.82)
    bbox = art.getbbox()
    if bbox:
        art = art.crop(bbox)
    return art.resize((size, size), Image.LANCZOS)


def save_android(icon):
    android = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for bucket, size in android.items():
        path = os.path.join(ROOT, "android", "app", "src", "main", "res", f"mipmap-{bucket}")
        os.makedirs(path, exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(path, "ic_launcher.png"))

    # Adaptive icon foreground: 108dp canvas, artwork inside the 66dp safe zone.
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    foreground = build_art(S, art_scale=0.60)
    for bucket, size in adaptive.items():
        path = os.path.join(ROOT, "android", "app", "src", "main", "res", f"mipmap-{bucket}")
        foreground.resize((size, size), Image.LANCZOS).save(
            os.path.join(path, "ic_launcher_foreground.png")
        )

    anydpi = os.path.join(ROOT, "android", "app", "src", "main", "res", "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8") as fh:
        fh.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            "</adaptive-icon>\n"
        )

    values = os.path.join(ROOT, "android", "app", "src", "main", "res", "values")
    colors_path = os.path.join(values, "colors.xml")
    colors = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="launch_bg">#04060D</color>\n'
        '    <color name="ic_launcher_background">#060B18</color>\n'
        "</resources>\n"
    )
    with open(colors_path, "w", encoding="utf-8") as fh:
        fh.write(colors)

    # Android 12+ splash icon.
    drawable = os.path.join(ROOT, "android", "app", "src", "main", "res", "drawable-nodpi")
    os.makedirs(drawable, exist_ok=True)
    build_mark(360).save(os.path.join(drawable, "launch_logo.png"))


def save_ios(icon):
    ios_dir = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    if not os.path.isdir(ios_dir):
        return
    for name, size in sizes.items():
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(ios_dir, name))


def save_macos(icon):
    macos_dir = os.path.join(ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    sizes = {16: 16, 32: 32, 64: 64, 128: 128, 256: 256, 512: 512, 1024: 1024}
    if not os.path.isdir(macos_dir):
        return
    for px, size in sizes.items():
        icon.resize((size, size), Image.LANCZOS).save(
            os.path.join(macos_dir, f"app_icon_{px}.png")
        )


def save_web(icon):
    web = os.path.join(ROOT, "web")
    if not os.path.isdir(web):
        return
    icons = os.path.join(web, "icons")
    os.makedirs(icons, exist_ok=True)
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(icons, "Icon-192.png"))
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(icons, "Icon-512.png"))
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(icons, "Icon-maskable-192.png"))
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(icons, "Icon-maskable-512.png"))
    icon.resize((64, 64), Image.LANCZOS).save(os.path.join(web, "favicon.png"))
    icon.resize((32, 32), Image.LANCZOS).save(os.path.join(web, "favicon-32.png"))


def main() -> None:
    icon = build_icon()
    icon_dir = os.path.join(ROOT, "assets", "icon")
    os.makedirs(icon_dir, exist_ok=True)
    master = os.path.join(icon_dir, "icon-1024.png")
    icon.save(master)

    save_android(icon)
    save_ios(icon)
    save_macos(icon)
    save_web(icon)
    print("wrote", master)


if __name__ == "__main__":
    main()
