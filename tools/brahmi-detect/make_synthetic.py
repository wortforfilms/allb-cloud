#!/usr/bin/env python3
"""
Builds a synthetic "photographed inscription" test image to sanity-check
detect.py end-to-end BEFORE any real sample images arrive.

Renders a real short Brahmi phrase (independent letters, clean since
detect.py's candidate-region step doesn't need to understand conjuncts --
it just needs glyph-shaped ink blobs) at generous size, then distorts it to
roughly simulate a rock/manuscript photo: uneven lighting (a soft gradient
+ vignette), paper/stone-grain noise, slight rotation, and JPEG-ish blur.

This is NOT a substitute for real sample images -- it only proves the
mechanism (preprocess -> segment -> match -> line-cluster -> report) runs
and produces sane output on some input. Real accuracy is still unknown
until real photos arrive.
"""
import os
import numpy as np
import cv2
from PIL import Image, ImageFont, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
_FONT_CANDIDATES = [
    os.path.join(REPO_ROOT, "assets", "fonts", "NotoSansBrahmi-Regular.ttf"),  # tools/brahmi-detect/ in the repo
    "/mnt/user-data/uploads/Documents/Repos/allb.xyz/assets/fonts/NotoSansBrahmi-Regular.ttf",  # this session's sandbox copy
]
FONT_PATH = next((p for p in _FONT_CANDIDATES if os.path.exists(p)), _FONT_CANDIDATES[0])
OUT_PATH = os.path.join(HERE, "synthetic_test.png")

# A clean line of 8 distinct Brahmi consonants (KA GA CA TA PA YA VA SA),
# spread with normal word-gaps -- ground truth for checking the detector.
GROUND_TRUTH_HEX = ["11013", "11015", "11018", "1101F", "11028", "1102A", "1102D", "11030"]
GROUND_TRUTH_CHARS = [chr(int(h, 16)) for h in GROUND_TRUTH_HEX]

def render_clean_line(chars, font_size=160, pad=60, gap=40):
    font = ImageFont.truetype(FONT_PATH, size=font_size)
    imgs = []
    for ch in chars:
        tmp = Image.new("L", (font_size * 2, font_size * 2), 0)
        d = ImageDraw.Draw(tmp)
        d.text((font_size // 2, font_size // 2), ch, fill=255, font=font)
        arr = np.array(tmp)
        ys, xs = np.where(arr > 40)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        imgs.append(arr[y0:y1+1, x0:x1+1])
    h = max(im.shape[0] for im in imgs)
    total_w = sum(im.shape[1] for im in imgs) + gap * (len(imgs) - 1)
    canvas = np.zeros((h + 2 * pad, total_w + 2 * pad), dtype=np.uint8)
    x = pad
    for im in imgs:
        ih, iw = im.shape
        y = pad + (h - ih)  # baseline-align at bottom
        canvas[y:y+ih, x:x+iw] = im
        x += iw + gap
    return canvas  # 0 background, 255 ink (white glyphs on black)

def photographize(gray_ink_on_black):
    """Turn a clean white-ink-on-black render into something that looks
    roughly like a photo of dark ink on an aged, unevenly lit surface."""
    h, w = gray_ink_on_black.shape
    # ink dark on a light "stone/paper" background instead
    base = 200 - gray_ink_on_black.astype(np.int16) * 0.75
    base = np.clip(base, 0, 255).astype(np.uint8)

    # uneven lighting: soft gradient + vignette
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grad = 30 * (xx / w) - 15 * (yy / h)
    cy, cx = h / 2, w / 2
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / np.sqrt(cx ** 2 + cy ** 2)
    vignette = -35 * dist
    lit = base.astype(np.float32) + grad + vignette
    lit = np.clip(lit, 0, 255).astype(np.uint8)

    # surface grain noise
    noise = np.random.normal(0, 12, (h, w)).astype(np.float32)
    noisy = np.clip(lit.astype(np.float32) + noise, 0, 255).astype(np.uint8)

    # slight blur (soft focus / worn edges)
    blurred = cv2.GaussianBlur(noisy, (3, 3), 0.8)

    # slight rotation, expand canvas so nothing crops
    angle = -2.3
    M = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0)
    cos, sin = abs(M[0, 0]), abs(M[0, 1])
    nw, nh = int(h * sin + w * cos), int(h * cos + w * sin)
    M[0, 2] += (nw - w) / 2
    M[1, 2] += (nh - h) / 2
    rotated = cv2.warpAffine(blurred, M, (nw, nh), borderValue=180)

    return cv2.cvtColor(rotated, cv2.COLOR_GRAY2BGR)

def main():
    clean = render_clean_line(GROUND_TRUTH_CHARS)
    photo = photographize(clean)
    cv2.imwrite(OUT_PATH, photo)
    print(f"wrote {OUT_PATH}, shape {photo.shape}")
    print("ground truth (left to right):", GROUND_TRUTH_HEX)
    print("ground truth chars:", " ".join(GROUND_TRUTH_CHARS))

if __name__ == "__main__":
    main()
