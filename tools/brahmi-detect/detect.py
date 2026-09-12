#!/usr/bin/env python3
"""
Brahmi script detector for manuscript / rock-inscription photos.

Three-stage pipeline, in one pass over the image:
  1. CLASSIFY  -- does this image contain Brahmi-like glyph shapes at all?
  2. LOCALIZE  -- where are the individual glyph-like regions (boxes)?
  3. TRANSCRIBE -- best-guess Unicode Brahmi code point per region, ordered
     into reading lines, with a confidence score per character.

Method: classical image processing + shape matching against
reference_shapes.npz (real Noto Sans Brahmi outlines), NOT a trained
neural OCR model -- there is no labeled dataset of real historical Brahmi
inscriptions available to train on. This is an honest first-pass
prototype: it will do reasonably on clean, well-lit, printed-style Brahmi
and give a rough starting transcription on real photos, but real carved
or handwritten letterforms vary by century and region in ways one
digital reference font cannot fully capture. Treat low-confidence
characters (flagged in the output) as "needs a human eye", not fact.

Usage:
    python3 detect.py <image_path> [--out-dir DIR]

Writes into --out-dir (default: alongside the input image, in
<name>_detected/):
    annotated.png   -- boxes drawn, colored by confidence, guess labeled
    report.json      -- full structured result
    transcription.txt -- the best-guess line-by-line Brahmi text,
                          plus its Devanagari cross-check reading
"""
import sys
import os
import json
import argparse
import numpy as np
import cv2
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REF_PATH = os.path.join(HERE, "reference_shapes.npz")
NORM_SIZE = 64

# Same Brahmi-order -> Devanagari mapping used in the placement pad, for a
# quick human-readable cross-check of the guessed transcription. Only
# covers the 33 classical consonants + a few vowel signs; anything else
# in the guess is left as its Brahmi name.
CONS_ORDER = [f"{cp:05X}" for cp in range(0x11013, 0x11034)]
DEV_CONS = ["क","ख","ग","घ","ङ","च","छ","ज","झ","ञ","ट","ठ","ड","ढ","ण","त","थ","द","ध","न","प","फ","ब","भ","म","य","र","ल","व","श","ष","स","ह"]
DEV_VOWEL_SIGNS = {"11038": "ा", "1103A": "ि", "1103C": "ु", "11046": "्"}

def dev_for(hexcode):
    if hexcode in CONS_ORDER:
        return DEV_CONS[CONS_ORDER.index(hexcode)]
    return DEV_VOWEL_SIGNS.get(hexcode, "")


def load_reference(categories=None):
    """categories=None loads everything. Otherwise keeps only reference
    shapes whose category (see reference_shapes.py's category_for) is in
    the given set. Default detection use restricts to letter-like
    categories (consonants, independent vowels, vowel signs/virama) --
    Brahmi's number/digit glyphs include plain geometric shapes (a
    cross, straight strokes) that shape-match confusingly well against
    ordinary consonant strokes, and real inscriptions are overwhelmingly
    letters. --all-categories on the CLI restores the full 115-shape
    pool for text that may genuinely contain numerals or punctuation."""
    d = np.load(REF_PATH)
    hexes, names, cats, bitmaps = d["hexes"], d["names"], d["cats"], d["bitmaps"].astype(np.float32)
    if categories is not None:
        keep = np.isin(cats, list(categories))
        hexes, names, cats, bitmaps = hexes[keep], names[keep], cats[keep], bitmaps[keep]
    return hexes, names, cats, bitmaps


LETTER_CATEGORIES = {"consonant", "independent_vowel", "vowel_sign_or_virama"}


def preprocess(image_path):
    """Grayscale -> denoise -> CLAHE (local contrast normalization, which
    also flattens a lot of uneven lighting on its own) -> try several
    thresholding strategies and keep whichever gives the most solid
    (non-hollow), glyph-shaped ink regions.

    A single threshold strategy isn't robust across both clean/evenly-lit
    input and a genuinely unevenly-lit rock/manuscript photo: adaptive
    thresholding with a small block size tends to hollow out strokes that
    are wider than the block (each stroke's own interior gets locally
    averaged into "background", leaving two thin parallel outline-lines
    instead of one solid stroke) -- caught here by testing on a synthetic
    photo, where global Otsu on the CLAHE-normalized image gave clean
    solid strokes but a small-block adaptive threshold gave hollow
    outlines. Global Otsu alone will still fail on strong real lighting
    gradients adaptive thresholding exists to handle, so several
    candidates (global Otsu, and adaptive at two block sizes) are tried
    in both polarities, and the best is picked in two steps:
      1. keep only the polarity where ink is the minority of the image
         area (real ink/carving normally covers much less area than open
         page/stone background -- this rules out picking "background" as
         the foreground class);
      2. among those, pick whichever has the LOWEST "close-growth-ratio"
         on its plausible-sized components -- i.e. how much each
         component's area grows under a small morphological close. A
         solid stroke barely changes; a hollowed-out outline grows a lot
         once its interior gap gets closed. Lowest growth = most solid.
    Returns (original_bgr, binary) where binary has ink=255 on a 0
    background regardless of the source image's original polarity."""
    bgr = cv2.imread(image_path, cv2.IMREAD_COLOR)
    if bgr is None:
        raise FileNotFoundError(f"could not read image: {image_path}")
    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    gray = cv2.fastNlMeansDenoising(gray, h=10)
    gray = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8)).apply(gray)
    img_area = gray.shape[0] * gray.shape[1]

    candidates = []
    _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    candidates.append(otsu)
    candidates.append(cv2.bitwise_not(otsu))
    for block in (max(15, (min(gray.shape) // 20) | 1), max(25, (min(gray.shape) // 6) | 1)):
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, block, 5
        )
        candidates.append(thresh)
        candidates.append(cv2.bitwise_not(thresh))

    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))

    def ink_fraction(binary):
        return (binary > 0).sum() / img_area

    def solidity_score(binary):
        """Lower is more solid (less hollow). None if no plausible components."""
        n, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
        areas = stats[1:, cv2.CC_STAT_AREA]
        idx = np.where((areas > img_area * 0.0002) & (areas < img_area * 0.05))[0] + 1
        if len(idx) == 0:
            return None
        growth = []
        for i in idx:
            comp = (labels == i).astype(np.uint8) * 255
            closed = cv2.morphologyEx(comp, cv2.MORPH_CLOSE, close_kernel)
            a0 = max((comp > 0).sum(), 1)
            a1 = (closed > 0).sum()
            growth.append(a1 / a0)
        return float(np.mean(growth))

    # step 1: ink should be the minority of the frame; fall back to all
    # candidates if every one is >50% ink (e.g. a dense block of text).
    minority = [c for c in candidates if ink_fraction(c) < 0.5]
    pool = minority if minority else candidates

    # step 2: among those, the most solid (lowest growth ratio); skip any
    # with no plausible components at all.
    scored = [(solidity_score(c), c) for c in pool]
    scored = [(s, c) for s, c in scored if s is not None]
    binary = min(scored, key=lambda sc: sc[0])[1] if scored else pool[0]

    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, np.ones((2, 2), np.uint8))
    return bgr, binary


def find_candidates(binary):
    """Connected-component regions filtered to plausible glyph size/shape.
    Returns list of (x, y, w, h)."""
    n, labels, stats, centroids = cv2.connectedComponentsWithStats(binary, connectivity=8)
    img_area = binary.shape[0] * binary.shape[1]
    boxes = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area < img_area * 0.00015 or area > img_area * 0.06:
            continue
        aspect = w / max(h, 1)
        if aspect > 4 or aspect < 0.15:
            continue
        boxes.append((x, y, w, h))
    return boxes


def normalize_region(binary, box):
    x, y, w, h = box
    crop = binary[y:y+h, x:x+w]
    side = max(w, h)
    pad = np.zeros((side, side), dtype=np.uint8)
    oy, ox = (side - h) // 2, (side - w) // 2
    pad[oy:oy+h, ox:ox+w] = crop
    return cv2.resize(pad, (NORM_SIZE, NORM_SIZE), interpolation=cv2.INTER_AREA).astype(np.float32)


def match_best(region, ref_bitmaps, ref_hexes, ref_names, top_k=3):
    """Normalized cross-correlation of the candidate against every
    reference shape. Cheap and effective for a small (~115-way), roughly
    pre-aligned classification problem like this one."""
    r = region - region.mean()
    r_norm = np.linalg.norm(r) or 1.0
    refs = ref_bitmaps - ref_bitmaps.mean(axis=(1, 2), keepdims=True)
    ref_norms = np.linalg.norm(refs.reshape(len(refs), -1), axis=1)
    ref_norms[ref_norms == 0] = 1.0
    scores = (refs.reshape(len(refs), -1) @ r.flatten()) / (ref_norms * r_norm)
    order = np.argsort(-scores)[:top_k]
    return [(ref_hexes[i], ref_names[i], float(scores[i])) for i in order]


def cluster_into_lines(boxes, line_thresh_frac=0.6):
    """Group boxes into reading lines by vertical position, then order
    each line left-to-right. line_thresh_frac is relative to median box
    height -- boxes whose vertical centers are within that band are the
    same line."""
    if not boxes:
        return []
    heights = [h for (_, _, _, h) in boxes]
    med_h = float(np.median(heights))
    items = sorted(boxes, key=lambda b: b[1] + b[3] / 2)
    lines = []
    current = [items[0]]
    current_y = items[0][1] + items[0][3] / 2
    for b in items[1:]:
        cy = b[1] + b[3] / 2
        if abs(cy - current_y) <= med_h * line_thresh_frac:
            current.append(b)
        else:
            lines.append(current)
            current = [b]
        current_y = cy
    lines.append(current)
    return [sorted(line, key=lambda b: b[0]) for line in lines]


# Calibrated against test_synthetic.py: on a synthetic "photographed"
# line of 8 clean-font Brahmi consonants (denoise+CLAHE+rotation+grain
# distortion, no real historical letterform variation), correct top-1
# matches scored 0.64-0.90 and the one wrong match (a plain cross shape
# mismatched against a similarly-shaped numeral) still scored 0.81 --
# so this score is a much better signal for "does this look like an
# inked/carved glyph at all" (classification) than for "is this exact
# letter identification right" (transcription); treat CONFIDENCE_OK as
# a floor for "plausible glyph," not a guarantee of a correct label.
# Real carved/handwritten letterforms will very likely score lower and
# separate less cleanly than this clean synthetic case -- recalibrate
# both thresholds once real sample images are available.
CONFIDENCE_OK = 0.35
CONFIDENCE_LOW = 0.20


def detect(image_path, out_dir=None, categories=LETTER_CATEGORIES):
    ref_hexes, ref_names, ref_cats, ref_bitmaps = load_reference(categories)
    bgr, binary = preprocess(image_path)
    boxes = find_candidates(binary)
    lines = cluster_into_lines(boxes)

    results = []
    for line in lines:
        line_results = []
        for box in line:
            region = normalize_region(binary, box)
            matches = match_best(region, ref_bitmaps, ref_hexes, ref_names)
            best_hex, best_name, best_score = matches[0]
            line_results.append({
                "box": [int(v) for v in box],
                "best_hex": str(best_hex), "best_name": str(best_name), "score": round(best_score, 3),
                "alternatives": [{"hex": str(h), "name": str(n), "score": round(s, 3)} for h, n, s in matches[1:]],
            })
        results.append(line_results)

    all_scores = [c["score"] for line in results for c in line]
    n_candidates = len(all_scores)
    n_confident = sum(1 for s in all_scores if s >= CONFIDENCE_OK)
    looks_like_brahmi = n_candidates > 0 and (n_confident / n_candidates) >= 0.3
    classification = {
        "looks_like_brahmi": bool(looks_like_brahmi),
        "n_candidate_regions": n_candidates,
        "n_confident_matches": n_confident,
        "confidence_fraction": round(n_confident / n_candidates, 3) if n_candidates else 0.0,
    }

    # ---- annotate ----
    annotated = bgr.copy()
    for line in results:
        for c in line:
            x, y, w, h = c["box"]
            score = c["score"]
            color = (0, 200, 0) if score >= CONFIDENCE_OK else ((0, 165, 255) if score >= CONFIDENCE_LOW else (0, 0, 255))
            cv2.rectangle(annotated, (x, y), (x + w, y + h), color, 2)
            cv2.putText(annotated, c["best_name"].replace("BRAHMI LETTER ", "").replace("BRAHMI ", "")[:4],
                        (x, max(0, y - 4)), cv2.FONT_HERSHEY_SIMPLEX, 0.35, color, 1, cv2.LINE_AA)

    # ---- transcription ----
    transcription_lines = []
    dev_lines = []
    for line in results:
        chars = []
        dev_chars = []
        for c in line:
            ch = chr(int(c["best_hex"], 16))
            if c["score"] < CONFIDENCE_LOW:
                chars.append(f"[{ch}?]")
            else:
                chars.append(ch)
            dev_chars.append(dev_for(c["best_hex"]) or "?")
        transcription_lines.append("".join(chars))
        dev_lines.append("".join(dev_chars))

    if out_dir is None:
        base = os.path.splitext(image_path)[0]
        out_dir = base + "_detected"
    os.makedirs(out_dir, exist_ok=True)

    cv2.imwrite(os.path.join(out_dir, "annotated.png"), annotated)
    cv2.imwrite(os.path.join(out_dir, "binary.png"), binary)
    report = {
        "image": image_path,
        "classification": classification,
        "lines": results,
        "transcription_brahmi": transcription_lines,
        "transcription_devanagari_crosscheck": dev_lines,
        "notes": "Shape-matched against a single modern digital font (Noto Sans Brahmi). "
                 "Confidence >= %.2f shown green, >= %.2f amber, else red/bracketed as unreliable. "
                 "Real carved/historical letterform variation is NOT represented in the reference set." % (CONFIDENCE_OK, CONFIDENCE_LOW),
    }
    with open(os.path.join(out_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    with open(os.path.join(out_dir, "transcription.txt"), "w") as f:
        f.write("Brahmi (best guess, low-confidence chars in [brackets]):\n")
        for l in transcription_lines:
            f.write(l + "\n")
        f.write("\nDevanagari cross-check (consonants/vowel-signs only, '?' = no mapping):\n")
        for l in dev_lines:
            f.write(l + "\n")

    print(f"classification: {classification}")
    print(f"wrote {out_dir}/annotated.png, report.json, transcription.txt")
    return report


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out-dir", default=None)
    ap.add_argument("--all-categories", action="store_true",
                     help="also match against Brahmi numerals/digits/punctuation "
                          "(default: letters only -- consonants, independent vowels, vowel signs)")
    args = ap.parse_args()
    detect(args.image, args.out_dir, categories=None if args.all_categories else LETTER_CATEGORIES)
