# Brahmi rendering — Noto Sans Brahmi

Status date: 2026-09-12. Fixes the terminal-rendering gap found while
explaining `maataa_shell`: `brahmi_tokenizer.rs` produces correct UTF-8 for
the full Brahmi block (U+11000–U+1107F), but most terminal fonts have no
glyphs for it, so the output rendered as tofu boxes.

## What's actually installed

**Noto Sans Brahmi**, the real Google/Noto Project font for this script —
`assets/fonts/NotoSansBrahmi-Regular.ttf`, SIL Open Font License 1.1
(`assets/fonts/NotoSansBrahmi-OFL.txt` is bundled alongside it, as the
license requires). It's installed into `~/Library/Fonts` on this Mac, so
Terminal.app/iTerm2 pick it up automatically via font fallback for any
Brahmi code point the active terminal font doesn't cover — no settings
change needed in Terminal.app; iTerm2 users who want to force it can set
it as the "non-ASCII font" in Profiles → Text.

Verified against real HarfBuzz (14.4.0, via `uharfbuzz`): 115 of the 128
code points in the Brahmi block are covered (the other 13 are code points
Unicode itself has never assigned a character to — not a font gap), and
sample text — independent vowels, a consonant + vowel-sign combination,
and the isolated combining marks (candrabindu/anusvara/visarga) — all
shape to real glyphs with zero `.notdef` fallbacks.

## Correction — an earlier version of this was wrong

The first pass at this built a from-scratch "font" out of invented
geometric shapes (a stem + combinations of bars/hooks/loops, procedurally
generated per code point) rather than actual Brahmi letterforms, on the
reasoning that I didn't trust my own memory to reproduce real epigraphic
shapes accurately. That reasoning doesn't hold up: real, correct Brahmi
letterforms already exist as a properly researched, openly licensed font
(Noto Sans Brahmi) — there was no need to invent placeholder shapes when
the real thing was one download away. That invented font
(`MAATAA-Brahmi-Sans.ttf`) has been deleted from both this repo and
`~/Library/Fonts`; Noto Sans Brahmi replaces it entirely.

## Files

- `assets/fonts/NotoSansBrahmi-Regular.ttf` — the font.
- `assets/fonts/NotoSansBrahmi-OFL.txt` — its license (SIL OFL 1.1),
  required to accompany redistributed copies.
