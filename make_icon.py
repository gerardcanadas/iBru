#!/usr/bin/env python3
"""
Generate a 1024x1024 iBru app icon as a pure-Python PNG (no external deps).

Design:
  - Warm coral radial gradient background (#FF6B6B → #E84040)
  - Rounded corners (iOS-style squircle mask, soft 220px radius)
  - Centred white heart shape with a tiny baby silhouette inside
  - Small decorative dots (baby feel)
"""
import struct, zlib, math, os

W = H = 1024

def lerp(a, b, t): return a + (b - a) * t

def clamp(v, lo=0, hi=255): return max(lo, min(hi, int(round(v))))

# ── pixel buffer (RGBA) ──────────────────────────────────────────────────────
pixels = bytearray(W * H * 4)

def set_px(x, y, r, g, b, a=255):
    if 0 <= x < W and 0 <= y < H:
        idx = (y * W + x) * 4
        # alpha-blend onto existing pixel
        src_a = a / 255.0
        dst_a = pixels[idx + 3] / 255.0
        out_a = src_a + dst_a * (1 - src_a)
        if out_a > 0:
            pixels[idx]     = clamp((r * src_a + pixels[idx]     * dst_a * (1 - src_a)) / out_a)
            pixels[idx + 1] = clamp((g * src_a + pixels[idx + 1] * dst_a * (1 - src_a)) / out_a)
            pixels[idx + 2] = clamp((b * src_a + pixels[idx + 2] * dst_a * (1 - src_a)) / out_a)
            pixels[idx + 3] = clamp(out_a * 255)

# ── squircle mask helper ─────────────────────────────────────────────────────
def squircle_alpha(x, y, cx, cy, r, n=4.0):
    """Returns 0..1 smoothstep alpha for a superellipse."""
    dx = abs(x - cx) / r
    dy = abs(y - cy) / r
    val = dx**n + dy**n
    # smooth edge ±1px
    edge = (r * ((1**n + 0**n))**(1/n))  # always 1.0 in normalised space
    dist = val ** (1/n)  # normalised distance from centre (1.0 = edge)
    t = (dist - 0.97) / 0.06
    return max(0.0, min(1.0, 1.0 - t))

# ── 1. Coral radial gradient background ──────────────────────────────────────
cx, cy = W / 2, H / 2
r_outer = W * 0.72

# Coral light (#FF6B6B) → deeper coral (#D94040)
for y in range(H):
    for x in range(W):
        dx = x - cx
        dy = y - cy
        dist = math.sqrt(dx*dx + dy*dy)
        t = min(dist / r_outer, 1.0)
        # radial gradient
        pr = clamp(lerp(0xFF, 0xD9, t))
        pg = clamp(lerp(0x6B, 0x40, t))
        pb = clamp(lerp(0x6B, 0x40, t))
        # squircle mask (iOS rounded corner)
        sq_a = squircle_alpha(x, y, cx, cy, W * 0.46, n=5)
        idx = (y * W + x) * 4
        pixels[idx]     = pr
        pixels[idx + 1] = pg
        pixels[idx + 2] = pb
        pixels[idx + 3] = clamp(sq_a * 255)

# ── helpers ───────────────────────────────────────────────────────────────────
def fill_circle(cx, cy, radius, r, g, b, a=255, aa=True):
    ir = int(radius) + 2
    for dy in range(-ir, ir + 1):
        for dx in range(-ir, ir + 1):
            dist = math.sqrt(dx*dx + dy*dy)
            if aa:
                alpha = max(0.0, min(1.0, (radius - dist + 0.5)))
                set_px(int(cx)+dx, int(cy)+dy, r, g, b, clamp(alpha * a))
            elif dist <= radius:
                set_px(int(cx)+dx, int(cy)+dy, r, g, b, a)

def fill_rect(x0, y0, x1, y1, r, g, b, a=255):
    for y in range(y0, y1):
        for x in range(x0, x1):
            set_px(x, y, r, g, b, a)

def fill_ellipse(cx, cy, rx, ry, r, g, b, a=255):
    for dy in range(-int(ry)-2, int(ry)+2):
        for dx in range(-int(rx)-2, int(rx)+2):
            nx = dx / rx
            ny = dy / ry
            dist = math.sqrt(nx*nx + ny*ny)
            alpha = max(0.0, min(1.0, (1.0 - dist + 0.5/rx)))
            if alpha > 0:
                set_px(int(cx)+dx, int(cy)+dy, r, g, b, clamp(alpha * a))

# ── 2. White heart ────────────────────────────────────────────────────────────
# Heart: two circles + rotated square
heart_cx = W // 2
heart_cy = H // 2 + 20   # slightly below centre
hs = 210   # half-size of heart

def in_heart(x, y, cx, cy, size):
    """Returns 0..1 alpha for a heart shape centred at cx,cy with given half-size."""
    # translate & normalise to -1..1
    nx = (x - cx) / size
    ny = (y - cy) / size
    # standard heart curve: (x²+y²-1)³ - x²y³ < 0  (ny flipped because screen-y is down)
    ny = -ny + 0.15   # shift so heart points down
    val = (nx*nx + ny*ny - 1)**3 - nx*nx * ny**3
    # smooth edge
    # approximate gradient magnitude ~ 1, so use val directly
    t = -val / 0.06
    return max(0.0, min(1.0, t))

heart_r, heart_g, heart_b = 255, 255, 255
for y in range(H):
    for x in range(W):
        alpha = in_heart(x, y, heart_cx, heart_cy, hs)
        if alpha > 0:
            set_px(x, y, heart_r, heart_g, heart_b, clamp(alpha * 255))

# ── 3. Coral baby face inside heart ──────────────────────────────────────────
face_cx = heart_cx
face_cy = heart_cy - 30
face_r  = 115

# face circle (coral, solid)
fill_ellipse(face_cx, face_cy, face_r, face_r, 0xFF, 0x8C, 0x8C, 255)

# cheeks (lighter blush circles)
fill_ellipse(face_cx - 68, face_cy + 20, 30, 20, 0xFF, 0xAA, 0xAA, 180)
fill_ellipse(face_cx + 68, face_cy + 20, 30, 20, 0xFF, 0xAA, 0xAA, 180)

# eyes (white circles with dark pupils)
for ex, ey in [(face_cx - 38, face_cy - 18), (face_cx + 38, face_cy - 18)]:
    fill_circle(ex, ey, 18, 255, 255, 255, 255)
    fill_circle(ex, ey, 9,  50,  30,  30,  255)
    # eye shine
    fill_circle(ex + 5, ey - 5, 4, 255, 255, 255, 255)

# smile (arc drawn as filled ellipse bottom half)
sm_cx, sm_cy = face_cx, face_cy + 35
sm_rx, sm_ry = 42, 22
for dy in range(0, sm_ry + 8):
    for dx in range(-sm_rx - 4, sm_rx + 4):
        nx = dx / sm_rx
        ny = dy / sm_ry
        dist = math.sqrt(nx*nx + ny*ny)
        # ring: 0.75..1.0
        inner = max(0.0, min(1.0, (dist - 0.72) / 0.04))
        outer = max(0.0, min(1.0, (1.04 - dist) / 0.04))
        alpha = inner * outer
        if alpha > 0:
            set_px(sm_cx + dx, sm_cy + dy, 180, 60, 60, clamp(alpha * 240))

# small dots decoration (white, scattered around heart)
dot_positions = [
    (heart_cx - 260, heart_cy - 200, 18),
    (heart_cx + 270, heart_cy - 190, 14),
    (heart_cx - 300, heart_cy + 80,  12),
    (heart_cx + 290, heart_cy + 100, 16),
    (heart_cx - 180, heart_cy + 280, 10),
    (heart_cx + 190, heart_cy + 270, 12),
]
for dx, dy, dr in dot_positions:
    fill_circle(dx, dy, dr, 255, 255, 255, 180)

# ── PNG encode ────────────────────────────────────────────────────────────────
def make_png(pixels, width, height):
    def chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', c)

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    # Use RGB (drop alpha) — AppIcon should be opaque; background already handles shape
    # Actually keep RGBA so the squircle transparency is preserved in the catalog
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))  # 6=RGBA

    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type None
        raw.extend(pixels[y * width * 4:(y + 1) * width * 4])

    idat = chunk(b'IDAT', zlib.compress(bytes(raw), 6))
    iend = chunk(b'IEND', b'')
    return sig + ihdr + idat + iend

out_dir = "iBru/Assets.xcassets/AppIcon.appiconset"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "AppIcon.png")

png_data = make_png(pixels, W, H)
with open(out_path, "wb") as f:
    f.write(png_data)

print(f"Written {len(png_data):,} bytes → {out_path}")
