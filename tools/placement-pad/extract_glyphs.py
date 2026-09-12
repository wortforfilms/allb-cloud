#!/usr/bin/env python3
"""
Extracts real SVG path data + advance widths + bounding boxes for the 33
classical Brahmi consonants (U+11013-U+11033), VIRAMA (U+11046), and three
vowel signs (AA/I/U) from the real Noto Sans Brahmi font, for use by
pad.py / the Conjunct Placement Pad artifact.

Nothing here invents a letterform -- every path is copied directly out of
Noto Sans Brahmi's own outlines via fontTools' SVGPathPen, at the font's
native 1000 UPM, matching build_stacked.py's coordinate space exactly.
"""
import json
import unicodedata
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.boundsPen import BoundsPen

SRC = "assets/fonts/NotoSansBrahmi-Regular.ttf"
OUT = "glyphs.json"

CODEPOINTS = (
    list(range(0x11013, 0x11034))  # KA..HA, the 33 classical consonants
    + [0x11046]                     # VIRAMA
    + [0x11038, 0x1103A, 0x1103C]   # vowel signs AA, I, U
)

def main():
    font = TTFont(SRC)
    glyphs = font.getGlyphSet()
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()

    out = {}
    for cp in CODEPOINTS:
        if cp not in cmap:
            print(f"warning: U+{cp:05X} not in cmap, skipping")
            continue
        gname = cmap[cp]
        glyph = glyphs[gname]

        svg_pen = SVGPathPen(glyphs)
        glyph.draw(svg_pen)
        path = svg_pen.getCommands()

        bounds_pen = BoundsPen(glyphs)
        glyph.draw(bounds_pen)
        bounds = list(bounds_pen.bounds) if bounds_pen.bounds else [0, 0, 0, 0]

        width, _lsb = hmtx[gname]

        out[f"{cp:05X}"] = {
            "path": path,
            "width": width,
            "bounds": bounds,
            "name": unicodedata.name(chr(cp)),
        }

    with open(OUT, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print(f"wrote {OUT}: {len(out)} glyphs")

if __name__ == "__main__":
    main()
