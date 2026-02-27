#!/usr/bin/env python3
"""
Generate a macOS app icon for MarkdownViewer.

Usage:
    python3 make_icon.py

Output:
    AppIcon.icns  (in the current directory)

Requires Pillow — installed automatically if missing.
"""

import os, sys, subprocess, shutil
from pathlib import Path

# ── Auto-install Pillow ───────────────────────────────────────────────────────
try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    print("Installing Pillow…")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "Pillow"])
    from PIL import Image, ImageDraw, ImageFilter, ImageFont


# ── Design constants ──────────────────────────────────────────────────────────
MASTER   = 1024
CORNER   = 0.225   # squircle corner radius as fraction of size

# Diagonal gradient: bright indigo (top-left) → vibrant purple (bottom-right)
C_TL = (71,  118, 230)   # #4776E6
C_BR = (142,  84, 233)   # #8E54E9


# ── Building blocks ───────────────────────────────────────────────────────────

def diagonal_gradient(size: int) -> Image.Image:
    """Smooth 2-stop diagonal gradient via 2×2 seed + bicubic upscale."""
    def mix(a, b, t):
        return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

    seed = Image.new("RGB", (2, 2))
    seed.putdata([
        C_TL,              # top-left
        mix(C_TL, C_BR, 0.45),  # top-right
        mix(C_TL, C_BR, 0.55),  # bottom-left
        C_BR,              # bottom-right
    ])
    return seed.resize((size, size), Image.BICUBIC)


def inner_glow(size: int) -> Image.Image:
    """Soft white radial glow for depth — drawn with Gaussian blur."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    r     = int(size * 0.36)
    cx, cy = size // 2, int(size * 0.46)
    ImageDraw.Draw(layer).ellipse(
        [cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 55)
    )
    return layer.filter(ImageFilter.GaussianBlur(r // 2))


def squircle_mask(size: int) -> Image.Image:
    """Alpha mask with macOS-style rounded corners."""
    radius = int(size * CORNER)
    mask   = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def find_bold_font(size: int):
    """Return the best available bold system font at *size* pt."""
    candidates = [
        # SF Pro / NS (macOS 11+)
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/SFNSText.ttf",
        # Helvetica Neue Bold (index 2 in the .ttc collection)
        "/System/Library/Fonts/HelveticaNeue.ttc",
        # Arial Bold
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        # Georgia Bold — serif, still looks great large
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        # Last resort
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    ttc_bold_index = {
        "/System/Library/Fonts/HelveticaNeue.ttc": 2,  # HelveticaNeue-Bold
        "/System/Library/Fonts/Helvetica.ttc":     0,
    }
    for path in candidates:
        if not os.path.exists(path):
            continue
        idx = ttc_bold_index.get(path, 0)
        for index in ([idx] + [i for i in range(6) if i != idx]):
            try:
                return ImageFont.truetype(path, size, index=index)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_letter(base: Image.Image, size: int) -> Image.Image:
    """Composite a centred white 'M' with a subtle drop shadow."""
    font       = find_bold_font(int(size * 0.60))
    shadow_off = max(5, int(size * 0.011))

    # Measure on a scratch canvas
    scratch = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    try:
        bbox = scratch.textbbox((0, 0), "M", font=font)
    except AttributeError:                          # Pillow < 8.0 fallback
        w, h = scratch.textsize("M", font=font)
        bbox = (0, 0, w, h)

    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1] - int(size * 0.02)  # slightly above centre

    # Shadow layer
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_layer)
    sd.text((x + shadow_off, y + shadow_off), "M", font=font, fill=(0, 0, 0, 80))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(shadow_off * 1.2))

    # Compose: base → shadow → letter
    out  = base.copy()
    out  = Image.alpha_composite(out, shadow_layer)
    draw = ImageDraw.Draw(out)
    draw.text((x, y), "M", font=font, fill=(255, 255, 255, 245))
    return out


# ── Assemble ──────────────────────────────────────────────────────────────────

def generate(size: int = MASTER) -> Image.Image:
    img = diagonal_gradient(size).convert("RGBA")
    img = Image.alpha_composite(img, inner_glow(size))
    img = draw_letter(img, size)
    img.putalpha(squircle_mask(size))
    return img


# ── Export ────────────────────────────────────────────────────────────────────

SIZES = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]


def export_icns(icon: Image.Image, out: Path = Path(".")) -> None:
    iconset = out / "AppIcon.iconset"
    iconset.mkdir(exist_ok=True)

    for px, name in SIZES:
        dest = iconset / f"{name}.png"
        icon.resize((px, px), Image.LANCZOS).save(str(dest), "PNG")
        print(f"  {px:4d}px  {dest.name}")

    icns   = out / "AppIcon.icns"
    result = subprocess.run(
        ["iconutil", "-c", "icns", str(iconset), "-o", str(icns)],
        capture_output=True, text=True,
    )
    shutil.rmtree(iconset)

    if result.returncode == 0:
        print(f"\n✔  {icns.resolve()}")
    else:
        raise RuntimeError(f"iconutil failed:\n{result.stderr}")


if __name__ == "__main__":
    print("Generating icon…")
    export_icns(generate())
