# Brahmi Script Detector

A first-pass tool to point at a photo of a manuscript or a rock/stone
inscription and get back: does this look like it has Brahmi script on it
(**classify**), where are the individual letter-shaped marks
(**localize**), and a best-guess Unicode Brahmi transcription
(**transcribe**), line by line, with a confidence flag per character.

## What this is, honestly

This is **classical image processing + shape matching**, not a trained
neural OCR model. There is no labeled dataset of real historical/carved
Brahmi inscriptions to train on, and no off-the-shelf pretrained OCR
model for ancient Brahmi exists (unlike modern Indic scripts, which
Tesseract etc. do support). The approach: rasterize all 115 assigned
Brahmi Unicode code points from the real Noto Sans Brahmi font (the same
font used throughout this project) into normalized reference bitmaps,
then for an input photo — denoise, auto-threshold, segment into
candidate ink regions, normalize each to the same size, and match it
against all 115 references by normalized cross-correlation.

It will do reasonably on clean, well-lit, printed-style Brahmi. On a
real photographed inscription, expect it to give a rough starting
transcription that needs a human eye on anything it flags low-confidence
- real carved or handwritten letterforms vary by century and region in
ways one modern digital reference font cannot fully capture. **Accuracy
on real sample images is unproven until validated against them** — see
"Status" below.

## Files

- `reference_shapes.py` — rasterizes the 115 assigned Brahmi code points
  (U+11000-U+1107F) from `assets/fonts/NotoSansBrahmi-Regular.ttf` into
  normalized 64x64 binary bitmaps. Writes `reference_shapes.npz`
  (regeneratable; committed for convenience).
- `detect.py` — the three-stage pipeline. `python3 detect.py <image>
  [--out-dir DIR] [--all-categories]`. Writes `annotated.png` (boxes
  colored by confidence), `report.json` (full structured result), and
  `transcription.txt` (best-guess Brahmi + a Devanagari cross-check
  line) into `<name>_detected/` next to the input image by default.
- `make_synthetic.py` — builds a synthetic "photographed inscription"
  test image (a clean line of 8 distinct consonants, then denoised,
  CLAHE'd, lit unevenly, grain-noised, and rotated) since no real sample
  images were available yet when this was built.
- `test_synthetic.py` — runs the full pipeline against that synthetic
  image and checks segmentation count, classification, and per-letter
  transcription accuracy. **Run this before trusting any change to the
  pipeline.**

## How the pipeline works

1. **Preprocess** (`preprocess()`): grayscale, denoise, CLAHE (local
   contrast normalization — flattens a lot of uneven lighting on its
   own). Then several thresholding candidates are tried (global Otsu,
   and adaptive at two block sizes, each in both polarities) and the
   best one is picked in two steps: first keep only the polarity where
   ink covers a minority of the frame (real ink/carving is normally far
   less area than open page/stone), then among those pick whichever
   gives the most *solid* (least hollow) glyph-sized regions — measured
   by how much each region's area grows under a small morphological
   close. This two-step selection exists because a naive "most
   plausible-sized components" heuristic was fooled by adaptive
   thresholding hollowing out strokes into thin parallel outlines on a
   test image (see "Status" below) — solidity, not raw component count,
   is what actually separates a good threshold from a bad one.
2. **Segment** (`find_candidates`): connected-component analysis on the
   binary image, filtered to plausible glyph size/aspect ratio.
3. **Cluster into lines** (`cluster_into_lines`): groups candidate boxes
   into reading lines by vertical-center proximity, then orders each
   line left-to-right.
4. **Match** (`normalize_region` + `match_best`): each candidate is
   square-padded and resized to 64x64, then matched by normalized
   cross-correlation against the reference bitmaps. By default only
   letter-like categories (consonants, independent vowels, vowel
   signs/virama) are matched against — Brahmi's numeral glyphs include
   plain geometric shapes (a cross, a bare stroke) that shape-match
   confusingly well against ordinary letters, and real inscription text
   is overwhelmingly letters. Pass `--all-categories` to include
   numbers/digits/punctuation too.
5. **Report**: a classification verdict (`looks_like_brahmi`, based on
   what fraction of candidates matched confidently), the annotated
   image, and the transcription (bracketed `[x?]` for low-confidence
   characters), plus a Devanagari cross-check line using the same
   Brahmi-order-to-Devanagari-order mapping used in the placement pad.

## Status

Validated so far: `test_synthetic.py` passes end-to-end (8/8 candidate
regions found and correctly transcribed on the synthetic photographed
test). That proves the *mechanism* works — preprocessing, segmentation,
matching, and line-ordering all function together — not that it's
accurate on real inscriptions.

While building this, a genuine bug was caught by comparing threshold
strategies against the synthetic test: small-block adaptive
thresholding hollowed thick strokes into two thin parallel outlines,
which silently doubled/split some glyphs into extra fake candidate
regions. Fixed by the solidity-based threshold selection described
above (`preprocess()`).

`CONFIDENCE_OK = 0.35` / `CONFIDENCE_LOW = 0.20` in `detect.py` are
calibrated against that one synthetic case: correct top-1 matches
scored 0.64-0.90, but note the match score is a much better signal for
"this looks like *some* inked/carved glyph" than for "this exact letter
ID is right" — on the un-filtered 115-shape pool, a plain cross-shaped
consonant scored 0.81 against the *wrong* Brahmi numeral glyph before
the letter-only category filter was added. **Not yet validated**: real
carved/handwritten letterform variation, real lighting/texture/damage
conditions, or a second real script sample. Next step is running this
against the real manuscript/rock-sample images the user is going to
provide, then very likely retuning `preprocess()`'s denoising/CLAHE
parameters and the confidence thresholds against what real photos
actually look like.
