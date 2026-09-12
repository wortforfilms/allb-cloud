#!/usr/bin/env python3
"""
Builds the reference shape library the detector matches candidate regions
against: one normalized binary bitmap per assigned Brahmi code point
(U+11000-U+1107F), rasterized straight from the real Noto Sans Brahmi
font (SIL OFL) -- the same font used throughout this project's other
Brahmi work, so the reference shapes and everything else built earlier
(MAATAA Brahmi Stacked, the placement pad) stay consistent.

This is deliberately a CLASSICAL shape-matching approach, not a trained
neural OCR model: there is no labeled dataset of real historical/carved
Brahmi inscriptions available here to train on, and no off-the-shelf
pretrained model for ancient Brahmi exists (unlike modern Indic scripts,
which Tesseract etc. do support). Matching candidate regions against one
modern digital font's letterforms is a reasonable, honest starting point
-- it will work well on clean/printed-style Brahmi and give a rough first
pass on real inscriptions, but real carved/handwritten letterforms vary
by century and region in ways a single reference font cannot capture.
Calibrating against real sample images (once provided) is the next step.

Output: reference_shapes.npz -- for each assigned code point, a
NORM_SIZE x NORM_SIZE uint8 binary bitmap (255 = ink) plus its Unicode
name and category (vowel / consonant / vowel-sign / mark / punctuation /
number / digit), so the detector can report a human-readable label.
"""
import os
import numpy as np
import unicodedata
from PIL import Image, ImageFont, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
_FONT_CANDIDATES = [
    os.path.join(REPO_ROOT, "assets", "fonts", "NotoSansBrahmi-Regular.ttf"),  # tools/brahmi-detect/ in the repo
    "/mnt/user-data/uploads/Documents/Repos/allb.xyz/assets/fonts/NotoSansBrahmi-Regular.ttf",  # this session's sandbox copy
]
FONT_PATH = next((p for p in _FONT_CANDIDATES if os.path.exists(p)), _FONT_CANDIDATES[0])
OUT_PATH = os.path.join(HERE, "reference_shapes.npz")
RENDER_SIZE = 300      # px, generous canvas for rasterizing before cropping
NORM_SIZE = 64         # px, final normalized template size

def category_for(cp):
    if 0x11003 <= cp <= 0x11010: return "independent_vowel"
    if 0x11013 <= cp <= 0x11037: return "consonant"
    if 0x11038 <= cp <= 0x11046: return "vowel_sign_or_virama"
    if 0x11047 <= cp <= 0x11051: return "punctuation"
    if 0x11052 <= cp <= 0x11065: return "number"
    if 0x11066 <= cp <= 0x1106F: return "digit"
    return "other"

def rasterize(font, ch):
    img = Image.new("L", (RENDER_SIZE, RENDER_SIZE), 0)
    draw = ImageDraw.Draw(img)
    draw.text((RENDER_SIZE // 4, RENDER_SIZE // 4), ch, fill=255, font=font)
    arr = np.array(img)
    ys, xs = np.where(arr > 40)
    if len(xs) == 0:
        return None
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cropped = arr[y0:y1+1, x0:x1+1]
    h, w = cropped.shape
    side = max(h, w)
    pad = np.zeros((side, side), dtype=np.uint8)
    oy, ox = (side - h) // 2, (side - w) // 2
    pad[oy:oy+h, ox:ox+w] = cropped
    norm = np.array(Image.fromarray(pad).resize((NORM_SIZE, NORM_SIZE), Image.LANCZOS))
    _, binary = cv2_threshold(norm)
    return binary

def cv2_threshold(norm):
    import cv2
    _, binary = cv2.threshold(norm, 60, 255, cv2.THRESH_BINARY)
    return None, binary

def main():
    font = ImageFont.truetype(FONT_PATH, size=220)
    names, bitmaps, cats, hexes = [], [], [], []
    for cp in range(0x11000, 0x11080):
        try:
            name = unicodedata.name(chr(cp))
        except ValueError:
            continue  # genuinely unassigned code point
        bmp = rasterize(font, chr(cp))
        if bmp is None:
            continue
        hexes.append(f"{cp:05X}")
        names.append(name)
        cats.append(category_for(cp))
        bitmaps.append(bmp)
    bitmaps = np.stack(bitmaps)
    np.savez_compressed(OUT_PATH, hexes=np.array(hexes), names=np.array(names),
                         cats=np.array(cats), bitmaps=bitmaps)
    print(f"wrote {OUT_PATH}: {len(hexes)} reference shapes, bitmap {bitmaps.shape}")

if __name__ == "__main__":
    main()
