#!/usr/bin/env python3
"""ほしよみ天文台のアイコン（1024x1024、透過なし）。紫紺の夜に真鍮の天球の縁、中に北斗七星と光る北極星、下に地球儀の弧。
使い方: python3 scripts/make-icon-observatory.py"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def hx(v):
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, low = hx("2A2250"), hx("0D0A1C")
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp(top, low, y / S))

cx, cy, R = S / 2, S / 2 - 30, 380
# 天球の地
sky = Image.new("RGB", (S, S), (0, 0, 0))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)
sd = ImageDraw.Draw(sky)
for r in range(int(R), 0, -2):
    sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=lerp(hx("0D0A1C"), hx("2A2250"), r / R))
img.paste(sky, (0, 0), mask)

# 天の川の霞
haze = Image.new("RGB", (S, S), (0, 0, 0))
hd = ImageDraw.Draw(haze)
hd.line([(cx - R, cy + 160), (cx + R, cy - 220)], fill=(70, 60, 110), width=150)
haze = haze.filter(ImageFilter.GaussianBlur(60))
hm = Image.new("L", (S, S), 0)
ImageDraw.Draw(hm).ellipse([cx - R, cy - R, cx + R, cy + R], fill=150)
img.paste(Image.blend(img, Image.eval(haze, lambda v: v), 1.0), (0, 0), Image.composite(hm, Image.new("L", (S, S), 0), hm).point(lambda v: v // 2))
d = ImageDraw.Draw(img)

# 地球儀の弧（下）
for i, a in enumerate([0.95, 0.7, 0.45]):
    rr = R * 0.95 + i * 2
    d.arc([cx - rr * 1.25, cy + R * 0.55, cx + rr * 1.25, cy + R * 0.55 + rr * 1.6], 200, 340, fill=lerp(hx("0D0A1C"), hx("C9A15B"), a), width=10)

# 北斗七星
dipper = [(-250, -40), (-150, -10), (-60, 40), (20, 30), (60, -60), (190, -40), (210, 70)]
pts = [(cx + x * 0.95, cy + y * 0.95 + 40) for x, y in dipper]
for a, b in [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 3)]:
    d.line([pts[a], pts[b]], fill=hx("8A6A32"), width=5)
for x, y in pts:
    d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=hx("F6F0DE"))

# 北極星（光る）
px, py = cx + 40, cy - 230
glow = Image.new("RGB", (S, S), (0, 0, 0))
ImageDraw.Draw(glow).ellipse([px - 90, py - 90, px + 90, py + 90], fill=(255, 207, 110))
glow = glow.filter(ImageFilter.GaussianBlur(45))
img = Image.composite(Image.blend(img, glow, 0.0), img, Image.new("L", (S, S), 0))
img = Image.fromarray if False else img
from PIL import ImageChops
img = ImageChops.add(img, Image.eval(glow, lambda v: int(v * 0.55)))
d = ImageDraw.Draw(img)
star = []
for i in range(10):
    a = i * math.pi / 5 - math.pi / 2
    r = 46 if i % 2 == 0 else 18
    star.append((px + r * math.cos(a), py + r * math.sin(a)))
d.polygon(star, fill=hx("FFE3A8"))

# 小さな星
import random
rng = random.Random(7)
for _ in range(60):
    a = rng.random() * 2 * math.pi
    r = math.sqrt(rng.random()) * (R - 30)
    x, y = cx + r * math.cos(a), cy + r * math.sin(a)
    s = rng.choice([2, 3, 3, 4])
    d.ellipse([x - s, y - s, x + s, y + s], fill=lerp(hx("2A2250"), hx("F6F0DE"), 0.4 + rng.random() * 0.5))

# 真鍮の縁と目盛り
for w, col in [(46, "8A6A32"), (38, "C9A15B"), (10, "EED9A4")]:
    off = R + 24
    d.ellipse([cx - off, cy - off, cx + off, cy + off], outline=hx(col), width=w if col != "EED9A4" else 4)
for k in range(72):
    a = k * math.pi / 36
    long = k % 9 == 0
    r1, r2 = R + 6, R + (36 if long else 22)
    d.line([(cx + r1 * math.cos(a), cy + r1 * math.sin(a)), (cx + r2 * math.cos(a), cy + r2 * math.sin(a))], fill=hx("4A3818"), width=6 if long else 3)

img.convert("RGB").save(OUT)
print("saved", OUT)
