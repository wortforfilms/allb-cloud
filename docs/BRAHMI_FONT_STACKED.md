# MAATAA Brahmi Stacked — Devanagari-style conjunct stacking for Brahmi

Status date: 2026-09-12. Built on request: when a virama is immediately
followed by another consonant, that consonant should render small and
positioned *below* the first, with any following vowel-sign staying in its
own normal place — the composition rule Devanagari conjuncts use, applied
here to Brahmi even though it is not Brahmi's own native convention (its
native convention is a flat sequence: full-size consonants with a visible
virama stroke between them, and precomposed ligatures only for a
handful of classical clusters like jña — see `assets/fonts/preview.png` /
`BRAHMI_FONT.md` for how plain Noto Sans Brahmi renders these same roots).

## What's in the font

`assets/fonts/MAATAA-Brahmi-Stacked.ttf` is a derivative of Noto Sans
Brahmi. Every visible letterform is a **real Noto outline** — nothing is
invented (that mistake isn't being repeated). The only new glyphs are
`<consonant>.blwf`: the same real outline, scaled to 55% and shifted down
and left, used as a below-base subjoined form for all 33 classical
consonants (KA–HA).

A GSUB rule (`sub virama consonant by consonant.blwf;`, one line per
consonant — not a combinatorial pairwise table, since the rule only looks
at "does a virama immediately precede," regardless of what came before)
replaces `virama + consonant` with the small stacked form whenever a
virama is followed by another consonant. A virama at the end of a word
(nothing follows) is untouched and still renders as a visible mark, which
is correct — there's nothing to stack it under.

## The one genuinely tricky part: getting HarfBuzz to apply it at all

The standard OpenType tag for below-base forms is `blwf`, and that was
the first thing tried — it silently did nothing. Checked why: `blwf` (like
`half`, `pref`, `pstf`) is only auto-applied by HarfBuzz's Indic/Universal-
Shaping-Engine complex shaper, which Brahmi doesn't run through here.
Brahmi goes through the generic shaper, which only auto-applies the
always-on feature set (`ccmp`, `liga`, `rlig`, `calt`, `locl`, `mark`,
`mkmk`, a few others) regardless of script. Confirmed by inspecting Noto's
own GSUB: its jña ligature is tagged `ccmp`, not `blwf`, which is exactly
why it fires automatically. Retagging the new rule as `ccmp` fixed it —
verified with real HarfBuzz shaping (glyph count drops by exactly one for
every virama+consonant pair: `sthA` 4→3 glyphs, `kram` 5→4, `jñā` 4→3;
untouched for word-final viramas as expected).

## Verification method

Rendering this correctly needed a real two-stage pipeline — HarfBuzz to
shape (get the actual glyph IDs and positions after GSUB/GPOS), FreeType
to rasterize each resulting glyph *by glyph ID* and composite the bitmaps
at HarfBuzz's computed offsets (`assets/fonts/render_shaped.py`). Pillow's
plain `ImageFont.text()` was tried first and produces misleading output —
it maps characters to glyphs via cmap only, without reliably running the
substitution, so it doesn't show what the font actually does. This is the
same shape-then-rasterize pipeline a real terminal uses.

## Known limitation

The below-base form's position is a single fixed offset (tuned against
average consonant width), not a proper per-pair GPOS anchor — so centering
under a very narrow consonant (like DA) versus a very wide one (like SA)
isn't pixel-perfect. Good enough to see and verify the rule works; a
real anchor-based GPOS pass would be the next refinement if this needs to
look production-clean.

## Trade-off, stated plainly

This replaces Noto's own hardcoded classical ligatures (jña included) with
the uniform stacking rule for all 33 consonants. jña no longer renders as
Noto's fused glyph — it renders like every other cluster now, jn-small-
stacked-below-a. That's the deliberate consequence of asking for one
uniform rule instead of Brahmi's own mixed convention.

## Files

- `assets/fonts/MAATAA-Brahmi-Stacked.ttf` — the font.
- `assets/fonts/build_stacked.py` — builds it from the real Noto outlines.
- `assets/fonts/stacked.fea` — the compiled GSUB feature source.
- `assets/fonts/render_shaped.py` — the HarfBuzz+FreeType verification
  renderer (reusable for checking any future font change against real
  shaping instead of guessing from a screenshot).
