#!/usr/bin/env python3
"""Generate the AssetLife app icon (1024x1024 PNG, no alpha) with pure stdlib.

Design: near-black canvas (#171717), a bright green (#9BE52E) rounded label/tag
with a punched hole and three ascending dark bars (growth motif). Flat, on-brand,
no external assets.
"""
import struct
import zlib

SIZE = 1024
BG = (0x17, 0x17, 0x17)
GREEN = (0x9B, 0xE5, 0x2E)


def rounded_rect_contains(px, py, x0, y0, x1, y1, r):
    # shrink to inner box
    cx = min(max(px, x0 + r), x1 - r)
    cy = min(max(py, y0 + r), y1 - r)
    if x0 + r <= px <= x1 - r or y0 + r <= py <= y1 - r:
        return x0 <= px <= x1 and y0 <= py <= y1
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def circle_contains(px, py, cx, cy, r):
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def main():
    # tag geometry
    tx0, ty0, tx1, ty1, tr = 176, 268, 848, 756, 110
    # hole
    hx, hy, hr = 316, 512, 46
    # bars (baseline aligned), dark on green
    bars = []
    baseline = 656
    heights = [168, 252, 336]
    widths = [88, 88, 88]
    xs = [432, 588, 744]
    for x, w, h in zip(xs, widths, heights):
        bars.append((x, baseline - h, x + w, baseline, 20))

    rows = []
    for y in range(SIZE):
        row = bytearray()
        row.append(0)  # filter type 0
        for x in range(SIZE):
            if rounded_rect_contains(x, y, tx0, ty0, tx1, ty1, tr):
                if circle_contains(x, y, hx, hy, hr):
                    row.extend(BG)
                elif any(rounded_rect_contains(x, y, *b) for b in bars):
                    row.extend(BG)
                else:
                    row.extend(GREEN)
            else:
                row.extend(BG)
        rows.append(bytes(row))

    raw = b"".join(rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")

    out = "/Users/vrp/WorkBuddy/2026-10-23-23-05-23/AssetLife/AssetLife/Resources/Assets.xcassets/AppIcon/AppIcon.png"
    with open(out, "wb") as f:
        f.write(png)
    print("wrote", out, len(png), "bytes")


if __name__ == "__main__":
    main()
