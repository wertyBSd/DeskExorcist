# Turns the raw generated JPGs in temp/ into the PNGs the game actually loads
# (see LEONARDO_PROMPTS.md). Run headless:
#   blender.exe --background --python tools/build_ui_art.py
#
# Why a script instead of "rename .jpg to .png": the spell icons have to end up
# as 256x256 RGBA with a TRANSPARENT background. The sources come out of the
# image model as opaque 1024x1024 JPGs -- each one painted on a different flat
# backdrop (navy, white, beige, blue, an app-icon tile, a full stone scene).
# Dropping those into the HUD as-is would show a coloured square sitting on the
# crosshair, so every icon gets the backdrop taken off here.
#
# The cut is a flood fill from the border, not a global colour key: these are
# flat-vector icons, so "background" is "whatever is connected to the edge".
# Two guards keep it honest on the awkward ones:
#   * a local step tolerance, so gradients (glows, long drop shadows) stay
#     background instead of leaking into the subject;
#   * a global distance cap, so a smooth ramp cannot flood the whole frame and
#     swallow the icon.
# Per-icon overrides for cap/lo/hi live in ICONS below; the comment on each
# line says which backdrop forced the value.
#
# Blender is the only Python on this machine with numpy, and bpy reads/writes
# the image files for us -- hence "run it through Blender" like build_models.py.

import bpy
import math
import os
import numpy as np

ROOT = r"c:\research\games\Shooter"
SRC_DIR = os.path.join(ROOT, "temp")
ICON_DIR = os.path.join(ROOT, "assets", "ui", "icons")
BG_DIR = os.path.join(ROOT, "assets", "ui", "backgrounds")

ICON_SIZE = 256
# Margin around the subject, as a fraction of the crop box. LEONARDO_PROMPTS.md
# asks for ~10% so the sign survives STRETCH_KEEP_ASPECT_CENTERED into a 40px
# slot without its edges being shaved off.
PAD = 0.08
# Resolution the flood fill runs at. 512 is plenty to resolve a silhouette and
# keeps the region-grow loop fast; the mask is upscaled afterwards.
FLOOD_RES = 512
# Feather band, in full-res pixels, over which alpha ramps from 0 to 1.
FEATHER = 5

# spell_id -> settings. "cap"/"lo"/"hi" are RGB distances on a 0..255 scale.
#   cap : flood stops (background ends) beyond this distance from the backdrop
#   lo  : below this distance a pixel counts as pure background
#   hi  : beyond it, fully opaque subject
# "glow" is an optional (low, high) luminance ramp multiplied over the result:
# it keeps the bright core of a bloomed icon and lets the dim outer bloom fade
# out instead of freezing into a muddy solid blob.
ICONS = {
    # Red hammer on a beige backdrop with a long cast shadow. The shadow is a
    # beige gradient ~85 units from the wall colour, so the cap has to clear it
    # or a grey diagonal slab survives into the icon.
    0: dict(cap=115.0, lo=30.0, hi=95.0),
    # Glowing sword on navy. The bloom is a wide lens of dark orange -- dim
    # enough that the colour key reads it as subject -- so it is faded by
    # brightness: only the blade and the tight glow at its edge stay.
    1: dict(cap=45.0, lo=18.0, hi=70.0, glow=(0.28, 0.44)),
    # Rune circle on a stone floor: the backdrop is a whole scene, not a flat
    # colour, so flood fill has nothing to grip. Handled as a disc below.
    2: dict(mode="disc", crop=0.66),
    # Purple boot on a rounded app-icon tile. High cap eats the tile too, which
    # keeps the bar stylistically uniform (all ten icons are bare subjects).
    3: dict(cap=95.0, lo=30.0, hi=95.0),
    # Lightning on navy, no glow to speak of.
    4: dict(cap=55.0, lo=18.0, hi=70.0),
    # Gold hammer on a purple tile: same as spell 3.
    5: dict(cap=95.0, lo=30.0, hi=95.0),
    # Cyan arcs on navy with a soft bloom, same treatment as the sword.
    6: dict(cap=45.0, lo=18.0, hi=70.0, glow=(0.18, 0.55)),
    # Censer on blue with a very long diagonal drop shadow; the shadow is the
    # one backdrop tone far from the wall, hence the mid cap. The chains also
    # fence off a pocket of backdrop, which the hole fill has to reclaim.
    7: dict(cap=80.0, lo=22.0, hi=75.0),
    # Footprint on peach. Its bloom is only ~90 units off the backdrop colour,
    # so the cap has to clear that to take the glow with the backdrop; the
    # dark outline around the foot is what stops the fill there.
    8: dict(cap=72.0, lo=25.0, hi=85.0),
    # Gold mirror on white: the easy case.
    9: dict(cap=70.0, lo=20.0, hi=70.0),
}

# Opaque 16:9 frames, copied across as-is (no alpha wanted, no cropping).
BACKGROUNDS = ["menu", "training", "arena_overview"]

# Filled by build_icons() so the contact sheet can reuse the finished crops.
BUILT = []


# --- bpy image I/O ----------------------------------------------------------
# Colourspace is forced to Non-Color on both ends so the pixels are the stored
# bytes, not a linearised copy: converting would shift every colour and the
# output PNG would no longer match the file the artist graded.

def load_rgba(path):
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    # Blender stores rows bottom-up; flip once here and once in save_rgba().
    arr = buf.reshape(h, w, 4)[::-1].copy()
    bpy.data.images.remove(img)
    return arr


def save_rgba(path, arr):
    h, w = arr.shape[:2]
    out = bpy.data.images.new(os.path.basename(path), width=w, height=h,
                              alpha=True, float_buffer=False)
    out.colorspace_settings.name = "Non-Color"
    out.pixels.foreach_set(np.ascontiguousarray(arr[::-1], dtype=np.float32).ravel())
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


# --- small numeric helpers --------------------------------------------------

def dist255(a, b):
    return np.sqrt(((a - b) ** 2).sum(-1)) * 255.0


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _downscale(arr, res):
    h, w = arr.shape[:2]
    if min(h, w) <= res:
        return arr
    ys = (np.arange(res) + 0.5) * h / res - 0.5
    xs = (np.arange(res) + 0.5) * w / res - 0.5
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    y1 = np.clip(y0 + 1, 0, h - 1)
    x1 = np.clip(x0 + 1, 0, w - 1)
    wy = smoothstep(ys - y0)[:, None, None]
    wx = smoothstep(xs - x0)[None, :, None]
    top = arr[np.clip(y0, 0, h - 1)][:, np.clip(x0, 0, w - 1)] * (1 - wx) \
        + arr[np.clip(y0, 0, h - 1)][:, x1] * wx
    bot = arr[y1][:, np.clip(x0, 0, w - 1)] * (1 - wx) + arr[y1][:, x1] * wx
    return top * (1 - wy) + bot * wy


def _upsample_nearest(mask, h, w):
    sh, sw = mask.shape
    return mask[(np.arange(h) * sh // h)[:, None], (np.arange(w) * sw // w)[None, :]]


def _dilate(mask, k):
    m = mask.copy()
    for _ in range(k):
        n = m.copy()
        n[1:, :] |= m[:-1, :]
        n[:-1, :] |= m[1:, :]
        n[:, 1:] |= m[:, :-1]
        n[:, :-1] |= m[:, 1:]
        n[1:, 1:] |= m[:-1, :-1]
        n[1:, :-1] |= m[:-1, 1:]
        n[:-1, 1:] |= m[1:, :-1]
        n[:-1, :-1] |= m[1:, 1:]
        m = n
    return m


def _erode(mask, k):
    return ~_dilate(~mask, k)


def _open(mask, k):
    """Morphological opening: drops anything thinner than 2k+1 px. That is
    exactly what is left over when a flood fill stops a hair short -- the cast
    shadow on spell 0 survives as a one-pixel diagonal line."""
    return _dilate(_erode(mask, k), k)


def _majority(mask):
    """3x3 majority vote. The flood fill resolves at 512 and gets upscaled, so
    its boundary is stair-stepped; one vote smooths that without visibly
    shrinking anything."""
    h, w = mask.shape
    p = np.pad(mask.astype(np.uint8), 1)
    total = np.zeros((h, w), dtype=np.uint8)
    for dy in range(3):
        for dx in range(3):
            total += p[dy:dy + h, dx:dx + w]
    return total >= 5


def _reached_from_border(mask):
    """The subset of `mask` that is 4-connected to the frame. Whatever is left
    over is enclosed -- the censer's chains fence off a pocket of backdrop
    (spell 7) that no flood from the edge can ever reach."""
    out = np.zeros_like(mask)
    out[:1, :] |= mask[:1, :]
    out[-1:, :] |= mask[-1:, :]
    out[:, :1] |= mask[:, :1]
    out[:, -1:] |= mask[:, -1:]
    for _ in range(mask.shape[0] + mask.shape[1]):
        before = int(out.sum())
        n = out.copy()
        n[1:, :] |= out[:-1, :]
        n[:-1, :] |= out[1:, :]
        n[:, 1:] |= out[:, :-1]
        n[:, :-1] |= out[:, 1:]
        n &= mask
        if int(n.sum()) == before:
            break
        out = n
    return out


def resize_rgba(img, out_w, out_h):
    """Bilinear resize. Done on premultiplied alpha: blending straight RGBA
    would pull the transparent pixels' colour into every soft edge and ring
    each icon in a dark halo."""
    sh, sw = img.shape[:2]
    if (sw, sh) == (out_w, out_h):
        return img
    alpha = img[..., 3:4]
    # Premultiplied RGB + the real alpha, both interpolated together. Putting a
    # constant 1.0 in the alpha slot here would rescale the whole crop back to
    # fully opaque.
    pm = np.concatenate([img[..., :3] * alpha, alpha], -1)
    ys = (np.arange(out_h) + 0.5) * sh / out_h - 0.5
    xs = (np.arange(out_w) + 0.5) * sw / out_w - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, sh - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, sw - 1)
    y1 = np.clip(y0 + 1, 0, sh - 1)
    x1 = np.clip(x0 + 1, 0, sw - 1)
    wy = smoothstep(ys - np.floor(ys))[:, None, None]
    wx = smoothstep(xs - np.floor(xs))[None, :, None]
    top = pm[y0][:, x0] * (1 - wx) + pm[y0][:, x1] * wx
    bot = pm[y1][:, x0] * (1 - wx) + pm[y1][:, x1] * wx
    out = top * (1 - wy) + bot * wy
    out_alpha = np.clip(out[..., 3:4], 0.0, 1.0)
    rgb = np.where(out_alpha > 1e-4, out[..., :3] / np.maximum(out_alpha, 1e-4), 0.0)
    return np.clip(np.concatenate([rgb, out_alpha], -1), 0.0, 1.0)


# --- backdrop removal -------------------------------------------------------

def _border_samples(rgb):
    """Median colours of the four edges: the palette the backdrop is allowed
    to be. Distance is taken to the NEAREST of them, so a backdrop that
    gradients from dark to light still counts as backdrop everywhere."""
    h, w = rgb.shape[:2]
    band = max(2, int(min(h, w) * 0.02))
    edges = [
        rgb[:band].reshape(-1, 3),
        rgb[-band:].reshape(-1, 3),
        rgb[:, :band].reshape(-1, 3),
        rgb[:, -band:].reshape(-1, 3),
    ]
    return [np.median(e, axis=0) for e in edges]


def _global_distance(rgb, samples):
    d = None
    for s in samples:
        cur = dist255(rgb, s)
        d = cur if d is None else np.minimum(d, cur)
    return d


def flood_backdrop(rgb, samples, cap, step_tol=16.0):
    """Region-grow 'background' inward from the border ring. A neighbour joins
    the background when it is both close to its own neighbour (step_tol, which
    lets gradients and shadows stay background) and close to the backdrop
    palette (cap, which stops the grow from running away)."""
    dglob = _global_distance(rgb, samples)
    allowed = dglob < cap
    h, w = rgb.shape[:2]
    bg = np.zeros((h, w), dtype=bool)
    bg[:2, :] = bg[-2:, :] = bg[:, :2] = bg[:, -2:] = True
    bg &= allowed
    for _ in range(h + w + 8):
        before = int(bg.sum())
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nb = np.roll(bg, (dy, dx), axis=(0, 1))
            px_nb = np.roll(rgb, (dy, dx), axis=(0, 1))
            # np.roll wraps; drop the wrapped row/column so the grow cannot
            # jump across the image.
            if dy == -1:
                nb[-1, :] = False
            elif dy == 1:
                nb[0, :] = False
            elif dx == -1:
                nb[:, -1] = False
            else:
                nb[:, 0] = False
            bg |= nb & ~bg & (dist255(rgb, px_nb) < step_tol) & allowed
        if int(bg.sum()) == before:
            break
    return bg, dglob


def _disc_alpha(h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    cy, cx = (h - 1) * 0.5, (w - 1) * 0.5
    r = np.sqrt(((yy - cy) / (h * 0.5)) ** 2 + ((xx - cx) / (w * 0.5)) ** 2)
    return smoothstep((1.0 - r) / 0.05)[:, :, None]


def build_alpha(rgb, cfg):
    h, w = rgb.shape[:2]
    if cfg.get("mode") == "disc":
        crop = cfg["crop"]
        ch, cw = int(h * crop), int(w * crop)
        y0, x0 = (h - ch) // 2, (w - cw) // 2
        rgb = rgb[y0:y0 + ch, x0:x0 + cw]
        return rgb, _disc_alpha(rgb.shape[0], rgb.shape[1])[:, :, 0]
    samples = _border_samples(rgb)
    small = _downscale(rgb, FLOOD_RES)
    small_samples = _border_samples(small)
    bg_small, dglob_small = flood_backdrop(small, small_samples, cfg["cap"])
    subject_small = ~bg_small
    # Backdrop-coloured pockets the fill never reached because the subject
    # sealed them off: the censer hangs on chains, and the triangle between
    # them is wall, not subject. Without this the hole ships as a solid slab
    # of backdrop colour.
    sealed = ~_reached_from_border(subject_small) & (dglob_small < cfg["cap"])
    subject_small &= ~sealed
    subject = _upsample_nearest(subject_small, h, w)
    bg = ~subject
    subject = _majority(_open(subject, 2))
    # Softness only matters in a thin band just inside the cut: that is where
    # the anti-aliased edge and the outer bloom live. Everywhere else the
    # subject is either solid colour or noise, and softening it would only
    # wash the icon out.
    band = _dilate(bg, FEATHER) & subject
    soft = smoothstep((_global_distance(rgb, samples) - cfg["lo"])
                      / max(cfg["hi"] - cfg["lo"], 1e-3))
    alpha = np.where(bg, 0.0, np.where(band, soft, 1.0))
    if "glow" in cfg:
        # A bloom that sits closer to the backdrop than the subject does (or is
        # too dim to pass a colour key on its own) has to be faded by
        # brightness instead: the bright core survives, the haze around it
        # dissolves into transparency instead of freezing into a solid disc.
        lo, hi = cfg["glow"]
        lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        alpha = alpha * smoothstep((lum - lo) / max(hi - lo, 1e-3))
    return rgb, alpha


def crop_to_subject(rgb, alpha, out=ICON_SIZE, pad=PAD):
    mask = alpha > 0.5
    ys, xs = np.nonzero(mask)
    if ys.size == 0:
        return None
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    side = int(max(y1 - y0, x1 - x0) * (1.0 + 2.0 * pad))
    cy, cx = (y0 + y1) * 0.5, (x0 + x1) * 0.5
    side = max(side, 8)
    half = side * 0.5
    ry0 = int(max(0, min(cy - half, rgb.shape[0] - side)))
    rx0 = int(max(0, min(cx - half, rgb.shape[1] - side)))
    ry0 = int(min(ry0, max(0, rgb.shape[0] - side)))
    rx0 = int(min(rx0, max(0, rgb.shape[1] - side)))
    sub = rgb[ry0:ry0 + side, rx0:rx0 + side]
    suba = alpha[ry0:ry0 + side, rx0:rx0 + side][:, :, None]
    return resize_rgba(np.concatenate([sub, suba], -1), out, out)


# --- entry point ------------------------------------------------------------

def build_icons():
    os.makedirs(ICON_DIR, exist_ok=True)
    for spell_id in sorted(ICONS):
        cfg = ICONS[spell_id]
        src = os.path.join(SRC_DIR, "spell_%d.jpg" % spell_id)
        if not os.path.exists(src):
            print("  skip spell_%d: no source" % spell_id)
            continue
        rgb = load_rgba(src)[:, :, :3]
        rgb, alpha = build_alpha(rgb, cfg)
        out = crop_to_subject(rgb, alpha)
        if out is None:
            print("  FAIL spell_%d: nothing left after the cut" % spell_id)
            continue
        save_rgba(os.path.join(ICON_DIR, "spell_%d.png" % spell_id), out)
        cover = float((out[..., 3] > 0.5).mean())
        BUILT.append((spell_id, out))
        print("  spell_%d.png  %dx%d  opaque %.0f%%" %
              (spell_id, out.shape[1], out.shape[0], cover * 100.0))


def write_contact_sheet():
    """Two review strips: every icon on a checkerboard (so a failed cut shows
    up as a halo), and every icon at the real 40px slot size on the dark HUD
    panel (so a sign that only reads at 256px gets caught)."""
    if not BUILT:
        return
    cell = ICON_SIZE
    big = np.concatenate([_checkerboard(cell * len(BUILT), cell), ], axis=0)
    for i, (_, icon) in enumerate(BUILT):
        _blend(big, resize_rgba(icon, cell, cell), i * cell, 0)
    save_rgba(os.path.join(SRC_DIR, "ui_icons_sheet.png"),
              np.concatenate([big, np.ones(big.shape[:2] + (1,), np.float32)], -1))

    hud = np.tile(np.array([0.10, 0.10, 0.13], dtype=np.float32), (cell, cell * len(BUILT), 1))
    for i, (_, icon) in enumerate(BUILT):
        _blend(hud, resize_rgba(icon, 40, 40), i * cell + (cell - 40) // 2,
               (cell - 40) // 2)
    hud = _nearest_scale(hud, 4)
    save_rgba(os.path.join(SRC_DIR, "ui_icons_hud.png"),
              np.concatenate([hud, np.ones(hud.shape[:2] + (1,), np.float32)], -1))
    print("  temp/ui_icons_sheet.png, temp/ui_icons_hud.png")


def _nearest_scale(img, k):
    return np.repeat(np.repeat(img, k, axis=0), k, axis=1)


def _checkerboard(w, h, sq=16):
    yy, xx = np.mgrid[0:h, 0:w]
    a = (((yy // sq) + (xx // sq)) % 2).astype(np.float32)
    c = 0.55 + 0.25 * a
    return np.repeat(c[:, :, None], 3, axis=2)


def _blend(dst, src, x0, y0):
    h, w = src.shape[:2]
    region = dst[y0:y0 + h, x0:x0 + w]
    a = src[..., 3:4]
    dst[y0:y0 + h, x0:x0 + w] = src[..., :3] * a + region * (1.0 - a)


def build_backgrounds():
    os.makedirs(BG_DIR, exist_ok=True)
    for name in BACKGROUNDS:
        src = os.path.join(SRC_DIR, name + ".jpg")
        if not os.path.exists(src):
            print("  skip %s: no source" % name)
            continue
        arr = load_rgba(src)
        arr[..., 3] = 1.0
        save_rgba(os.path.join(BG_DIR, name + ".png"), arr)
        print("  %s.png  %dx%d" % (name, arr.shape[1], arr.shape[0]))


def main():
    print("icons:")
    build_icons()
    print("backgrounds:")
    build_backgrounds()
    print("contact sheet:")
    write_contact_sheet()
    print("done")


main()
