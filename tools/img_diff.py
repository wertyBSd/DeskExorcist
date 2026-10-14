"""Pixel-diff two PNGs and report where (and how much) they differ.

Used by the shadow bench work: eyeballing two nearly identical 1280x720 frames
tells you that "something changed" and nothing about where. This prints the
bounding box of the changed pixels and the strongest change, which is what
actually decides whether a decal is landing where it should.

    python tools/img_diff.py a.png b.png [--crop out.png x0 y0 x1 y1]

No third-party deps: the project has no Python packages installed.
"""

import struct
import sys
import zlib


def read_png(path):
    """Decode a non-interlaced 8-bit RGB/RGBA PNG into (w, h, bpp, pixels)."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    w = h = ct = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, _depth, ct = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length
    bpp = 4 if ct == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * bpp
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        out += line
        prev = line
    return w, h, bpp, bytes(out)


def write_png(path, w, h, bpp, pixels):
    """Write an 8-bit RGB PNG (alpha is dropped)."""
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        row = pixels[y * w * bpp:(y + 1) * w * bpp]
        for x in range(w):
            o = x * bpp
            rows += bytes(row[o:o + 3])
    ct = 2

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, ct, 0, 0, 0)
    blob = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(rows), 6))
            + chunk(b"IEND", b""))
    open(path, "wb").write(blob)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    a, b = sys.argv[1], sys.argv[2]
    w1, h1, bpp1, p1 = read_png(a)
    w2, h2, bpp2, p2 = read_png(b)
    if (w1, h1) != (w2, h2):
        print("size mismatch: %dx%d vs %dx%d" % (w1, h1, w2, h2))
        return 1
    changed = 0
    worst = 0
    worst_at = None
    minx, miny, maxx, maxy = w1, h1, -1, -1
    for y in range(h1):
        for x in range(w1):
            o = (y * w1 + x) * bpp1
            o2 = (y * w2 + x) * bpp2
            d = max(abs(p1[o + k] - p2[o2 + k]) for k in range(3))
            if d > 1:
                changed += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
            if d > worst:
                worst, worst_at = d, (x, y)
    total = w1 * h1
    print("%s vs %s" % (a, b))
    print("  changed %d px (%.2f%%), strongest delta %d at %s"
          % (changed, 100.0 * changed / total, worst, worst_at))
    if changed:
        print("  bbox x %d..%d  y %d..%d" % (minx, maxx, miny, maxy))
    if "--pixels" in sys.argv:
        # Raw RGB of both frames at given points. Needed to tell a decal that
        # fades to nothing at its rim from one that tints its whole quad: the
        # bounding box is the quad either way.
        pts = sys.argv[sys.argv.index("--pixels") + 1].split(";")
        print("  pixel          a            b")
        for pt in pts:
            x, y = (int(v) for v in pt.split(","))
            o = (y * w1 + x) * bpp1
            q = (y * w2 + x) * bpp2
            print("  (%4d,%4d)  %-12s %-12s" % (
                x, y, tuple(p1[o:o + 3]), tuple(p2[q:q + 3])))
    if "--line" in sys.argv:
        # Delta profile along one row: tells a soft radial falloff (a smooth
        # hump) from a flat tint (a plateau), which is the difference between a
        # decal that reads as shade and one that reads as a painted square.
        y = int(sys.argv[sys.argv.index("--line") + 1])
        row = []
        for x in range(0, w1, max(1, w1 // 64)):
            o = (y * w1 + x) * bpp1
            q = (y * w2 + x) * bpp2
            row.append(max(abs(p1[o + k] - p2[q + k]) for k in range(3)))
        print("  row %d deltas:" % y)
        print("   ", " ".join("%3d" % v for v in row))
    if "--crop" in sys.argv:
        i = sys.argv.index("--crop")
        out, x0, y0, x1, y1 = sys.argv[i + 1], *map(int, sys.argv[i + 2:i + 6])
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(w1, x1), min(h1, y1)
        cw, ch = x1 - x0, y1 - y0
        crop = bytearray()
        for y in range(y0, y1):
            o = (y * w1 + x0) * bpp1
            crop += p1[o:o + cw * bpp1]
        write_png(out, cw, ch, bpp1, bytes(crop))
        print("  wrote %s (%dx%d)" % (out, cw, ch))
    return 0


if __name__ == "__main__":
    sys.exit(main())
