# Conjunct Placement Pad

An interactive tool for calibrating exactly where a below-base ("blwf")
consonant sits under its base consonant in **MAATAA Brahmi Stacked** (see
`BRAHMI_FONT_STACKED.md`). `build_stacked.py` currently places every
below-base form with one formula (self-centered scaled copy, GPOS-shifted
by half the base's advance width) — this pad exists to check that formula
against the eye, pair by pair, and to record exceptions.

Published as a Claude Artifact with the `db` and `downloads` runtime
capabilities:
- **Drag** the stacked (red) glyph to move it, its top-right handle to
  resize it, and the handle above it to rotate it — all three write back
  into `scale` / `rotation` / `dxOffset` / `dyOffset`, exactly the
  parameters `build_stacked.py` already computes per base consonant.
- **Base size** additionally shrinks the base (blue) consonant itself in
  place, per the stated design rule: both letters a little smaller than
  their normal full size, but the pair together only a little taller than
  one letter alone — not the ~1.6x span you get from a full-size base plus
  a merely-scaled-down stacked form. The "Combined vs 1 letter" readout is
  the number that rule is about (defaults land around 1.25-1.3x); it turns
  red outside a "still reads as a little bigger" range.
- **Save this pair** stores a per-(base, stacked) override, including
  `baseScale`, in the artifact's shared database
  (`pairs/<baseHex>-<stackHex>`); **Save as global default** stores a
  fallback used by any pair without its own override (`config/global`).
- The saved rules live-recompose six real dhaatu roots (gam, paTh, likh,
  sthA, kram, jña) at the bottom of the page, using the same
  virama-then-consonant detection `build_stacked.py`'s font logic uses,
  so a calibration change is visible on real words immediately.
- **Export config JSON** downloads `{global, pairs}` in the shape
  `build_stacked.py` should read back in to replace its one-size formula
  with per-pair calibrated values, once enough pairs have been checked.
- A **Devanagari reference** sits beside the stage, and above every dhaatu
  card: the same consonants, real Devanagari shaping, for comparison —
  since the stacking convention being calibrated here was borrowed from
  Devanagari in the first place. It is derived from the exact same `cps`
  arrays as the Brahmi rendering (Brahmi's classical consonant order
  matches Devanagari's position-for-position, so `CONS_ORDER`'s index maps
  directly onto a Devanagari consonant table), not typed by hand — so it
  can't drift out of sync with what's actually being rendered in Brahmi.
- **Mode: Single pair / Sheet: fix stacked / Sheet: fix base** — calibrating
  one of 33×33 possible pairs at a time doesn't scale, so the two sheet
  modes fix one letter and show it against all 33 of the other kind at
  once, all 33 sharing the SAME base-size/stacked-size/rotation/nudge
  sliders: move one slider and all 33 cells update live together. Each
  cell shows its own Devanagari reference and its own combined-ratio
  number, with a red outline on any cell outside the "reads as a little
  bigger" band, so an outlier is visible at a glance instead of requiring
  a pair-by-pair walk. "Save for all 33 bases" (fix-stacked mode) or
  "Save for all 33 stacked letters" (fix-base mode) writes one rule to
  `stackDefaults/<hex>` or `baseDefaults/<hex>`. Precedence when resolving
  a specific (base, stacked) pair's actual parameters is: an exact pair
  override first, then a stacked-letter default, then a base-letter
  default, then the plain global default — so a sheet-level rule is a
  wide-but-overridable default, not a hard rule.

## Files

- `extract_glyphs.py` — pulls real outlines (SVG path data), advance
  widths, and bounding boxes for the 33 classical consonants
  (U+11013-U+11033), VIRAMA (U+11046), and vowel signs AA/I/U straight out
  of `assets/fonts/NotoSansBrahmi-Regular.ttf` via fontTools'
  `SVGPathPen`/`BoundsPen` — nothing here invents a shape. Writes
  `glyphs.json`.
- `glyphs.json` — the extracted data (regeneratable; committed for
  convenience).
- `pad.py` — embeds `glyphs.json` into the HTML/JS template and writes
  `pad.html`. Edit the template inside this file, not `pad.html` directly.
- `pad.html` — the generated, self-contained page (published as the
  Artifact).

## Regenerating

```
python3 extract_glyphs.py   # refresh glyphs.json from the font
python3 pad.py               # rebuild pad.html from glyphs.json
```

## Coordinate space

All values are font units at 1000 UPM, matching `build_stacked.py`'s
space exactly (`S` = scale, `DY_TOP` = vertical placement of the scaled
glyph's top) — an exported config's numbers drop straight into that
script's per-base `advances`/`shift` computation without unit conversion.

## Calibration notes (checked against the Devanagari reference)

Checked the three real conjunct pairs the dhaatu preview actually uses,
against their Devanagari reference render, at the global default
(baseScale 0.85, scale 0.5, dyOffset 60):

- **KA + RA** (क्र) — combined ratio 1.32×. RA's Brahmi letterform is a
  plain vertical stroke (no curve), so scaled down it just hangs as a
  short bar centered under KA's cross-shape. Reads cleanly, no overlap —
  KA has no stroke near the baseline for it to collide with.
- **SA + THA** (स्थ) — 1.26×. SA's own lower loop comes close to the
  baseline, so the stacked THA's top edge just touches it. Reads as a
  join, not a collision.
- **JA + NYA** (ज्ञ) — 1.32×. Same effect as SA+THA: JA's lower curve
  touches NYA's top. Also reads fine.

Conclusion: the global default generalizes across a straight-stroke base
(KA), a looped base (SA), and a curved base (JA) without a per-pair
override — all three land in the 1.26-1.32× "a little bigger than one
letter" band. The baseline-touching on looped bases is a side effect of
`dyOffset` (stacked form starts slightly above the baseline) meeting a
base whose own outline already reaches close to y=0 — expected, and it
reads as a natural join rather than a defect. Revisit with a per-pair
override only if a specific base's touch looks like a genuine collision
once more pairs are checked (SA/JA-like rounded-bottom consonants are the
ones to watch: DA, DHA, NA, GA, PHA, VA, HA all have curves that reach
near the baseline the same way).
