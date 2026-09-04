"""
textures — the texture catalogue for ANTEROOM.

Run from the repo root:

    python3 tools/gen_assets/textures.py            # generate everything
    python3 tools/gen_assets/textures.py --only wood # subset (substring match)
    python3 tools/gen_assets/textures.py --sheet     # also write a contact sheet

Every texture is a small procedural function in this file, registered in
CATALOG as "group/name" -> (generator, options). Output goes to
assets/textures/<group>/<name>.png plus assets/textures/manifest.json, which
the Kit reads for footstep surfaces and tiling sizes.

Art direction: PlayStation-era. 64 px for surfaces, 128 px for pictures and
signs, ordered dither to ~12 levels per channel, saturated but sombre
palettes, one colour identity per realm.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import texgen as T  # noqa: E402

OUT = T.ROOT / "assets" / "textures"

# --------------------------------------------------------------------------
# palettes — one identity per realm
# --------------------------------------------------------------------------
P = {
    "waking": dict(wall="#c9b48a", wall2="#b9a276", wood="#6b4a2e", wood2="#553a22", trim="#efe6cf", teal="#6d9a94", dark="#2a2320"),
    "house": dict(wall="#8f8a6a", paper="#6d7a5a", paper2="#4f5a41", floral="#c9a0a8", wood="#4a3020", carpet="#a99a7a", dark="#1a1612"),
    "forest": dict(bg="#0f2a25", moss="#4a6b2f", moss2="#2f4a22", bark="#3b2a1f", bark2="#241811", glow="#7ff5e6", pink="#d55cff", fog="#6c8f8a", leaf="#2e5e3a", leaf2="#4f8a3f"),
    "city": dict(slate="#3a3d4a", slate2="#2a2c36", bone="#c9c2b0", bone2="#a89f8c", water="#17323a", rust="#7b3f2a", crimson="#6e1a2a", gold="#b8963e"),
    "tavern": dict(amber="#d9903a", wood="#3d2415", wood2="#2c1a0e", red="#7a1f1f", candle="#ffd27f", plaster="#c9b08a"),
    "castle": dict(stone="#5b5f6b", stone2="#464a55", velvet="#3e1f52", velvet2="#2b1538", gold="#c9a227", iron="#3a3a40"),
    "sea": dict(pink="#f5b8d0", lilac="#b7a6f0", mint="#a6f0d4", cream="#fff3dd", deep="#2b1a47", sky="#f7c9e0"),
    "catacombs": dict(bone="#d8cdb2", bone2="#b5a98b", dust="#6b6250", dark="#1a1612", torch="#ff9a3c"),
    "furnace": dict(black="#0d0507", red="#8b0f1e", ember="#ff5a1f", flesh="#b5555e", flesh2="#7a2f3a", vein="#3a1a4a"),
    "cistern": dict(tile="#e6ede9", tile2="#cfd9d4", cyan="#8fc7c2", water="#2f8f95", grout="#7f8a86", deep="#12484d"),
    "offices": dict(yellow="#d8c26a", yellow2="#c4ad55", beige="#cbbf9c", carpet="#55606b", carpet2="#46505a", light="#fff8dc", ceiling="#e2dcc8"),
    "clocktower": dict(brass="#b58a3c", brass2="#8a6628", wood="#3a2a1a", iron="#4a4a50"),
    "nexus": dict(indigo="#1a1533", stone="#454866", stone2="#33365a", gold="#d9b24c", well="#0b0a18"),
    "hallway": dict(black="#1e1e24", grey="#3c3c44", cold="#3d4550"),
}


# --------------------------------------------------------------------------
# helpers shared by generators
# --------------------------------------------------------------------------

def bevel_shade(img, bevel, amount=0.22):
    out = img.copy()
    out[..., :3] = T.clamp01(out[..., :3] * (1.0 + amount * bevel)[..., None])
    return out


def stone_blocks(rng, c1, c2, mortar, rows=4, cols=3, size=64, cracks=2, grain=0.05, levels=12):
    ids, m, bev = T.bricks(size, rows, cols, rng, mortar=2)
    var = T.id_variation(ids, rng)
    n = T.noise(size, 6, rng, octaves=3)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), var * 0.7 + n * 0.3)
    base = T.shade(base, n, 0.25)
    base = bevel_shade(base, bev)
    base = T.mix(base, T.solid(size, mortar), m)
    if cracks:
        ck = T.cracks(size, rng, n=cracks, steps=30)
        base = T.mix(base, T.solid(size, mortar), ck * (1 - m))
    return T.quantize(T.grain(base, rng, grain), levels)


def cobbles(rng, c1, c2, mortar, size=64, npts=22, moss=None, levels=12):
    f1, f2, ids = T.worley(size, npts, rng)
    edge = T.clamp01((f2 - f1) * 6.0)
    var = T.id_variation(ids, rng)
    n = T.noise(size, 8, rng, octaves=3)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), var)
    base = T.shade(base, 1.0 - f1, 0.3)
    base = T.shade(base, n, 0.15)
    base = T.mix(T.solid(size, mortar), base, edge)
    if moss is not None:
        mm = T.clamp01((T.noise(size, 3, rng, octaves=3) - 0.55) * 4.0) * (1 - edge * 0.5)
        base = T.mix(base, T.solid(size, moss), mm * 0.8)
    return T.quantize(T.grain(base, rng, 0.04), levels)


def plank_floor(rng, c1, c2, gap, n=6, size=64, vertical=False, grain_amt=0.3, levels=12, knots=True):
    ids, gm = T.planks(size, n, rng, vertical=vertical, gap=1)
    var = T.id_variation(ids, rng)
    g = T.noise(size, 2 if not vertical else 14, rng, octaves=4, cells_y=14 if not vertical else 2)
    g = T.ridged(size, 2 if not vertical else 12, rng, octaves=3, cells_y=12 if not vertical else 2) * 0.5 + g * 0.5
    base = T.mix(T.solid(size, c1), T.solid(size, c2), var * 0.8)
    base = T.shade(base, g, grain_amt)
    if knots:
        k = T.scatter_blobs(size, rng, 3, 2, 4, soft=True)
        base = T.shade(base, 1.0 - k * 0.8, 0.5)
    base = T.mix(base, T.solid(size, gap), gm)
    return T.quantize(T.grain(base, rng, 0.03), levels)


def tile_floor(rng, c1, c2, grout, n=4, size=64, gloss=0.18, levels=12, checker=None):
    ids, gm, bev = T.tiles(size, n, gap=1)
    var = T.id_variation(ids, rng)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), var * 0.6)
    if checker is not None:
        ty = (ids // 1000) % 2
        tx = (ids % 1000) % 2
        chk = ((ty + tx) % 2).astype(np.float32)
        base = T.mix(base, T.solid(size, checker), chk)
    # glossy highlight: brighter toward top-left of each tile
    h, w = base.shape[:2]
    yy = (np.arange(h) % (h / n)) / (h / n)
    xx = (np.arange(w) % (w / n)) / (w / n)
    gl = 1.0 - (yy[:, None] * 0.5 + xx[None, :] * 0.5)
    base = T.shade(base, gl, gloss)
    base = bevel_shade(base, bev, 0.18)
    base = T.mix(base, T.solid(size, grout), gm)
    return T.quantize(T.grain(base, rng, 0.02), levels)


def plaster(rng, c1, c2, size=64, stains=0.0, stain_color="#4a3a2a", levels=10):
    n = T.noise(size, 5, rng, octaves=4)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), n)
    if stains > 0:
        s = T.clamp01((T.noise(size, 2, rng, octaves=3) - 0.5) * 3.0) * stains
        base = T.mix(base, T.solid(size, stain_color), s)
    return T.quantize(T.grain(base, rng, 0.04), levels)


def damask(rng, bg, fg, size=64, stripes=True, levels=10):
    """Symmetric organic motif: mirror noise in both axes, threshold."""
    n = T.noise(size, 3, rng, octaves=3)
    n = np.maximum(n, n[:, ::-1])
    n = np.maximum(n, n[::-1, :])
    n = (n - n.min()) / max(1e-6, n.max() - n.min())
    motif = T.clamp01((n - 0.55) * 6.0)
    # add a lattice of small diamonds between the blobs
    yy, xx = np.meshgrid(np.arange(size), np.arange(size), indexing="ij")
    dia = ((np.abs((yy % 16) - 8) + np.abs((xx % 16) - 8)) < 3).astype(np.float32)
    motif = np.maximum(motif, dia * 0.6)
    base = T.solid(size, bg)
    if stripes:
        s = T.stripes_v(size, 8, 0.5)
        base = T.shade(base, s, 0.06)
    base = T.mix(base, T.solid(size, fg), motif)
    return T.quantize(base, levels)


def floral(rng, bg, petal, center, size=64, n=4, levels=10):
    base = plaster(rng, bg, bg, size, levels=64)
    def fn(d, sz):
        w, h = sz
        step = w / n
        pc = tuple(int(c * 255) for c in T.hexc(petal))
        cc = tuple(int(c * 255) for c in T.hexc(center))
        for i in range(n):
            for j in range(n):
                cx = (i + 0.5 + (0.5 if j % 2 else 0.0)) * step % w
                cy = (j + 0.5) * step
                for k in range(5):
                    a = k / 5.0 * 6.283
                    px = cx + np.cos(a) * step * 0.18
                    py = cy + np.sin(a) * step * 0.18
                    d.ellipse([px - 2, py - 2, px + 2, py + 2], fill=pc)
                d.ellipse([cx - 1.5, cy - 1.5, cx + 1.5, cy + 1.5], fill=cc)
    return T.quantize(T.draw_on(base, fn), levels)


def carpet(rng, c1, c2, border, size=64, pattern=True, levels=10):
    n = T.noise(size, 12, rng, octaves=2)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), n * 0.5)
    if pattern:
        def fn(d, sz):
            w, h = sz
            bc = tuple(int(c * 255) for c in T.hexc(border))
            d.rectangle([2, 2, w - 3, h - 3], outline=bc)
            d.rectangle([6, 6, w - 7, h - 7], outline=bc)
            cx, cy = w / 2, h / 2
            r = w * 0.22
            d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], outline=bc)
            d.polygon([(cx, cy - r * 0.5), (cx + r * 0.5, cy), (cx, cy + r * 0.5), (cx - r * 0.5, cy)], fill=bc)
        base = T.draw_on(base, fn)
    return T.quantize(T.grain(base, rng, 0.05), levels)


def bark(rng, c1, c2, size=64, levels=10, ridges=8):
    r = T.ridged(size, ridges, rng, octaves=4, cells_y=1)
    n = T.noise(size, 3, rng, octaves=3, cells_y=1)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), r)
    base = T.shade(base, n, 0.35)
    return T.quantize(T.grain(base, rng, 0.05), levels)


def grass(rng, c1, c2, blade, size=64, blades=140, levels=10):
    n = T.noise(size, 6, rng, octaves=4)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), n)
    def fn(d, sz):
        w, h = sz
        bc = tuple(int(c * 255) for c in T.hexc(blade))
        dark = tuple(int(c * 255 * 0.55) for c in T.hexc(blade))
        for _ in range(blades):
            x = rng.integers(0, w)
            y = rng.integers(0, h)
            ln = rng.integers(2, 6)
            dx = rng.integers(-1, 2)
            col = bc if rng.random() < 0.6 else dark
            d.line([(x, y), (x + dx, y - ln)], fill=col)
    base = T.draw_on(base, fn)
    return T.quantize(T.grain(base, rng, 0.04), levels)


def hedge(rng, colors, size=64, n=160, rmin=3, rmax=7, levels=12):
    """A clipped hedge: dense opaque leaf blobs over a dark base (no alpha)."""
    base = T.solid(size, colors[0])
    im = T.to_pil(base)
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    for i in range(n):
        x = rng.random() * size
        y = rng.random() * size
        r = rng.uniform(rmin, rmax)
        c = colors[int(rng.integers(1, len(colors)))]
        col = tuple(int(v * 255) for v in T.hexc(c))
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.ellipse([x + ox - r, y + oy - r * 0.7, x + ox + r, y + oy + r * 0.7], fill=col)
    out = T.from_pil(im)
    return T.quantize(T.grain(out[..., :3], rng, 0.03), levels)


def leaves_card(rng, colors, size=64, n=90, rmin=4, rmax=9, levels=12):
    """Alpha-cut leaf cluster for tree canopy cards."""
    base = T.solid(size, colors[0])
    alpha = np.zeros((size, size), dtype=np.float32)
    im = T.to_pil(T.add_alpha(base, alpha))
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    cx, cy = size / 2, size / 2
    for i in range(n):
        ang = rng.random() * 6.283
        rad = rng.random() ** 0.6 * size * 0.42
        x = cx + np.cos(ang) * rad
        y = cy + np.sin(ang) * rad
        r = rng.uniform(rmin, rmax)
        c = colors[int(rng.integers(0, len(colors)))]
        col = tuple(int(v * 255) for v in T.hexc(c)) + (255,)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=col)
    out = T.from_pil(im)
    rgb = T.quantize(out[..., :3], levels)
    return np.concatenate([rgb, out[..., 3:4]], axis=-1)


def sky(top, mid, bottom, size=(256, 128), stars=0, rng=None, bands=0.0, levels=24):
    h, w = size[1], size[0]
    t = np.arange(h, dtype=np.float32) / (h - 1)
    img = T.palette(np.repeat(t[:, None], w, axis=1), [(0, top), (0.55, mid), (1.0, bottom)])
    if bands > 0:
        b = np.sin(t * 40.0)[:, None] * bands
        img = T.clamp01(img + b[..., None])
    if stars and rng is not None:
        for _ in range(stars):
            y = int(rng.random() ** 2 * h * 0.8)
            x = int(rng.random() * w)
            v = rng.uniform(0.5, 1.0)
            img[y, x] = np.maximum(img[y, x], [v, v, v * 0.9])
    return T.quantize(img, levels, dither=0.35)


def keepsake_icon(kind, color, size=32):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = tuple(int(v * 255) for v in T.hexc(color)) + (255,)
    dark = tuple(int(v * 120) for v in T.hexc(color)) + (255,)
    white = (255, 250, 230, 255)
    if kind == "lantern":
        d.rectangle([12, 4, 20, 7], fill=dark)
        d.rectangle([9, 8, 23, 26], outline=c, width=2)
        d.polygon([(16, 12), (19, 19), (16, 24), (13, 19)], fill=(255, 200, 90, 255))
        d.rectangle([8, 26, 24, 28], fill=dark)
    elif kind == "wings":
        d.polygon([(16, 16), (2, 6), (5, 20), (14, 22)], fill=c, outline=dark)
        d.polygon([(16, 16), (30, 6), (27, 20), (18, 22)], fill=c, outline=dark)
        d.ellipse([14, 12, 18, 24], fill=dark)
    elif kind == "mouse":
        d.ellipse([6, 12, 24, 26], fill=c, outline=dark)
        d.ellipse([7, 7, 13, 13], fill=c, outline=dark)
        d.ellipse([15, 7, 21, 13], fill=c, outline=dark)
        d.line([(24, 20), (30, 14)], fill=dark, width=2)
        d.point([(10, 18)], fill=(0, 0, 0, 255))
        d.rectangle([12, 4, 20, 6], fill=dark)
    elif kind == "crown":
        d.polygon([(4, 26), (4, 10), (10, 18), (16, 6), (22, 18), (28, 10), (28, 26)], fill=c, outline=dark)
        d.line([(6, 22), (26, 22)], fill=dark)
    elif kind == "bell":
        d.polygon([(16, 4), (10, 10), (8, 22), (24, 22), (22, 10)], fill=c, outline=dark)
        d.rectangle([6, 22, 26, 25], fill=dark)
        d.ellipse([13, 25, 19, 30], fill=c)
    elif kind == "knife":
        d.polygon([(4, 28), (8, 20), (26, 4), (28, 8), (12, 24)], fill=c, outline=dark)
        d.polygon([(2, 30), (8, 22), (11, 25), (5, 31)], fill=(70, 40, 20, 255))
    elif kind == "umbrella":
        d.pieslice([4, 6, 28, 30], 180, 360, fill=c, outline=dark)
        d.line([(16, 18), (16, 28)], fill=dark, width=2)
        d.arc([12, 24, 20, 30], 0, 180, fill=dark, width=2)
    elif kind == "hourglass":
        d.polygon([(8, 4), (24, 4), (16, 16), (24, 28), (8, 28), (16, 16)], outline=c, fill=(40, 30, 20, 255))
        d.polygon([(11, 6), (21, 6), (16, 14)], fill=c)
        d.polygon([(12, 26), (20, 26), (16, 20)], fill=c)
        d.rectangle([6, 3, 26, 5], fill=dark)
        d.rectangle([6, 27, 26, 29], fill=dark)
    elif kind == "shard":
        d.polygon([(6, 8), (18, 3), (28, 14), (20, 29), (8, 24)], fill=c, outline=white)
        d.line([(10, 10), (22, 24)], fill=white)
        d.line([(12, 20), (24, 12)], fill=white)
    return T.from_pil(im)


def face_card(rng, skin, eye, mouth, size=128, eyes_open=False, smile=True, tone_split=False, alpha=True, bg="#000000"):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0) if alpha else tuple(int(v * 255) for v in T.hexc(bg)) + (255,))
    d = ImageDraw.Draw(im)
    sc = tuple(int(v * 255) for v in T.hexc(skin)) + (255,)
    ec = tuple(int(v * 255) for v in T.hexc(eye)) + (255,)
    mc = tuple(int(v * 255) for v in T.hexc(mouth)) + (255,)
    d.ellipse([16, 8, size - 16, size - 8], fill=sc)
    if tone_split:
        d.pieslice([16, 8, size - 16, size - 8], 90, 270, fill=(20, 20, 24, 255))
    ey = size * 0.42
    for ex in (size * 0.36, size * 0.64):
        if eyes_open:
            d.ellipse([ex - 8, ey - 6, ex + 8, ey + 6], fill=(250, 250, 250, 255))
            d.ellipse([ex - 3, ey - 3, ex + 3, ey + 3], fill=ec)
        else:
            d.arc([ex - 9, ey - 6, ex + 9, ey + 6], 10, 170, fill=ec, width=2)
    if tone_split:
        d.ellipse([size * 0.36 - 3, ey - 3, size * 0.36 + 3, ey + 3], fill=(250, 250, 250, 255))
        d.ellipse([size * 0.64 - 3, ey - 3, size * 0.64 + 3, ey + 3], fill=(20, 20, 24, 255))
    my = size * 0.68
    if smile:
        d.arc([size * 0.32, my - 14, size * 0.68, my + 10], 15, 165, fill=mc, width=3)
    else:
        d.line([(size * 0.4, my), (size * 0.6, my)], fill=mc, width=3)
    return T.from_pil(im)


def photo(rng, variant, size=128):
    """A family on a porch. Variants: 0 normal, 1 one scratched out, 2 no faces, 3 empty porch, 4 an extra figure."""
    from PIL import ImageDraw
    sepia_bg = "#d9c9a8"
    img = T.gradient_v((size, size), "#e8dcc0", "#b09a78")
    def fn(d, sz):
        w, h = sz
        d.rectangle([0, h * 0.62, w, h], fill=(120, 96, 70))       # porch floor
        for i in range(0, w, 12):
            d.line([(i, h * 0.62), (i, h)], fill=(100, 80, 58))
        d.rectangle([8, 10, 24, h * 0.62], fill=(160, 140, 110))    # post
        d.rectangle([w - 24, 10, w - 8, h * 0.62], fill=(160, 140, 110))
        d.rectangle([0, 0, w, 12], fill=(90, 70, 50))               # roof edge
        figures = [(40, 1.0), (62, 1.15), (84, 0.8)]
        if variant == 4:
            figures.append((104, 1.3))
        if variant != 3:
            for idx, (x, s) in enumerate(figures):
                top = h * 0.62 - 54 * s
                d.rectangle([x - 8 * s, top + 16 * s, x + 8 * s, h * 0.62], fill=(70, 60, 50))
                if variant == 2:
                    d.ellipse([x - 7 * s, top, x + 7 * s, top + 16 * s], fill=(200, 190, 170))
                else:
                    d.ellipse([x - 7 * s, top, x + 7 * s, top + 16 * s], fill=(210, 180, 150))
                    d.point([(x - 3 * s, top + 7 * s), (x + 3 * s, top + 7 * s)], fill=(40, 30, 30))
                if variant == 1 and idx == 1:
                    for _ in range(40):
                        x0 = x + rng.integers(-12, 12)
                        y0 = top + rng.integers(-4, 60)
                        d.line([(x0, y0), (x0 + rng.integers(-8, 8), y0 + rng.integers(-8, 8))], fill=(245, 240, 230), width=1)
                if variant == 4 and idx == 3:
                    d.ellipse([x - 7 * s, top, x + 7 * s, top + 16 * s], fill=(30, 30, 34))
    img = T.draw_on(img, fn)
    img = T.grain(img, rng, 0.06)
    img = T.vignette(img, 0.35)
    img = T.frame(img, "#f2ecd8", 4, inner="#8a7a60", inner_width=1)
    return T.quantize(img, 14)


def painting(rng, kind, size=128):
    if kind == "landscape":
        img = T.gradient_v((size, size), "#6d5a7a", "#d9a06a")
        hills = T.noise((size, size), 3, rng, octaves=3)
        yy = np.arange(size)[:, None] / size
        mask = (yy > 0.55 + (hills[0] - 0.5) * 0.25).astype(np.float32)
        img = T.mix(img, T.solid(size, "#2a2530"), mask)
        def fn(d, sz):
            d.line([(90, 118), (90, 60)], fill=(20, 18, 24), width=3)
            d.ellipse([70, 34, 110, 70], fill=(24, 20, 28))
            d.ellipse([28, 20, 44, 36], fill=(240, 230, 200))
        img = T.draw_on(img, fn)
    elif kind == "portrait":
        img = T.gradient_v((size, size), "#1c1418", "#3a2a2e")
        def fn(d, sz):
            d.ellipse([44, 24, 84, 78], fill=(214, 196, 176))
            d.polygon([(30, 128), (64, 78), (98, 128)], fill=(40, 30, 40))
            d.rectangle([56, 74, 72, 84], fill=(214, 196, 176))
        img = T.draw_on(img, fn)
    elif kind == "door":
        img = T.gradient_v((size, size), "#8aa3c9", "#c9c2a0")
        def fn(d, sz):
            d.rectangle([0, 84, 128, 128], fill=(96, 120, 70))
            d.rectangle([52, 40, 76, 96], fill=(70, 46, 30), outline=(40, 26, 16))
            d.rectangle([56, 44, 72, 92], fill=(12, 10, 14))
        img = T.draw_on(img, fn)
    elif kind == "house":
        img = T.gradient_v((size, size), "#0f1424", "#232a3e")
        def fn(d, sz):
            d.rectangle([0, 96, 128, 128], fill=(30, 40, 30))
            d.rectangle([34, 60, 94, 100], fill=(60, 50, 44))
            d.polygon([(28, 62), (64, 34), (100, 62)], fill=(40, 32, 28))
            d.rectangle([58, 78, 70, 100], fill=(20, 16, 18))
            d.rectangle([40, 68, 52, 80], fill=(255, 220, 130))
            d.rectangle([76, 68, 88, 80], fill=(24, 20, 22))
        img = T.draw_on(img, fn)
    else:
        img = T.solid(size, "#222")
    img = T.grain(img, rng, 0.03)
    img = T.frame(img, "#a67c2e", 5, inner="#5b4114", inner_width=2)
    return T.quantize(img, 14)


def sign(lines, bg, fg, size=(128, 64), kind="display", font_size=20, frame_color=None, plank=False, rng=None, levels=12, line_gap=2):
    base = T.solid(size, bg)
    if plank and rng is not None:
        base = plank_floor(rng, bg, bg, "#1a1008", n=3, size=size[0], vertical=False, levels=64)
        base = base[: size[1], : size[0]] if base.shape[0] >= size[1] else np.resize(base, (size[1], size[0], 3))
    img = T.text_block(size, lines, fg, base, kind=kind, font_size=font_size, line_gap=line_gap)
    if frame_color:
        img = T.frame(img, frame_color, 3)
    return T.quantize(img, levels, dither=0.2)


def bones_wall(rng, size=64, levels=12):
    """Stacked femurs with rows of skulls — an ossuary wall."""
    base = plaster(rng, "#3a3128", "#221c16", size, levels=64)
    def fn(d, sz):
        w, h = sz
        bone = (216, 205, 178)
        bone2 = (170, 158, 130)
        dark = (60, 50, 40)
        y = 0
        row = 0
        while y < h:
            if row % 3 == 2:
                # skull row
                for x in range(-6, w + 8, 16):
                    d.ellipse([x, y + 1, x + 12, y + 11], fill=bone, outline=bone2)
                    d.ellipse([x + 2, y + 4, x + 5, y + 7], fill=dark)
                    d.ellipse([x + 7, y + 4, x + 10, y + 7], fill=dark)
                    d.rectangle([x + 4, y + 9, x + 8, y + 11], fill=bone2)
                y += 12
            else:
                # bone ends row: circles pairs
                for x in range(-4, w + 8, 10):
                    r = rng.integers(3, 5)
                    d.ellipse([x, y, x + 2 * r, y + 2 * r], fill=bone, outline=bone2)
                    d.ellipse([x + r - 1, y + r - 1, x + r + 1, y + r + 1], fill=bone2)
                y += 10
            row += 1
    img = T.draw_on(base, fn)
    return T.quantize(T.grain(img, rng, 0.04), levels)


def flesh(rng, c1, c2, vein, size=64, levels=12):
    r = T.ridged(size, 4, rng, octaves=4)
    f1, f2, _ = T.worley(size, 10, rng)
    veins = T.clamp01(1.0 - (f2 - f1) * 12.0)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), r)
    base = T.mix(base, T.solid(size, vein), veins * 0.6)
    base = T.shade(base, T.noise(size, 3, rng), 0.2)
    return T.quantize(T.grain(base, rng, 0.04), levels)


def water(rng, c1, c2, size=64, levels=12):
    r = T.ridged(size, 4, rng, octaves=3)
    n = T.noise(size, 3, rng, octaves=2)
    base = T.mix(T.solid(size, c1), T.solid(size, c2), T.clamp01(r * 0.8 + n * 0.3))
    return T.quantize(base, levels, dither=0.4)


def door_panel(rng, c1, c2, frame_c, size=(64, 128), knob="#c9a227", levels=12):
    w, h = size
    base = plank_floor(rng, c1, c2, "#1a1008", n=4, size=w, vertical=True, levels=64, knots=False)
    base = np.concatenate([base, base], axis=0)[:h]
    def fn(d, sz):
        fc = tuple(int(v * 255) for v in T.hexc(frame_c))
        d.rectangle([0, 0, w - 1, h - 1], outline=fc, width=3)
        d.rectangle([10, 10, w - 11, h // 2 - 6], outline=fc, width=2)
        d.rectangle([10, h // 2 + 6, w - 11, h - 11], outline=fc, width=2)
        kc = tuple(int(v * 255) for v in T.hexc(knob))
        d.ellipse([w - 20, h // 2 - 3, w - 14, h // 2 + 3], fill=kc)
    return T.quantize(T.draw_on(base, fn), levels)


def book_spines(rng, size=64, levels=12):
    cols = ["#5a2a2a", "#2a3a5a", "#3a4a2a", "#6a5a2a", "#4a2a5a", "#2a2a2a", "#7a3a2a", "#3a5a5a"]
    img = T.solid(size, "#1a1410")
    def fn(d, sz):
        w, h = sz
        x = 0
        while x < w:
            bw = int(rng.integers(4, 10))
            c = tuple(int(v * 255) for v in T.hexc(cols[int(rng.integers(0, len(cols)))]))
            top = int(rng.integers(2, 10))
            d.rectangle([x, top, x + bw - 2, h], fill=c)
            gold = (200, 170, 90)
            for yy in range(top + 6, h - 6, 12):
                d.line([(x + 1, yy), (x + bw - 3, yy)], fill=gold)
            x += bw
    return T.quantize(T.draw_on(img, fn), levels)


def tv_static(rng, size=64, face=False, levels=8):
    n = rng.random((size, size)).astype(np.float32)
    img = np.repeat(n[..., None], 3, axis=-1) * 0.8 + 0.1
    if face:
        def fn(d, sz):
            d.ellipse([16, 10, 48, 54], fill=(30, 30, 30))
            d.ellipse([22, 24, 28, 30], fill=(240, 240, 240))
            d.ellipse([36, 24, 42, 30], fill=(240, 240, 240))
            d.rectangle([24, 40, 40, 44], fill=(240, 240, 240))
        img = T.mix(img, T.draw_on(img, fn), 0.75)
    return T.quantize(img, levels, dither=0.0)


def window(rng, night=True, size=64, levels=12):
    if night:
        img = T.gradient_v((size, size), "#0d1526", "#1a2540")
        stars = T.scatter_blobs(size, rng, 8, 0.5, 1.2, soft=False)
        img = T.mix(img, T.solid(size, "#e8e8ff"), stars)
    else:
        img = T.gradient_v((size, size), "#ffe9a8", "#d9a44a")
    def fn(d, sz):
        w, h = sz
        fc = (60, 48, 36) if night else (90, 70, 50)
        d.rectangle([0, 0, w - 1, h - 1], outline=fc, width=4)
        d.line([(w // 2, 0), (w // 2, h)], fill=fc, width=3)
        d.line([(0, h // 2), (w, h // 2)], fill=fc, width=3)
        if night:
            d.line([(6, 10), (14, 22)], fill=(80, 100, 140), width=1)
    return T.quantize(T.draw_on(img, fn), levels)


def gravestone(rng, name, size=(64, 96), levels=12):
    base = plaster(rng, "#6a6a66", "#4a4a48", size[0], levels=64)
    base = np.concatenate([base, base], axis=0)[: size[1]]
    lines = ["†", name, "sleeps"] if name else ["†", "", ""]
    img = T.text_block(size, lines, "#2a2a28", base, kind="display", font_size=13, line_gap=4)
    return T.quantize(T.grain(img, rng, 0.04), levels)


def clock_face(rng, size=128, levels=12):
    img = T.solid(size, "#efe6c8")
    def fn(d, sz):
        w, h = sz
        cx, cy, r = w / 2, h / 2, w / 2 - 4
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(40, 30, 20), width=3)
        for i in range(12):
            a = i / 12 * 6.283
            x0, y0 = cx + np.cos(a) * (r - 4), cy + np.sin(a) * (r - 4)
            x1, y1 = cx + np.cos(a) * (r - 12), cy + np.sin(a) * (r - 12)
            d.line([(x0, y0), (x1, y1)], fill=(40, 30, 20), width=3 if i % 3 == 0 else 1)
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(40, 30, 20))
    return T.quantize(T.draw_on(img, fn), levels)


def gear(rng, size=64, teeth=12, color="#b58a3c"):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = tuple(int(v * 255) for v in T.hexc(color)) + (255,)
    dk = tuple(int(v * 140) for v in T.hexc(color)) + (255,)
    cx = cy = size / 2
    r = size * 0.36
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c, outline=dk)
    for i in range(teeth):
        a = i / teeth * 6.283
        x, y = cx + np.cos(a) * (r + 3), cy + np.sin(a) * (r + 3)
        d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=c, outline=dk)
    d.ellipse([cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35], fill=(20, 16, 14, 255))
    return T.from_pil(im)


def rune_ring(rng, size=128, color="#d9b24c", bg="#1a1533", alpha=True):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0) if alpha else tuple(int(v * 255) for v in T.hexc(bg)) + (255,))
    d = ImageDraw.Draw(im)
    c = tuple(int(v * 255) for v in T.hexc(color)) + (255,)
    cx = cy = size / 2
    for r in (size * 0.47, size * 0.36):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=2)
    rr = size * 0.415
    for i in range(24):
        a = i / 24 * 6.283
        x, y = cx + np.cos(a) * rr, cy + np.sin(a) * rr
        for _ in range(3):
            dx, dy = rng.integers(-4, 5), rng.integers(-4, 5)
            d.line([(x, y), (x + dx, y + dy)], fill=c, width=1)
    d.polygon([(cx, cy - 20), (cx + 18, cy), (cx, cy + 20), (cx - 18, cy)], outline=c)
    return T.from_pil(im)


# --------------------------------------------------------------------------
# catalogue
# --------------------------------------------------------------------------

def _chain(rng, size=64):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = (110, 108, 112, 255)
    dk = (50, 48, 52, 255)
    for y in range(0, size, 16):
        d.ellipse([size / 2 - 6, y, size / 2 + 6, y + 18], outline=c, width=3)
        d.ellipse([size / 2 - 3, y + 9, size / 2 + 3, y + 25], outline=dk, width=3)
    return T.from_pil(im)


def _bars(rng, size=64):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(4, size, 16):
        d.rectangle([x, 0, x + 4, size], fill=(50, 50, 56, 255))
        d.line([(x + 1, 0), (x + 1, size)], fill=(110, 110, 118, 255))
    d.rectangle([0, 28, size, 34], fill=(60, 60, 66, 255))
    return T.from_pil(im)


def _grate(rng, size=64):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(0, size, 8):
        d.rectangle([x, 0, x + 3, size], fill=(70, 66, 60, 255))
    for y in range(0, size, 8):
        d.rectangle([0, y, size, y + 3], fill=(80, 76, 70, 255))
    return T.from_pil(im)


def _fern(rng, size=64):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    g = (78, 128, 62, 255)
    g2 = (46, 94, 58, 255)
    for k in range(5):
        a = -1.3 + k * 0.65
        x0, y0 = size / 2, size - 2
        x1, y1 = x0 + np.cos(a - 1.57) * 44, y0 + np.sin(a - 1.57) * 44
        d.line([(x0, y0), (x1, y1)], fill=g2, width=2)
        for t in np.linspace(0.15, 0.95, 8):
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            L = 7 * (1 - t) + 2
            for s in (-1, 1):
                d.line([(px, py), (px + np.cos(a - 1.57 + s * 1.1) * L, py + np.sin(a - 1.57 + s * 1.1) * L)], fill=g, width=2)
    return T.from_pil(im)


def _eye(rng, size=64):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(4, 32), (32, 8), (60, 32), (32, 56)], fill=(240, 236, 220, 255))
    d.ellipse([18, 18, 46, 46], fill=(120, 20, 30, 255))
    d.ellipse([26, 26, 38, 38], fill=(10, 4, 6, 255))
    d.ellipse([29, 24, 33, 28], fill=(255, 255, 255, 255))
    return T.from_pil(im)


def _mushroom_cap(rng, base, spot, size=64):
    img = plaster(rng, base, base, size, levels=64)
    spots = T.scatter_blobs(size, rng, 9, 2, 5, soft=False)
    img = T.mix(img, T.solid(size, spot), spots)
    return T.quantize(T.grain(img, rng, 0.03), 12)


def _static_field(rng, size=64):
    return tv_static(rng, size, face=False)


def _map_scrap(rng, size=128):
    img = plaster(rng, "#d9c9a0", "#bfae86", size, stains=0.6, stain_color="#8a7050", levels=64)
    def fn(d, sz):
        ink = (60, 40, 30)
        pts = [(20, 100), (40, 70), (70, 80), (90, 40), (110, 50)]
        d.line(pts, fill=ink, width=2)
        d.rectangle([64, 56, 76, 68], outline=ink)
        d.line([(86, 34), (94, 46)], fill=(140, 30, 30), width=2)
        d.line([(94, 34), (86, 46)], fill=(140, 30, 30), width=2)
        d.ellipse([18, 96, 24, 104], fill=ink)
    img = T.draw_on(img, fn)
    img = T.text_block((size, size), ["", "", "", "", "", "you are not here"], "#3a2a20", img, kind="body", font_size=14, valign="middle")
    return T.quantize(img, 12)


def _calendar(rng, size=128):
    img = T.solid(size, "#f0ead8")
    img = T.text_block((size, size), ["OCTOBER"], "#3a2a20", img, kind="display", font_size=16, valign="top", margin=6)
    def fn(d, sz):
        w, h = sz
        for r in range(5):
            for c in range(7):
                x, y = 8 + c * 16, 34 + r * 17
                d.rectangle([x, y, x + 14, y + 15], outline=(120, 110, 100))
        d.ellipse([8 + 3 * 16 - 2, 34 + 2 * 17 - 2, 8 + 3 * 16 + 16, 34 + 2 * 17 + 17], outline=(180, 30, 30), width=2)
        d.rectangle([0, 0, w - 1, h - 1], outline=(90, 70, 50), width=3)
    return T.quantize(T.draw_on(img, fn), 12)


def _keypad(rng, size=64):
    img = T.solid(size, "#3a3a40")
    def fn(d, sz):
        for i in range(12):
            x, y = 8 + (i % 3) * 18, 6 + (i // 3) * 14
            d.rectangle([x, y, x + 12, y + 10], fill=(200, 200, 190), outline=(20, 20, 20))
    return T.quantize(T.draw_on(img, fn), 12)


def _mirror_surface(rng, size=64):
    img = T.gradient_v((size, size), "#9fb0b8", "#6f7f88")
    n = T.noise(size, 2, rng, octaves=2)
    img = T.shade(img, n, 0.12)
    return T.quantize(img, 16, dither=0.2)


def _coat_black(rng, size=64):
    return plaster(rng, "#101014", "#1c1c22", size, levels=8)


def _crest(rng, kind, size=64):
    from PIL import ImageDraw
    img = T.solid(size, "#6e1a2a" if kind == "key" else "#1a2a4a")
    def fn(d, sz):
        gold = (200, 160, 60)
        d.rectangle([2, 2, size - 3, size - 3], outline=gold, width=2)
        if kind == "key":
            d.ellipse([22, 10, 42, 30], outline=gold, width=3)
            d.rectangle([30, 28, 34, 54], fill=gold)
            d.rectangle([34, 44, 42, 48], fill=gold)
            d.rectangle([34, 50, 40, 54], fill=gold)
        else:
            d.polygon([(8, 32), (32, 14), (56, 32), (32, 50)], outline=gold, width=2)
            d.ellipse([24, 24, 40, 40], fill=gold)
            d.ellipse([29, 29, 35, 35], fill=(20, 20, 30))
    return T.quantize(T.draw_on(img, fn), 12)


def _tapestry(rng, size=(64, 128)):
    w, h = size
    img = T.gradient_v(size, "#2b3a2b", "#1a2a1a")
    n = T.noise(size, 3, rng, octaves=3)
    img = T.shade(img, n, 0.2)
    def fn(d, sz):
        gold = (190, 150, 60)
        for x in (12, 34, 52):
            d.line([(x, 118), (x, 60)], fill=(60, 40, 30), width=3)
            d.ellipse([x - 10, 40, x + 10, 70], fill=(40, 70, 40))
        # a stag silhouette
        d.rectangle([24, 96, 44, 108], fill=(20, 18, 14))
        d.rectangle([40, 84, 46, 98], fill=(20, 18, 14))
        d.line([(44, 84), (38, 72)], fill=(20, 18, 14), width=2)
        d.line([(44, 84), (50, 72)], fill=(20, 18, 14), width=2)
        d.rectangle([2, 2, w - 3, h - 3], outline=gold, width=2)
        for y in range(8, h - 8, 12):
            d.point([(5, y), (w - 6, y)], fill=gold)
    return T.quantize(T.grain(T.draw_on(img, fn), rng, 0.04), 12)


def _stone_rune(rng, size=(64, 128)):
    w, h = size
    img = plaster(rng, "#5a5e66", "#3f434b", w, levels=64)
    img = np.concatenate([img, img], axis=0)[:h]
    def fn(d, sz):
        c = (120, 190, 170)
        for y in range(16, h - 20, 18):
            x = w // 2 + int(rng.integers(-8, 9))
            pts = [(x, y), (x + int(rng.integers(-8, 9)), y + 10), (x + int(rng.integers(-8, 9)), y + 4)]
            d.line(pts, fill=c, width=2)
    return T.quantize(T.grain(T.draw_on(img, fn), rng, 0.05), 12)


def _stars(rng, size=128):
    img = T.solid(size, "#05040c")
    for _ in range(90):
        y, x = int(rng.random() * size), int(rng.random() * size)
        v = rng.uniform(0.4, 1.0)
        img[y, x] = [v, v, v * 0.95]
    return img


def _dog_fur(rng, size=64):
    n = T.noise(size, 8, rng, octaves=4, cells_y=3)
    img = T.mix(T.solid(size, "#8a7358"), T.solid(size, "#5a4a36"), n)
    return T.quantize(T.grain(img, rng, 0.05), 10)


def _ash(rng, size=64):
    n = T.noise(size, 6, rng, octaves=4)
    img = T.mix(T.solid(size, "#1a1214"), T.solid(size, "#2e2226"), n)
    embers = T.scatter_blobs(size, rng, 14, 0.6, 1.5, soft=False)
    img = T.mix(img, T.solid(size, "#ff5a1f"), embers)
    return T.quantize(img, 10)


def _lava(rng, size=64):
    r = T.ridged(size, 3, rng, octaves=4)
    img = T.palette(r, [(0, "#1a0508"), (0.5, "#7a1010"), (0.8, "#ff5a1f"), (1.0, "#ffd07a")])
    return T.quantize(img, 12)


def _sofa_plaid(rng, size=64):
    img = T.solid(size, "#6b4a32")
    s1 = T.stripes_v(size, 16, 0.5)
    s2 = T.stripes_v(size, 16, 0.5).T
    img = T.shade(img, s1, 0.12)
    img = T.shade(img, s2, 0.12)
    return T.quantize(T.grain(img, rng, 0.04), 10)


def _note(rng, lines, size=128, ink="#2a2030"):
    img = plaster(rng, "#efe6cf", "#e0d4b6", size, stains=0.3, stain_color="#a08a60", levels=64)
    img = T.text_block((size, size), lines, ink, img, kind="body", font_size=15, align="left", margin=8, valign="top", line_gap=1)
    return T.quantize(img, 12, dither=0.2)


def _chalkboard(rng, lines, size=(128, 96)):
    img = plaster(rng, "#1e2a24", "#16201b", size[0], levels=64)[: size[1]]
    img = T.text_block(size, lines, "#e8e4d4", img, kind="body", font_size=16, line_gap=2)
    return T.quantize(T.frame(img, "#6b4a2e", 4), 12, dither=0.2)


CATALOG = {}


def reg(name, fn, surface="stone", levels=None, size=None, **opts):
    CATALOG[name] = (fn, dict(surface=surface, **opts))


def build_catalog():
    w, hs, f, c, tv, ca, se, ct, fu, ci, of, ck, nx, hw = (P["waking"], P["house"], P["forest"], P["city"], P["tavern"], P["castle"], P["sea"], P["catacombs"], P["furnace"], P["cistern"], P["offices"], P["clocktower"], P["nexus"], P["hallway"])

    # common
    reg("common/checker", lambda r: T.quantize(T.mix(T.solid(64, "#ff00ff"), T.solid(64, "#000000"), ((np.arange(64)[:, None] // 8 + np.arange(64)[None, :] // 8) % 2).astype(np.float32)), 4))
    reg("common/void", lambda r: T.solid(64, "#000000"))
    reg("common/white", lambda r: T.solid(64, "#ffffff"))
    reg("common/noise_soft", lambda r: T.quantize(np.repeat(T.noise(64, 4, r)[..., None], 3, -1) * 0.5 + 0.25, 12))
    reg("common/static", _static_field, surface="metal")
    reg("common/stars", _stars)

    # stone
    reg("stone/cobble_grey", lambda r: cobbles(r, "#7a7a80", "#55555c", "#2a2a2e"), surface="stone")
    reg("stone/cobble_mossy", lambda r: cobbles(r, "#6a6e66", "#4a4e48", "#22261f", moss=f["moss"]), surface="stone")
    reg("stone/cobble_city", lambda r: cobbles(r, c["bone2"], "#7a7468", "#2a2a30", npts=26), surface="stone")
    reg("stone/blocks_grey", lambda r: stone_blocks(r, "#6e6f74", "#55565c", "#2a2a2e"), surface="stone")
    reg("stone/blocks_nexus", lambda r: stone_blocks(r, nx["stone"], nx["stone2"], "#15132a", rows=4, cols=2), surface="stone")
    reg("stone/blocks_castle", lambda r: stone_blocks(r, ca["stone"], ca["stone2"], "#25272e", rows=3, cols=2, cracks=1), surface="stone")
    reg("stone/blocks_city", lambda r: stone_blocks(r, c["bone"], c["bone2"], "#4a4640", rows=4, cols=3, cracks=3), surface="stone")
    reg("stone/blocks_dark", lambda r: stone_blocks(r, "#3a352e", "#2a261f", "#0e0c0a", rows=5, cols=3, cracks=2), surface="stone")
    reg("stone/blocks_furnace", lambda r: stone_blocks(r, "#1a0d10", "#2a1418", fu["ember"], rows=4, cols=3, cracks=0), surface="stone")
    reg("stone/blocks_sea", lambda r: stone_blocks(r, se["pink"], "#e0a0bc", se["lilac"], rows=3, cols=2, cracks=0, grain=0.02), surface="stone")
    reg("stone/blocks_clocktower", lambda r: stone_blocks(r, "#5a4a3a", "#463a2c", "#1e1812", rows=4, cols=3, cracks=1), surface="stone")
    reg("stone/flagstone", lambda r: tile_floor(r, "#5e5f66", "#4a4b52", "#26262c", n=2, gloss=0.05), surface="stone")
    reg("stone/flagstone_castle", lambda r: tile_floor(r, ca["stone"], ca["stone2"], "#1e2026", n=2, gloss=0.05), surface="stone")
    reg("stone/marble_white", lambda r: T.quantize(T.shade(T.mix(T.solid(64, "#e8e4dc"), T.solid(64, "#b8b0a8"), T.ridged(64, 3, r, octaves=4)), T.noise(64, 2, r), 0.1), 12), surface="tile")
    reg("stone/marble_black", lambda r: T.quantize(T.mix(T.solid(64, "#15141a"), T.solid(64, "#5a5560"), T.clamp01(T.ridged(64, 3, r, octaves=4) ** 3)), 12), surface="tile")
    reg("stone/smooth_grey", lambda r: plaster(r, "#6e6e74", "#5a5a60"), surface="stone")
    reg("stone/smooth_pale", lambda r: plaster(r, "#c9c2b0", "#a89f8c"), surface="stone")
    reg("stone/statue", lambda r: plaster(r, "#9a9aa2", "#6e6e78", stains=0.4, stain_color="#3a4a40"), surface="stone")

    # ground
    reg("ground/gravel", lambda r: cobbles(r, "#8a8480", "#5a5650", "#3a3630", npts=60), surface="gravel")
    reg("ground/dirt", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#4a3a2c"), T.solid(64, "#2e2418"), T.noise(64, 6, r, octaves=4)), r, 0.06), 10), surface="grass")
    reg("ground/mud", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#3a2e22"), T.solid(64, "#221a12"), T.ridged(64, 4, r, octaves=3)), r, 0.04), 10), surface="water")
    reg("ground/sand", lambda r: T.quantize(T.grain(T.mix(T.solid(64, se["cream"]), T.solid(64, "#e2c9a6"), T.noise(64, 8, r, octaves=3)), r, 0.05), 10), surface="sand")
    reg("ground/ash", _ash, surface="sand")
    reg("ground/lava", _lava, surface="flesh")
    reg("ground/snow", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#eef0f5"), T.solid(64, "#c9d0dc"), T.noise(64, 5, r, octaves=3)), r, 0.03), 10), surface="snow")

    # nature
    reg("nature/grass_dark", lambda r: grass(r, "#1f3a26", "#152a1c", "#3d6b3a"), surface="grass")
    reg("nature/grass_moss", lambda r: grass(r, f["moss2"], "#223a1a", f["moss"], blades=100), surface="grass")
    reg("nature/grass_pale", lambda r: grass(r, "#7a7a4a", "#5a5a36", "#a0a060", blades=120), surface="grass")
    reg("nature/bark_oak", lambda r: bark(r, f["bark"], f["bark2"]), surface="wood")
    reg("nature/bark_dead", lambda r: bark(r, "#9a948a", "#5a5650", ridges=10), surface="wood")
    reg("nature/bark_pine", lambda r: bark(r, "#5a3a28", "#2e1c12", ridges=12), surface="wood")
    reg("nature/leaves_dark", lambda r: leaves_card(r, ["#1e4a30", "#2e5e3a", "#3f7a45", "#173a26"]), alpha=True)
    reg("nature/leaves_purple", lambda r: leaves_card(r, ["#3a1e4a", "#5a2e6e", "#7a3f8a", "#2a1436"]), alpha=True)
    reg("nature/leaves_pale", lambda r: leaves_card(r, ["#c9c2b0", "#a89f8c", "#e0dccc"], n=70), alpha=True)
    reg("nature/leaves_autumn", lambda r: leaves_card(r, ["#8a3a1a", "#b5561f", "#d9832a", "#5a2a12"]), alpha=True)
    # the King's Dream: a fever-bright garden
    reg("nature/hedge", lambda r: hedge(r, ["#1f4a22", "#3f8a3a", "#5aa848", "#2e6a2e", "#7cc258"]), surface="grass")
    reg("nature/hedge_red", lambda r: hedge(r, ["#4a1a22", "#8a2a3a", "#a83848", "#6a1e2e", "#c25058"]), surface="grass")
    reg("nature/grass_dream", lambda r: grass(r, "#8fc04a", "#6a9a36", "#d8f070", blades=160), surface="grass")
    reg("ground/pebbles", lambda r: cobbles(r, "#b8a890", "#8a7c6a", "#5a5048", npts=70), surface="gravel")
    reg("ground/red_dream", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#a02a2a"), T.solid(64, "#6a1418"), T.noise(64, 6, r, octaves=4)), r, 0.05), 10), surface="sand")
    reg("nature/fern", _fern, alpha=True)
    reg("nature/mushroom_glow", lambda r: _mushroom_cap(r, "#4a2a6e", f["glow"]))
    reg("nature/mushroom_red", lambda r: _mushroom_cap(r, "#8a1a1a", "#f0e6d0"))
    reg("nature/mushroom_pale", lambda r: _mushroom_cap(r, "#c9c2b0", "#8a8478"))
    reg("nature/water_dark", lambda r: water(r, "#0b1a1c", "#2a5a5e"), surface="water")
    reg("nature/water_sea", lambda r: water(r, "#b7a6f0", "#fff3dd"), surface="water")
    reg("nature/water_cistern", lambda r: water(r, ci["deep"], ci["water"]), surface="water")
    reg("nature/water_blood", lambda r: water(r, "#2a0508", "#8b0f1e"), surface="water")
    reg("nature/roots", lambda r: T.quantize(T.mix(T.solid(64, "#2a1a10"), T.solid(64, "#5a4030"), T.ridged(64, 5, r, octaves=3)), 10), surface="wood")
    reg("nature/stone_rune", _stone_rune)

    # sky (w x h = 256 x 128)
    reg("sky/night", lambda r: sky("#05040c", "#0f1424", "#2a2a44", stars=140, rng=r))
    reg("sky/forest", lambda r: sky("#061a18", "#0f2a25", "#3a6a5e", stars=40, rng=r))
    reg("sky/city", lambda r: sky("#2a2f3a", "#4a5060", "#8a8a80"))
    reg("sky/sea", lambda r: sky(se["deep"], se["lilac"], se["pink"], stars=60, rng=r, bands=0.02))
    reg("sky/furnace", lambda r: sky("#000000", "#2a0508", "#8b0f1e"))
    reg("sky/house", lambda r: sky("#050812", "#0d1526", "#1f2a40", stars=200, rng=r))
    reg("sky/castle", lambda r: sky("#0c0a18", "#2a1f3a", "#5a4a6a", stars=80, rng=r))
    reg("sky/nexus", lambda r: sky("#0b0a18", nx["indigo"], "#2a2450"))
    reg("sky/static", lambda r: sky("#3a3a3a", "#6a6a6a", "#9a9a9a"))
    reg("sky/cistern", lambda r: sky("#0a2a2c", "#12484d", "#2f8f95"))
    reg("sky/dawn", lambda r: sky("#2a1a3a", "#a04a5a", "#f0a060", stars=20, rng=r))
    reg("sky/kings_dream", lambda r: sky("#4a2a58", "#f0a0b8", "#fff0c0", stars=0, bands=0.04))

    # brick / wood
    reg("brick/red", lambda r: stone_blocks(r, "#7a3a2a", "#5e2c22", "#3a3028", rows=8, cols=4, cracks=1), surface="stone")
    reg("brick/dark", lambda r: stone_blocks(r, "#3a2a26", "#2a1e1c", "#1a1614", rows=8, cols=4, cracks=1), surface="stone")
    reg("brick/pale", lambda r: stone_blocks(r, "#a09080", "#8a7a6a", "#5a5048", rows=8, cols=4, cracks=1), surface="stone")
    reg("wood/planks_warm", lambda r: plank_floor(r, "#8a5a32", "#6b4424", "#2a1a0e"), surface="wood")
    reg("wood/planks_dark", lambda r: plank_floor(r, "#4a3020", "#382416", "#160e08"), surface="wood")
    reg("wood/planks_grey", lambda r: plank_floor(r, "#7a766e", "#5a5650", "#2a2824"), surface="wood")
    reg("wood/planks_white", lambda r: plank_floor(r, "#d9d2c2", "#bdb5a4", "#8a8478", grain_amt=0.12), surface="wood")
    reg("wood/planks_house", lambda r: plank_floor(r, "#6b4a30", "#523822", "#1e1408", n=8), surface="wood")
    reg("wood/planks_wall", lambda r: plank_floor(r, "#5a3a22", "#46301c", "#1a1008", n=5, vertical=True), surface="wood")
    reg("wood/thatch", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#8a6a30"), T.solid(64, "#4a3a18"), T.ridged(64, 12, r, octaves=3, cells_y=2)), r, 0.05), 10), surface="grass")
    reg("wood/crate", lambda r: T.frame(plank_floor(r, "#8a6a40", "#6b502c", "#2a1a0e", n=4), "#5a4020", 3), surface="wood")
    reg("wood/door", lambda r: door_panel(r, "#6b4a2e", "#553a22", "#3a2814"), surface="wood")
    reg("wood/door_dark", lambda r: door_panel(r, "#3a2416", "#2c1a0e", "#1a1008"), surface="wood")
    reg("wood/door_white", lambda r: door_panel(r, "#e8e2d4", "#d0c8b8", "#a8a090", knob="#8a8478"), surface="wood")
    reg("wood/door_red", lambda r: door_panel(r, "#7a1f1f", "#5a1414", "#2a0a0a"), surface="wood")
    reg("wood/door_iron", lambda r: door_panel(r, "#3a3a40", "#2a2a30", "#6a6a70", knob="#c9a227"), surface="metal")
    reg("wood/book_spines", book_spines, surface="wood")
    reg("wood/bar_counter", lambda r: plank_floor(r, "#3d2415", "#2c1a0e", "#100804", n=3, grain_amt=0.2), surface="wood")
    reg("wood/table", lambda r: plank_floor(r, "#6b4a2e", "#553a22", "#2a1a0e", n=3, grain_amt=0.2), surface="wood")

    # walls
    reg("wall/plaster_cream", lambda r: plaster(r, w["wall"], w["wall2"], stains=0.25), surface="stone")
    reg("wall/plaster_white", lambda r: plaster(r, "#e6e2d6", "#d0cbbd", stains=0.2, stain_color="#8a8070"), surface="stone")
    reg("wall/plaster_yellow", lambda r: plaster(r, of["yellow"], of["yellow2"], stains=0.35, stain_color="#8a7a30"), surface="stone")
    reg("wall/plaster_green", lambda r: plaster(r, "#8aa08a", "#6e846e", stains=0.4, stain_color="#3a4a3a"), surface="stone")
    reg("wall/plaster_tavern", lambda r: plaster(r, tv["plaster"], "#a89068", stains=0.5, stain_color="#4a3020"), surface="stone")
    reg("wall/plaster_house", lambda r: plaster(r, hs["wall"], "#7a7458", stains=0.5, stain_color="#3a3020"), surface="stone")
    reg("wall/concrete", lambda r: plaster(r, "#6a6a6e", "#54545a", stains=0.6, stain_color="#3a3a40"), surface="stone")
    reg("wall/concrete_dark", lambda r: plaster(r, "#3a3a40", "#2a2a30", stains=0.6, stain_color="#1a1a20"), surface="stone")
    reg("wall/hallway_black", lambda r: plaster(r, hw["black"], "#2a2a30", levels=6), surface="stone")
    reg("wall/hallway_grey", lambda r: plaster(r, hw["grey"], "#2e2e34", levels=6), surface="stone")
    reg("wall/wallpaper_damask", lambda r: damask(r, hs["paper"], hs["paper2"]), surface="carpet")
    reg("wall/wallpaper_damask_red", lambda r: damask(r, "#5a1e28", "#3e1420"), surface="carpet")
    reg("wall/wallpaper_floral", lambda r: floral(r, "#d9cbb0", hs["floral"], "#8a4a5a"), surface="carpet")
    reg("wall/wallpaper_stripe", lambda r: T.quantize(T.shade(plaster(r, "#9fb0b8", "#8a9aa2", levels=64), T.stripes_v(64, 8, 0.5), 0.1), 10), surface="carpet")
    reg("wall/wallpaper_brown", lambda r: damask(r, "#8a6a4a", "#6a4a30", stripes=False), surface="carpet")
    reg("wall/wallpaper_office", lambda r: T.quantize(T.shade(plaster(r, of["yellow"], of["yellow2"], stains=0.3, stain_color="#7a6a28", levels=64), T.stripes_v(64, 16, 0.5), 0.05), 10), surface="carpet")
    reg("wall/tile_bath", lambda r: tile_floor(r, w["teal"], "#5f8a84", "#e0e0d8", n=4, gloss=0.25), surface="tile")
    reg("wall/tile_white", lambda r: tile_floor(r, ci["tile"], ci["tile2"], ci["grout"], n=4, gloss=0.3), surface="tile")
    reg("wall/tile_cyan", lambda r: tile_floor(r, ci["cyan"], "#7ab5b0", ci["grout"], n=4, gloss=0.3), surface="tile")
    reg("wall/tile_checker", lambda r: tile_floor(r, "#e8e6e0", "#d8d6d0", "#6a6a66", n=4, gloss=0.15, checker="#1a1a1e"), surface="tile")
    reg("wall/tile_terracotta", lambda r: tile_floor(r, "#a8573a", "#8a4530", "#3a2a20", n=4, gloss=0.1), surface="tile")
    reg("wall/tile_black", lambda r: tile_floor(r, "#1e1e24", "#16161a", "#3a3a40", n=4, gloss=0.35), surface="tile")
    reg("wall/ceiling_tile", lambda r: tile_floor(r, of["ceiling"], "#d4cdb8", "#8a8478", n=2, gloss=0.02), surface="tile")
    reg("wall/ceiling_plaster", lambda r: plaster(r, "#d8d2c4", "#c4bdae", stains=0.3, stain_color="#8a7a5a"), surface="stone")
    reg("wall/carpet_red", lambda r: carpet(r, "#6e1a2a", "#5a1420", "#c9a227"), surface="carpet")
    reg("wall/carpet_office", lambda r: carpet(r, of["carpet"], of["carpet2"], "#3a4048", pattern=False), surface="carpet")
    reg("wall/carpet_house", lambda r: carpet(r, hs["carpet"], "#8a7c5c", "#6b4a32", pattern=False), surface="carpet")
    reg("wall/carpet_apartment", lambda r: carpet(r, "#6d7a5a", "#5a6648", "#3a4030", pattern=False), surface="carpet")
    reg("wall/carpet_tavern", lambda r: carpet(r, "#7a1f1f", "#5a1414", "#d9903a"), surface="carpet")
    reg("wall/paper", lambda r: plaster(r, "#efe6cf", "#e0d4b6", levels=8), surface="carpet")

    # metal / fabric
    reg("metal/iron", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#3a3a40"), T.solid(64, "#26262c"), T.noise(64, 6, r, octaves=3)), r, 0.05), 8), surface="metal")
    reg("metal/rust", lambda r: T.quantize(T.grain(T.mix(T.solid(64, "#4a3a34"), T.solid(64, c["rust"]), T.clamp01((T.noise(64, 4, r, octaves=4) - 0.4) * 2.5)), r, 0.05), 10), surface="metal")
    reg("metal/brass", lambda r: T.quantize(T.grain(T.mix(T.solid(64, ck["brass"]), T.solid(64, ck["brass2"]), T.noise(64, 5, r, octaves=3)), r, 0.04), 10), surface="metal")
    reg("metal/plate", lambda r: T.frame(T.quantize(T.mix(T.solid(64, "#5a5a62"), T.solid(64, "#46464e"), T.noise(64, 5, r, octaves=3)), 10), "#2e2e34", 2), surface="metal")
    reg("metal/chain", _chain, alpha=True)
    reg("metal/bars", _bars, alpha=True)
    reg("metal/grate", _grate, alpha=True)
    reg("metal/gear", lambda r: gear(r), alpha=True)
    reg("metal/clock_face", clock_face)
    reg("fabric/cloth_red", lambda r: plaster(r, "#7a1f1f", "#5a1414", levels=10), surface="carpet")
    reg("fabric/velvet", lambda r: plaster(r, ca["velvet"], ca["velvet2"], levels=10), surface="carpet")
    reg("fabric/curtain", lambda r: T.quantize(T.shade(plaster(r, "#3a1a2a", "#2a1220", levels=64), T.stripes_v(64, 6, 0.5), 0.2), 10), surface="carpet")
    reg("fabric/sheet", lambda r: T.quantize(T.shade(plaster(r, "#e8e4dc", "#d0ccc4", levels=64), T.noise(64, 2, r), 0.1), 10), surface="carpet")
    reg("fabric/mattress", lambda r: T.quantize(T.shade(plaster(r, "#d9d2c2", "#c4bdae", levels=64), T.stripes_v(64, 8, 0.5), 0.12), 10), surface="carpet")
    reg("fabric/sofa", _sofa_plaid, surface="carpet")
    reg("fabric/banner_key", lambda r: _crest(r, "key"), surface="carpet")
    reg("fabric/banner_eye", lambda r: _crest(r, "eye"), surface="carpet")
    reg("fabric/tapestry", _tapestry, surface="carpet")
    reg("fabric/coat", _coat_black, surface="carpet")
    reg("fabric/skin", lambda r: plaster(r, "#d8c0a8", "#c0a890", levels=8), surface="flesh")
    reg("fabric/dog_fur", _dog_fur, surface="carpet")

    # organic
    reg("organic/bones", bones_wall, surface="bone")
    reg("organic/flesh", lambda r: flesh(r, fu["flesh"], fu["flesh2"], fu["vein"]), surface="flesh")
    reg("organic/flesh_dark", lambda r: flesh(r, "#4a1a24", "#2a0c12", "#1a0a20"), surface="flesh")
    reg("organic/eye", _eye, alpha=True)

    # props / pictures (128)
    reg("props/tv_static", lambda r: tv_static(r, 64), surface="metal")
    reg("props/tv_face", lambda r: tv_static(r, 64, face=True), surface="metal")
    reg("props/window_night", lambda r: window(r, True))
    reg("props/window_lit", lambda r: window(r, False))
    reg("props/painting_landscape", lambda r: painting(r, "landscape"))
    reg("props/painting_portrait", lambda r: painting(r, "portrait"))
    reg("props/painting_door", lambda r: painting(r, "door"))
    reg("props/painting_house", lambda r: painting(r, "house"))
    for i in range(5):
        reg("props/photo_%d" % i, (lambda k: (lambda r: photo(r, k)))(i))
    reg("props/map_scrap", _map_scrap)
    reg("props/calendar", _calendar)
    reg("props/keypad", _keypad, surface="metal")
    reg("props/mirror", _mirror_surface, surface="tile")
    reg("props/rune_ring", lambda r: rune_ring(r), alpha=True)
    reg("props/rune_ring_floor", lambda r: rune_ring(r, alpha=False))
    for nm in ("ELSPETH", "MORROW", "HALDEN", "ANNIS", "", "YOU"):
        key = nm.lower() if nm else "blank"
        reg("props/grave_%s" % key, (lambda n: (lambda r: gravestone(r, n)))(nm))

    # signs and text
    reg("signs/last_lamp", lambda r: sign(["THE LAST LAMP"], tv["wood"], tv["candle"], size=(160, 48), kind="title", font_size=30, frame_color=tv["amber"]))
    reg("signs/five_half", lambda r: sign(["5½"], "#2a2a2e", "#e0d8c0", size=(48, 48), kind="display", font_size=26, frame_color="#8a8478"))
    reg("signs/exit", lambda r: sign(["EXIT"], "#1a3a1a", "#c8ffc8", size=(96, 40), kind="body", font_size=30))
    reg("signs/exit_wrong", lambda r: sign(["TIXE"], "#1a3a1a", "#c8ffc8", size=(96, 40), kind="body", font_size=30))
    reg("signs/take_a_number", lambda r: sign(["PLEASE TAKE", "A NUMBER"], of["light"], "#3a3a40", size=(128, 64), kind="body", font_size=22, frame_color="#8a8478"))
    reg("signs/your_call", lambda r: sign(["YOUR CALL IS", "IMPORTANT", "TO SOMEONE"], "#d0d8e0", "#2a3040", size=(128, 96), kind="body", font_size=20, frame_color="#8a8478"))
    reg("signs/now_serving", lambda r: sign(["NOW SERVING", "0000"], "#101014", "#ff3a2a", size=(128, 64), kind="body", font_size=24, frame_color="#3a3a40"))
    reg("signs/plaque_anteroom", lambda r: sign(["YOU ARE EARLY.", "WAIT HERE."], "#2a2440", nx["gold"], size=(128, 64), kind="display", font_size=15, frame_color=nx["gold"]))
    reg("signs/plaque_mirror", lambda r: sign([".ETAL ERA UOY", ".EREH TIAW"], "#2a2440", "#a7f3f0", size=(128, 64), kind="display", font_size=15, frame_color="#a7f3f0"))
    reg("signs/king_asleep", lambda r: sign(["the king", "is asleep"], "#1a1a20", "#b8963e", size=(128, 64), kind="title", font_size=22))
    reg("signs/no_vacancy", lambda r: sign(["NO VACANCY", "(one room)"], "#3a1a1a", "#ffb0a0", size=(128, 64), kind="body", font_size=22, frame_color="#8a4a3a"))
    reg("signs/halden_arms", lambda r: sign(["THE HALDEN ARMS", "flats 1 - 12", "and 5½"], "#2a2a2e", "#d0c8b0", size=(128, 64), kind="display", font_size=14, frame_color="#8a8478"))
    reg("signs/menu", lambda r: _chalkboard(r, ["TODAY:", "nothing", "", "TOMORROW:", "nothing, warmed"]))
    reg("signs/graffiti_wake", lambda r: T.add_alpha(sign(["WAKE UP"], "#000000", "#d9b24c", size=(128, 40), kind="title", font_size=30), (sign(["WAKE UP"], "#000000", "#ffffff", size=(128, 40), kind="title", font_size=30)[..., 0] > 0.5).astype(np.float32)), alpha=True)
    reg("signs/graffiti_door", lambda r: T.add_alpha(sign(["the door is a lie"], "#000000", "#c9402a", size=(128, 32), kind="body", font_size=18), (sign(["the door is a lie"], "#000000", "#ffffff", size=(128, 32), kind="body", font_size=18)[..., 0] > 0.5).astype(np.float32)), alpha=True)
    reg("signs/note_hallway", lambda r: _note(r, ["I measured it", "again. Inside:", "27 ft 4 in.", "Outside: 21 ft.", "", "The house is", "6 feet wrong.", "", "Do not tell", "the children."]))
    reg("signs/note_apartment", lambda r: _note(r, ["things to do:", "- sleep", "- measure the", "  closet", "- do NOT open", "  the closet", "- sleep", "", "(the last one", " is crossed out)"]))
    reg("signs/note_house", lambda r: _note(r, ["Dear whoever", "is reading this:", "", "the bathroom", "got bigger", "again. I moved", "the photos.", "", "Feed the dog.", "  - M."]))
    reg("signs/note_tavern", lambda r: _note(r, ["RIDDLE (for a", "coin):", "", "I have doors", "but no house,", "a well but no", "water, and", "everyone waits", "in me.", "  What am I?"]))
    reg("signs/note_king", lambda r: _note(r, ["The King sleeps", "so the Keep", "may stand.", "", "Wake him and", "the hours", "will fall out", "of the clock", "like teeth.", "  - the Steward"], ink="#4a1a1a"))
    reg("signs/note_offices", lambda r: _note(r, ["MEMO", "", "Your number", "will be called.", "", "Your number", "was called.", "", "Your number", "will be called."]))
    reg("signs/book_cover", lambda r: sign(["A HOUSE", "OF", "HALLWAYS"], "#2a1a2a", "#c9a227", size=(64, 96), kind="display", font_size=11, frame_color="#c9a227"))
    reg("signs/book_cover_2", lambda r: sign(["ON", "SLEEPING", "KINGS"], "#1a2a3a", "#c9c2b0", size=(64, 96), kind="display", font_size=11, frame_color="#8a8478"))
    reg("signs/label_moonlight", lambda r: sign(["MOONLIGHT", "do not open", "in daylight"], "#e8e4dc", "#2a2a40", size=(64, 48), kind="body", font_size=11))

    # faces
    reg("faces/sea_sleep", lambda r: face_card(r, "#f5e6dc", "#6a4a5a", "#c07a8a", eyes_open=False, smile=True), alpha=True)
    reg("faces/sea_awake", lambda r: face_card(r, "#f5e6dc", "#2a1a3a", "#c07a8a", eyes_open=True, smile=True), alpha=True)
    reg("faces/sea_sad", lambda r: face_card(r, "#e0d0e8", "#3a2a5a", "#8a6a9a", eyes_open=False, smile=False), alpha=True)
    reg("faces/usher", lambda r: face_card(r, "#f0eee8", "#101014", "#101014", eyes_open=False, smile=False, tone_split=True), alpha=True)
    reg("faces/patron", lambda r: face_card(r, "#d8c0a8", "#d8c0a8", "#d8c0a8", eyes_open=False, smile=False), alpha=True)
    reg("faces/king", lambda r: face_card(r, "#d8c8b0", "#5a4a3a", "#8a6a5a", eyes_open=False, smile=False), alpha=True)
    reg("faces/moon", lambda r: face_card(r, "#f0e6c8", "#8a7a5a", "#8a7a5a", eyes_open=False, smile=True), alpha=True)
    reg("faces/dog", lambda r: face_card(r, "#8a7358", "#1a1410", "#1a1410", eyes_open=True, smile=True), alpha=True)

    # ui
    for kid, col in (("lantern", "#f2b134"), ("wings", "#d8c7ff"), ("mouse", "#b6a48e"), ("crown", "#e8d36a"), ("bell", "#9fd3c7"),
                     ("knife", "#c9cdd6"), ("umbrella", "#6c8cd5"), ("hourglass", "#f0e6c8"), ("shard", "#a7f3f0")):
        reg("ui/keepsake_%s" % kid, (lambda k, c_: (lambda r: keepsake_icon(k, c_)))(kid, col), alpha=True)
    reg("ui/cursor", lambda r: keepsake_icon("shard", "#ffffff", 16), alpha=True)


def generate(only=None, sheet=False):
    build_catalog()
    manifest = {}
    written = []
    for name, (fn, opts) in CATALOG.items():
        if only and only not in name:
            continue
        rng = T.rng_for(name)
        img = fn(rng)
        path = OUT / (name + ".png")
        T.save_png(path, img)
        h, w = img.shape[:2]
        manifest[name] = {"w": int(w), "h": int(h), "surface": opts.get("surface", "stone"), "alpha": bool(opts.get("alpha", False) or img.shape[-1] == 4)}
        written.append(path)
    if not only:
        (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True))
    if sheet:
        T.contact_sheet(sorted(written), T.ROOT / "screenshots" / "textures_sheet.png", cols=12)
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--sheet", action="store_true")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    if a.list:
        build_catalog()
        for n in CATALOG:
            print(n)
        return
    w = generate(a.only, a.sheet)
    total = sum(p.stat().st_size for p in w)
    print("wrote %d textures (%.1f KB) to %s" % (len(w), total / 1024, OUT))


if __name__ == "__main__":
    main()
