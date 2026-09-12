#!/usr/bin/env python3
"""
Synthetic self-test for detect.py -- the sanity check to run BEFORE trusting
this on any real manuscript/rock-sample photo, and the source of the
CONFIDENCE_OK/CONFIDENCE_LOW comment in detect.py.

There is no real historical-Brahmi test set available. What this CAN prove:
the mechanism (preprocess -> segment -> normalize -> shape-match ->
line-cluster -> report) runs end-to-end and gets a clean, distorted-but-not
adversarial synthetic case right. What it can NOT prove: accuracy on real
carved/handwritten letterforms, which vary by century and region in ways
one modern digital reference font doesn't capture. Treat a pass here as
"the code works", not "the detector is accurate."

Regenerates synthetic_test.png (8 distinct Brahmi consonants, rendered
clean then denoised+CLAHE'd+rotated+grain-noised to roughly resemble a
photographed inscription -- see make_synthetic.py) and checks:
  - segmentation finds exactly 8 candidate regions (one per glyph -- catches
    both hollow-stroke over-splitting and cross-glyph merging regressions)
  - classification says looks_like_brahmi
  - all 8 top-1 transcription matches are correct (letters-only category
    filter; the full 115-shape pool including numerals is known to
    confuse plain-stroke letters against similarly-shaped numerals, which
    is exactly why detect() defaults to LETTER_CATEGORIES)
"""
import sys
import make_synthetic
import detect

def main():
    make_synthetic.main()
    report = detect.detect(make_synthetic.OUT_PATH, out_dir="synthetic_test_detected")

    ok = True
    n_regions = report["classification"]["n_candidate_regions"]
    if n_regions != len(make_synthetic.GROUND_TRUTH_HEX):
        print(f"FAIL: segmentation found {n_regions} regions, expected {len(make_synthetic.GROUND_TRUTH_HEX)}")
        ok = False

    if not report["classification"]["looks_like_brahmi"]:
        print("FAIL: classification did not flag this as Brahmi-like")
        ok = False

    line = report["lines"][0] if report["lines"] else []
    n_correct = 0
    for i, (gt_hex, cell) in enumerate(zip(make_synthetic.GROUND_TRUTH_HEX, line)):
        got = cell["best_hex"]
        if got == gt_hex:
            n_correct += 1
        else:
            print(f"  mismatch at position {i}: expected {gt_hex}, got {got} "
                  f"({cell['best_name']}, score {cell['score']:.3f})")
    print(f"transcription: {n_correct}/{len(make_synthetic.GROUND_TRUTH_HEX)} correct top-1 matches")
    if n_correct < len(make_synthetic.GROUND_TRUTH_HEX):
        ok = False

    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
