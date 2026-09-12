#!/usr/bin/env python3
"""
Derivative of Noto Sans Brahmi that stacks conjunct consonants the way the
user described (Devanagari-style, not Brahmi's own native convention):
when VIRAMA is immediately followed by a consonant, that consonant is
rendered as a small form positioned below the preceding consonant, instead
of Brahmi's native flat "consonant + visible virama stroke + consonant"
sequence.

All letterform outlines are copied directly from the real Noto Sans Brahmi
font (SIL OFL) -- nothing is invented. Only the below-base ("blwf") forms
are new glyphs, and they are scaled/repositioned copies of the same real
outlines, not new shapes.

This intentionally REPLACES Noto's own GSUB/GPOS (which includes a few
hardcoded classical ligatures, e.g. j+virama+nya -> the fused jna glyph)
with one uniform rule covering all 33 consonants. That is a deliberate
trade-off: this font no longer renders jna as Noto's special fused
ligature -- it renders it (like every other cluster) as the first
consonant with the second stacked below, per the requested rule.
"""
import unicodedata
from fontTools.ttLib import TTFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.feaLib.builder import addOpenTypeFeatures

SRC = "/mnt/user-data/uploads/Documents/Repos/allb.xyz/assets/fonts/NotoSansBrahmi-Regular.ttf"
OUT = "/home/claude/brahmi_font/MAATAA-Brahmi-Stacked.ttf"
FEA = "/home/claude/brahmi_font/stacked.fea"

src = TTFont(SRC)
src_glyphs = src.getGlyphSet()
src_hmtx = src["hmtx"]
cmap = src.getBestCmap()

UPM = src["head"].unitsPerEm  # 1000

def gname(cp):
    return f"u{cp:05X}"

# ---- copy every Brahmi-block code point's real outline under a new name ----
glyph_order = [".notdef", "space"]
outlines = {}   # name -> TTGlyph
advances = {}   # name -> (width, lsb)

def copy_outline(src_name, dest_glyphset_for_pen):
    pen = TTGlyphPen(dest_glyphset_for_pen)
    src_glyphs[src_name].draw(pen)
    return pen.glyph()

def transformed_outline(src_name, matrix, dest_glyphset_for_pen):
    pen = TTGlyphPen(dest_glyphset_for_pen)
    tpen = TransformPen(pen, matrix)
    src_glyphs[src_name].draw(tpen)
    return pen.glyph()

placeholder_glyphset = {}  # TTGlyphPen only needs .keys() style access for components; we use none (no composite glyphs)

outlines[".notdef"] = copy_outline(".notdef", placeholder_glyphset)
advances[".notdef"] = src_hmtx[".notdef"]
outlines["space"] = copy_outline("space", placeholder_glyphset)
advances["space"] = src_hmtx["space"]

for cp in range(0x11000, 0x11080):
    name = gname(cp)
    glyph_order.append(name)
    if cp in cmap:
        sname = cmap[cp]
        outlines[name] = copy_outline(sname, placeholder_glyphset)
        advances[name] = src_hmtx[sname]
    else:
        outlines[name] = TTGlyphPen(placeholder_glyphset).glyph()  # empty -- genuinely unassigned code point
        advances[name] = (500, 0)

# ---- consonants KA..HA (U+11013-U+11033), the real classical 33 ----
CONS_LO, CONS_HI = 0x11013, 0x11033
consonants = [cp for cp in range(CONS_LO, CONS_HI + 1)]

S = 0.55         # scale for the below-base (subjoined) form
DY_TOP = -40     # where the scaled glyph's top (cap height) lands, just under baseline

# Each blwf glyph is built SELF-CENTERED at local x=0 (its own scaled bbox
# is symmetric about the origin), so positioning it under any base consonant
# is a single horizontal shift that depends only on that base's own advance
# width (see the GPOS 'kern' block below) -- not on a fixed guess, and not
# on a per-(C1,C2) combinatorial table.
blwf_names = []
for cp in consonants:
    base = gname(cp)
    bname = base + ".blwf"
    sname = cmap[cp]
    bounds_pen = BoundsPen(src_glyphs)
    src_glyphs[sname].draw(bounds_pen)
    xmin, ymin, xmax, ymax = bounds_pen.bounds
    x_center = (xmin + xmax) / 2
    dx = -S * x_center          # center the scaled shape on local x=0
    dy = DY_TOP - S * 714        # same vertical placement for every consonant
    matrix = (S, 0, 0, S, dx, dy)
    outlines[bname] = transformed_outline(sname, matrix, placeholder_glyphset)
    advances[bname] = (0, 0)   # zero-width: it rides under the previous glyph, doesn't advance the pen
    glyph_order.append(bname)
    blwf_names.append((base, bname))

# ---- assemble the font ----
fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(glyph_order)
fb.setupCharacterMap({cp: gname(cp) for cp in range(0x11000, 0x11080)} | {0x20: "space"})
fb.setupGlyf(outlines)
fb.setupHorizontalMetrics(advances)
fb.setupHorizontalHeader(ascent=src["hhea"].ascent, descent=src["hhea"].descent)
fb.setupNameTable({
    "familyName": "MAATAA Brahmi Stacked",
    "styleName": "Regular",
    "uniqueFontIdentifier": "MAATAA Brahmi Stacked Regular 1.0",
    "fullName": "MAATAA Brahmi Stacked Regular",
    "version": "Version 1.0",
    "psName": "MAATAABrahmiStacked-Regular",
})
fb.setupOS2(sTypoAscender=src["hhea"].ascent, sTypoDescender=src["hhea"].descent,
            usWinAscent=src["hhea"].ascent, usWinDescent=-src["hhea"].descent)
fb.setupPost()
fb.font.save(OUT)
print(f"base font saved: {OUT}  ({len(glyph_order)} glyphs)")

# ---- add the GSUB stacking rule via a real .fea feature file ----
virama_name = gname(0x11046)
lines = ["languagesystem DFLT dflt;", "languagesystem brah dflt;", "",
         "# ccmp (not blwf/half) because HarfBuzz's generic shaper only",
         "# auto-applies the always-on feature set (ccmp, liga, rlig, calt,",
         "# locl, mark, mkmk, ...) for scripts outside its Indic/USE complex-",
         "# shaper list. blwf/half/pref are Indic-shaper-only features and",
         "# never fire here -- confirmed empirically: they were silently",
         "# ignored. Noto's own jna ligature is tagged ccmp for the same reason.",
         "feature ccmp {"]
for base, bname in blwf_names:
    lines.append(f"    sub {virama_name} {base} by {bname};")
lines.append("} ccmp;")
with open(FEA, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"wrote {FEA} ({len(blwf_names)} rules)")

# ---- GPOS: shift the stacked glyph to sit exactly centered under its base ----
# The blwf glyph is self-centered at local x=0 and has zero advance width,
# so after C1 it lands with its center exactly at C1's right edge. To put
# that center at C1's own horizontal midpoint instead, shift it left by
# half of C1's real advance width -- a single number per base consonant,
# not per (C1, C2) pair, because the blwf shape is already centered on
# itself. Uses 'kern' (not 'dist'/'blwm') for the same reason 'ccmp' was
# needed above: it's on HarfBuzz's generic always-on feature list.
blwf_class = " ".join(bname for _, bname in blwf_names)
gpos_lines = ["", "@BlwfForms = [" + blwf_class + "];", "", "feature kern {"]
for cp in consonants:
    base = gname(cp)
    base_width = advances[base][0]
    shift = -round(base_width / 2)
    gpos_lines.append(f"    pos {base} @BlwfForms' <{shift} 0 0 0>;")
gpos_lines.append("} kern;")

with open(FEA, "a") as f:
    f.write("\n".join(gpos_lines) + "\n")
print(f"appended GPOS centering rules for {len(consonants)} bases")

final = TTFont(OUT)
addOpenTypeFeatures(final, FEA)
final.save(OUT)
print("GSUB 'ccmp' + GPOS 'kern' compiled and saved.")
