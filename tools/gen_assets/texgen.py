"""
texgen — a tiny procedural texture toolkit (numpy + Pillow).

Everything here is built for small, tileable, palette-limited textures in the
PlayStation-era spirit: 64–128 px, nearest-filtered, ordered-dithered.
All noise is periodic so every texture tiles without seams.

Conventions
-----------
* Images are float arrays in [0, 1] shaped (H, W, 3) or (H, W, 4).
* `rng` is a numpy Generator; every generator is deterministic for a seed.
* Colours are given as hex strings ("#a1b2c3") or float RGB arrays.
"""
from __future__ import annotations

import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT_DIR = ROOT / "assets" / "fonts"

FONTS = {
    "title": FONT_DIR / "Jacquard12-Regular.ttf",
    "display": FONT_DIR / "Metamorphous-Regular.ttf",
    "body": FONT_DIR / "VT323-Regular.ttf",
}


# --------------------------------------------------------------------------
# basics
# --------------------------------------------------------------------------

def rng_for(name: str, seed: int = 1337) -> np.random.Generator:
    """Deterministic generator per texture name."""
    h = 2166136261
    for ch in name.encode():
        h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
    return np.random.default_rng((h ^ seed) & 0xFFFFFFFF)


def hexc(c) -> np.ndarray:
    """'#rrggbb' -> float rgb array. Passes arrays through."""
    if isinstance(c, str):
        c = c.lstrip("#")
        return np.array([int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)
    return np.asarray(c, dtype=np.float32)


def solid(size, color, alpha=None) -> np.ndarray:
    h, w = _hw(size)
    img = np.ones((h, w, 3), dtype=np.float32) * hexc(color)
    if alpha is not None:
        img = add_alpha(img, alpha)
    return img


def _hw(size):
    if isinstance(size, int):
        return size, size
    return size[1], size[0]  # size given as (w, h)


def clamp01(a):
    return np.clip(a, 0.0, 1.0)


def mix(a, b, t):
    t = np.asarray(t, dtype=np.float32)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1.0 - t) + b * t


def add_alpha(rgb: np.ndarray, alpha) -> np.ndarray:
    alpha = np.asarray(alpha, dtype=np.float32)
    if alpha.ndim == 0:
        alpha = np.full(rgb.shape[:2], float(alpha), dtype=np.float32)
    return np.concatenate([rgb[..., :3], alpha[..., None]], axis=-1)


def smoothstep(t):
    return t * t * (3.0 - 2.0 * t)


# --------------------------------------------------------------------------
# noise (all periodic / tileable)
# --------------------------------------------------------------------------

def _lattice_noise(h, w, cy, cx, rng):
    """One octave of periodic value noise with cy x cx lattice cells."""
    cy = max(1, int(cy))
    cx = max(1, int(cx))
    lat = rng.random((cy, cx)).astype(np.float32)
    ys = (np.arange(h, dtype=np.float32) / h) * cy
    xs = (np.arange(w, dtype=np.float32) / w) * cx
    y0 = np.floor(ys).astype(int) % cy
    x0 = np.floor(xs).astype(int) % cx
    y1 = (y0 + 1) % cy
    x1 = (x0 + 1) % cx
    ty = smoothstep(ys - np.floor(ys))[:, None]
    tx = smoothstep(xs - np.floor(xs))[None, :]
    a = lat[y0][:, x0]
    b = lat[y0][:, x1]
    c = lat[y1][:, x0]
    d = lat[y1][:, x1]
    top = a * (1 - tx) + b * tx
    bot = c * (1 - tx) + d * tx
    return top * (1 - ty) + bot * ty


def noise(size, cells, rng, octaves=4, persistence=0.5, lacunarity=2.0, cells_y=None):
    """Tileable fractal value noise in [0,1]. `cells` is the base frequency
    (number of lattice cells across the image). `cells_y` allows anisotropy."""
    h, w = _hw(size)
    cx = cells
    cy = cells if cells_y is None else cells_y
    total = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        total += amp * _lattice_noise(h, w, cy * lacunarity ** o, cx * lacunarity ** o, rng)
        norm += amp
        amp *= persistence
    n = total / norm
    lo, hi = n.min(), n.max()
    return (n - lo) / max(1e-6, hi - lo)


def ridged(size, cells, rng, octaves=4, cells_y=None):
    """Ridged noise: sharp bright creases (bark, veins, cracks)."""
    h, w = _hw(size)
    cx = cells
    cy = cells if cells_y is None else cells_y
    total = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        n = _lattice_noise(h, w, cy * 2 ** o, cx * 2 ** o, rng)
        total += amp * (1.0 - np.abs(n * 2.0 - 1.0))
        norm += amp
        amp *= 0.5
    return total / norm


def worley(size, npts, rng, wrap=True):
    """Tileable cellular noise. Returns (F1, F2, cell_id) with distances
    normalised roughly to [0,1]."""
    h, w = _hw(size)
    pts = rng.random((npts, 2)).astype(np.float32)
    ys = (np.arange(h, dtype=np.float32) + 0.5) / h
    xs = (np.arange(w, dtype=np.float32) + 0.5) / w
    gy, gx = np.meshgrid(ys, xs, indexing="ij")
    f1 = np.full((h, w), 9.0, dtype=np.float32)
    f2 = np.full((h, w), 9.0, dtype=np.float32)
    ids = np.zeros((h, w), dtype=np.int32)
    offsets = [(0, 0)]
    if wrap:
        offsets = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)]
    for i, (py, px) in enumerate(pts):
        for dy, dx in offsets:
            d = np.sqrt((gy - (py + dy)) ** 2 + (gx - (px + dx)) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ids = np.where(closer, i, ids)
            f1 = np.where(closer, d, f1)
    scale = np.sqrt(1.0 / npts)
    return clamp01(f1 / (scale * 1.6)), clamp01(f2 / (scale * 1.6)), ids


def bayer(size) -> np.ndarray:
    m = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0
    h, w = _hw(size)
    reps = (h // 4 + 1, w // 4 + 1)
    return np.tile(m, reps)[:h, :w]


def quantize(img, levels=12, dither=0.6) -> np.ndarray:
    """Ordered-dither quantisation per channel (keeps alpha untouched)."""
    rgb = img[..., :3]
    b = (bayer(rgb.shape[:2][::-1]) - 0.5) * dither / levels
    q = np.floor((rgb + b[..., None]) * levels + 0.5) / levels
    q = clamp01(q)
    if img.shape[-1] == 4:
        return np.concatenate([q, img[..., 3:4]], axis=-1)
    return q


def palette(t, stops) -> np.ndarray:
    """Map a scalar field t in [0,1] through colour stops [(pos, '#hex'), ...]."""
    t = np.asarray(t, dtype=np.float32)
    out = np.zeros(t.shape + (3,), dtype=np.float32)
    stops = sorted(stops, key=lambda s: s[0])
    pos = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.stack([hexc(s[1]) for s in stops])
    for ch in range(3):
        out[..., ch] = np.interp(t, pos, cols[:, ch])
    return out


def gradient_v(size, top, bottom, power=1.0) -> np.ndarray:
    h, w = _hw(size)
    t = (np.arange(h, dtype=np.float32) / max(1, h - 1)) ** power
    col = hexc(top)[None, :] * (1.0 - t[:, None]) + hexc(bottom)[None, :] * t[:, None]
    return np.repeat(col[:, None, :], w, axis=1).astype(np.float32)


def grain(img, rng, amount=0.05, mono=True) -> np.ndarray:
    h, w = img.shape[:2]
    if mono:
        g = rng.normal(0.0, amount, (h, w, 1)).astype(np.float32)
    else:
        g = rng.normal(0.0, amount, (h, w, 3)).astype(np.float32)
    out = img.copy()
    out[..., :3] = clamp01(out[..., :3] + g)
    return out


def blur(a, r=1):
    """Cheap tileable box blur on a 2D field."""
    out = np.zeros_like(a)
    n = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
            n += 1
    return out / n


def vignette(img, strength=0.35, power=1.5) -> np.ndarray:
    h, w = img.shape[:2]
    ys = (np.arange(h) + 0.5) / h * 2 - 1
    xs = (np.arange(w) + 0.5) / w * 2 - 1
    gy, gx = np.meshgrid(ys, xs, indexing="ij")
    d = clamp01(np.sqrt(gx ** 2 + gy ** 2) / 1.2) ** power
    out = img.copy()
    out[..., :3] *= (1.0 - strength * d)[..., None]
    return out


def shade(img, field, amount=0.2) -> np.ndarray:
    """Multiply brightness by (1 + amount*(field-0.5)*2)."""
    out = img.copy()
    f = 1.0 + amount * (np.asarray(field, dtype=np.float32) - 0.5) * 2.0
    out[..., :3] = clamp01(out[..., :3] * f[..., None])
    return out


def tint(img, color, amount) -> np.ndarray:
    out = img.copy()
    out[..., :3] = mix(out[..., :3], hexc(color)[None, None, :], amount)
    return out


# --------------------------------------------------------------------------
# structural patterns
# --------------------------------------------------------------------------

def bricks(size, rows, cols, rng, mortar=1, offset=0.5, jitter=0.0):
    """Running-bond brick layout.
    Returns (brick_id, mortar_mask, bevel) where bevel is +1 on lit edges and -1 on
    shadowed edges (0 elsewhere)."""
    h, w = _hw(size)
    bh = h / rows
    bw = w / cols
    ids = np.zeros((h, w), dtype=np.int32)
    mortar_mask = np.zeros((h, w), dtype=np.float32)
    bevel = np.zeros((h, w), dtype=np.float32)
    ys = np.arange(h)
    xs = np.arange(w)
    row = np.floor(ys / bh).astype(int)
    yin = ys - row * bh
    for y in range(h):
        r = row[y]
        shift = (r % 2) * offset * bw
        xr = (xs + shift) % w
        col = np.floor(xr / bw).astype(int)
        xin = xr - col * bw
        ids[y] = r * 1000 + col
        m = (yin[y] < mortar) | (xin < mortar)
        mortar_mask[y, m] = 1.0
        lit = ((yin[y] >= mortar) & (yin[y] < mortar + 1)) | ((xin >= mortar) & (xin < mortar + 1))
        dark = (yin[y] >= bh - 1) | (xin >= bw - 1)
        bevel[y, lit & ~m] = 1.0
        bevel[y, dark & ~m] = -1.0
    return ids, mortar_mask, bevel


def id_variation(ids, rng, amount=1.0):
    """Per-cell random value in [0,1] from an id map."""
    uniq = np.unique(ids)
    lut = {u: rng.random() for u in uniq}
    out = np.vectorize(lut.get)(ids).astype(np.float32)
    return out * amount


def planks(size, n, rng, vertical=False, gap=1, stagger=True):
    """Plank lanes with end joints. Returns (plank_id, gap_mask, along, across)
    where along/across are [0,1] coordinates within the plank for grain."""
    h, w = _hw(size)
    L = w if not vertical else h
    T = h if not vertical else w
    lane_t = T / n
    ids = np.zeros((h, w), dtype=np.int32)
    gapm = np.zeros((h, w), dtype=np.float32)
    for lane in range(n):
        t0 = int(round(lane * lane_t))
        t1 = int(round((lane + 1) * lane_t))
        joint = int(rng.integers(0, L)) if stagger else 0
        for t in range(t0, t1):
            for s in range(L):
                seg = 0 if ((s - joint) % L) < L * 0.5 else 1
                y, x = (t, s) if not vertical else (s, t)
                ids[y, x] = lane * 10 + seg
                is_gap = (t - t0) < gap or ((s - joint) % L) < gap or ((s - joint) % L) >= L * 0.5 and ((s - joint) % L) < L * 0.5 + gap
                if is_gap:
                    gapm[y, x] = 1.0
    return ids, gapm


def tiles(size, n, gap=1, ny=None):
    """Square tile grid. Returns (tile_id, grout_mask, bevel)."""
    h, w = _hw(size)
    ny = n if ny is None else ny
    tw = w / n
    th = h / ny
    ys = np.arange(h)
    xs = np.arange(w)
    ty = np.floor(ys / th).astype(int)
    tx = np.floor(xs / tw).astype(int)
    yin = ys - ty * th
    xin = xs - tx * tw
    ids = ty[:, None] * 1000 + tx[None, :]
    grout = ((yin < gap)[:, None] | (xin < gap)[None, :]).astype(np.float32)
    lit = ((yin >= gap) & (yin < gap + 1))[:, None] | ((xin >= gap) & (xin < gap + 1))[None, :]
    dark = (yin >= th - 1)[:, None] | (xin >= tw - 1)[None, :]
    bevel = np.zeros((h, w), dtype=np.float32)
    bevel[lit & (grout == 0)] = 1.0
    bevel[dark & (grout == 0)] = -1.0
    return ids, grout, bevel


def stripes_v(size, period, duty=0.5, soft=0.0):
    h, w = _hw(size)
    x = (np.arange(w) % period) / period
    s = (x < duty).astype(np.float32)
    return np.repeat(s[None, :], h, axis=0)


def cracks(size, rng, n=3, steps=40, width=1) -> np.ndarray:
    """Random-walk crack mask."""
    h, w = _hw(size)
    m = np.zeros((h, w), dtype=np.float32)
    for _ in range(n):
        y = rng.random() * h
        x = rng.random() * w
        ang = rng.random() * np.pi * 2
        for _ in range(steps):
            ang += rng.normal(0, 0.5)
            y += np.sin(ang)
            x += np.cos(ang)
            iy, ix = int(y) % h, int(x) % w
            m[iy, ix] = 1.0
            if width > 1:
                m[(iy + 1) % h, ix] = 1.0
    return m


def scatter_blobs(size, rng, n, rmin, rmax, value=1.0, soft=True):
    """Soft/hard circular blobs (tileable)."""
    h, w = _hw(size)
    m = np.zeros((h, w), dtype=np.float32)
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    for _ in range(n):
        cy = rng.random() * h
        cx = rng.random() * w
        r = rng.uniform(rmin, rmax)
        dy = np.minimum(np.abs(ys - cy), h - np.abs(ys - cy))
        dx = np.minimum(np.abs(xs - cx), w - np.abs(xs - cx))
        d = np.sqrt(dy ** 2 + dx ** 2) / r
        if soft:
            m = np.maximum(m, clamp01(1.0 - d) * value)
        else:
            m = np.maximum(m, (d < 1.0).astype(np.float32) * value)
    return m


# --------------------------------------------------------------------------
# PIL drawing helpers
# --------------------------------------------------------------------------

def to_pil(img) -> Image.Image:
    a = (clamp01(img) * 255.0 + 0.5).astype(np.uint8)
    return Image.fromarray(a, "RGBA" if a.shape[-1] == 4 else "RGB")


def from_pil(im: Image.Image) -> np.ndarray:
    return np.asarray(im).astype(np.float32) / 255.0


def draw_on(img, fn):
    """Run fn(ImageDraw, (w, h)) on the image and return a float array."""
    im = to_pil(img)
    d = ImageDraw.Draw(im)
    fn(d, im.size)
    return from_pil(im)


def font(kind="body", size=16) -> ImageFont.FreeTypeFont:
    p = FONTS.get(kind, FONTS["body"])
    try:
        return ImageFont.truetype(str(p), size)
    except OSError:
        return ImageFont.load_default()


def text_block(size, lines, color, bg, kind="body", font_size=14, align="center",
               line_gap=2, alpha=None, margin=4, valign="middle"):
    """Render lines of text into an image. Returns float RGB(A)."""
    h, w = _hw(size)
    base = solid((w, h), bg) if not isinstance(bg, np.ndarray) else bg.copy()
    im = to_pil(base)
    d = ImageDraw.Draw(im)
    f = font(kind, font_size)
    # auto-fit: shrink until the widest line fits inside the margins
    while font_size > 6:
        widest = max((d.textbbox((0, 0), ln, font=f)[2] - d.textbbox((0, 0), ln, font=f)[0]) for ln in lines) if lines else 0
        total_h = sum((d.textbbox((0, 0), ln, font=f)[3] - d.textbbox((0, 0), ln, font=f)[1]) for ln in lines) + line_gap * (len(lines) - 1)
        if widest <= w - 2 * margin and total_h <= h - 2 * margin:
            break
        font_size -= 1
        f = font(kind, font_size)
    heights = []
    for ln in lines:
        bbox = d.textbbox((0, 0), ln, font=f)
        heights.append(bbox[3] - bbox[1])
    total = sum(heights) + line_gap * (len(lines) - 1)
    if valign == "middle":
        y = (h - total) / 2
    elif valign == "top":
        y = margin
    else:
        y = h - total - margin
    col = tuple(int(c * 255) for c in hexc(color))
    for ln, lh in zip(lines, heights):
        bbox = d.textbbox((0, 0), ln, font=f)
        tw = bbox[2] - bbox[0]
        if align == "center":
            x = (w - tw) / 2 - bbox[0]
        elif align == "left":
            x = margin - bbox[0]
        else:
            x = w - tw - margin - bbox[0]
        d.text((x, y - bbox[1]), ln, font=f, fill=col)
        y += lh + line_gap
    out = from_pil(im)
    if alpha is not None:
        out = add_alpha(out[..., :3], alpha)
    return out


def frame(img, color, width=2, inner=None, inner_width=1):
    """Draw a rectangular frame around the image edge."""
    def fn(d, sz):
        w, h = sz
        c = tuple(int(x * 255) for x in hexc(color))
        for i in range(width):
            d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=c)
        if inner is not None:
            ci = tuple(int(x * 255) for x in hexc(inner))
            for i in range(width, width + inner_width):
                d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=ci)
    return draw_on(img, fn)


# --------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------

def save_png(path: Path, img: np.ndarray) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    to_pil(img).save(path, optimize=True)


def contact_sheet(paths, out, cell=96, cols=10, label=True):
    """Assemble a contact sheet for eyeballing the catalogue."""
    paths = list(paths)
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 14)), (20, 20, 24))
    d = ImageDraw.Draw(sheet)
    f = font("body", 12)
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        im = im.resize((cell - 4, cell - 4), Image.NEAREST)
        x = (i % cols) * cell + 2
        y = (i // cols) * (cell + 14) + 2
        bg = Image.new("RGBA", im.size, (60, 40, 70, 255))
        bg.alpha_composite(im)
        sheet.paste(bg.convert("RGB"), (x, y))
        if label:
            d.text((x, y + cell - 3), Path(p).stem[:16], font=f, fill=(200, 200, 200))
    sheet.save(out)
