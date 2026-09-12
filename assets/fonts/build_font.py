#!/usr/bin/env python3
"""
MAATAA Brahmi Sans -- an ORIGINAL, procedurally-generated geometric typeface
covering the full Unicode Brahmi block (U+11000-U+1107F), built to match
exactly what allb.xyz's brahmi_tokenizer.rs assumes (it maps every code
point in that 128-slot range, not just the officially-assigned ones).

IMPORTANT HONESTY NOTE (read before treating this as scholarly):
This is NOT a reproduction of historical/epigraphic Brahmi letterforms.
I do not have reliable pixel-accurate recall of Ashokan-era Brahmi glyph
shapes, and guessing them from memory risked misrepresenting a real
ancient script. Instead every glyph is built from a small, documented set
of geometric primitives (stem / bar / hook / loop / diagonal / dot),
combined by a deterministic rule keyed to each code point's index, so:
  - every one of the 128 code points gets a distinct, real, filled glyph
    (no boxes/tofu, nothing falls back to .notdef)
  - the same code point always produces the same shape (stable, testable)
  - letters (independent vowels + consonants, U+11003-11037) are drawn
    full height with a left stem, the way many real Brahmi consonants are
    built around a vertical
  - marks/signs/numbers (everything else in the block) are drawn smaller,
    without a stem, in the upper-middle zone -- visually reads as
    "mark", the same way real combining vowel signs and punctuation do

For anything that needs to look/behave like real, scholarly-accurate
Brahmi (publishing, academic work, anything user-facing) the honest
answer is: use Noto Sans Brahmi. This font's job is narrower -- give the
MAATAA dev tools a real, installable, HarfBuzz-shapeable font so
brahmi_tokenizer.rs output stops rendering as empty boxes in a terminal.
"""

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
import math

UPM = 1000
ASCENT = 800
DESCENT = -200
CAP = 700          # full letter height
MARK_TOP = 700      # marks live between MARK_BASE and MARK_TOP
MARK_BASE = 320
STEM_X = 180
STEM_W = 90
RIGHT_X = 620
GLYPH_W = 760

# ---------------------------------------------------------------- primitives
# Every primitive returns a list of closed contours; each contour is a list
# of (x, y) points, wound consistently (clockwise). Overlapping same-wound
# contours still render solid under the nonzero fill rule used by glyf, so
# we never need to worry about union booleans here.

def rect(x0, y0, x1, y1):
    return [[(x0, y0), (x1, y0), (x1, y1), (x0, y1)]]

def vbar(cx, y0, y1, w=STEM_W):
    return rect(cx - w / 2, y0, cx + w / 2, y1)

def hbar(cy, x0, x1, w=STEM_W):
    return rect(x0, cy - w / 2, x1, cy + w / 2)

def diag(x0, y0, x1, y1, w=STEM_W):
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1
    nx, ny = -dy / length * w / 2, dx / length * w / 2
    return [[(x0 + nx, y0 + ny), (x1 + nx, y1 + ny),
             (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]]

def dot(cx, cy, r):
    pts = []
    n = 16
    for i in range(n):
        a = 2 * math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return [pts]

def arc_stroke(cx, cy, r, w, a0_deg, a1_deg, n=10):
    """A thick filled arc from a0 to a1 degrees (0 = +x axis, ccw)."""
    a0, a1 = math.radians(a0_deg), math.radians(a1_deg)
    outer_r, inner_r = r + w / 2, r - w / 2
    outer = [(cx + outer_r * math.cos(a0 + (a1 - a0) * i / n),
              cy + outer_r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
    inner = [(cx + inner_r * math.cos(a1 - (a1 - a0) * i / n),
              cy + inner_r * math.sin(a1 - (a1 - a0) * i / n)) for i in range(n + 1)]
    return [outer + inner]

def hook_left(x, y, size, w=STEM_W):
    # a quarter-turn hook opening to the left, anchored at (x, y) = its top-right
    return arc_stroke(x - size, y - size, size, w, 0, 90)

def hook_right(x, y, size, w=STEM_W):
    return arc_stroke(x + size, y - size, size, w, 90, 180)

def loop(cx, cy, r, w=STEM_W):
    return arc_stroke(cx, cy, r, w, 0, 359.999, n=24)

# ------------------------------------------------------------- glyph recipes
HEADS = ["none", "bar", "hookL", "hookR", "loop"]
BODIES = ["none", "bar", "diagF", "diagB", "loop"]
FEET = ["none", "hookL", "hookR", "dot"]

def recipe_for_index(i):
    """Bijective mapping index -> (head, body, foot) so every index in
    range(len(HEADS)*len(BODIES)*len(FEET)) = 100 gets a unique combo."""
    nf = len(FEET)
    nb = len(BODIES)
    foot = FEET[i % nf]
    i //= nf
    body = BODIES[i % nb]
    i //= nb
    head = HEADS[i % len(HEADS)]
    return head, body, foot


def build_letter_contours(index):
    """Full-height glyph (independent vowels + consonants): left stem +
    head/body/foot attached on the right side."""
    head, body, foot = recipe_for_index(index)
    contours = []
    contours += vbar(STEM_X, 40, CAP)

    top_y, mid_y, bot_y = CAP - 90, CAP * 0.52, 140

    if head == "bar":
        contours += hbar(top_y, STEM_X, RIGHT_X)
    elif head == "hookL":
        contours += hook_left(STEM_X + 130, top_y, 110)
    elif head == "hookR":
        contours += hook_right(STEM_X, top_y, 130)
    elif head == "loop":
        contours += loop(STEM_X + 160, top_y - 40, 100)

    if body == "bar":
        contours += hbar(mid_y, STEM_X, RIGHT_X - 60)
    elif body == "diagF":
        contours += diag(STEM_X, mid_y - 90, RIGHT_X - 40, mid_y + 90)
    elif body == "diagB":
        contours += diag(STEM_X, mid_y + 90, RIGHT_X - 40, mid_y - 90)
    elif body == "loop":
        contours += loop(STEM_X + 190, mid_y, 130)

    if foot == "hookL":
        contours += hook_left(STEM_X + 130, bot_y, 110)
    elif foot == "hookR":
        contours += hook_right(STEM_X, bot_y, 130)
    elif foot == "dot":
        contours += dot(STEM_X + 220, bot_y, 55)

    return contours


def build_mark_contours(index):
    """Smaller, stem-less glyph for signs/vowel-signs/punctuation/numbers --
    floats in the upper-middle band so it visually reads as a 'mark' rather
    than a full letter."""
    head, body, foot = recipe_for_index(index)
    contours = []
    cx = GLYPH_W / 2 - 40
    top_y, mid_y, bot_y = MARK_TOP - 30, (MARK_TOP + MARK_BASE) / 2, MARK_BASE + 20
    w = 70

    any_drawn = False
    if head == "bar":
        contours += hbar(top_y, cx - 150, cx + 150, w); any_drawn = True
    elif head == "hookL":
        contours += hook_left(cx + 100, top_y, 85, w); any_drawn = True
    elif head == "hookR":
        contours += hook_right(cx - 100, top_y, 85, w); any_drawn = True
    elif head == "loop":
        contours += loop(cx, top_y - 30, 75, w); any_drawn = True

    if body == "bar":
        contours += hbar(mid_y, cx - 140, cx + 140, w)
    elif body == "diagF":
        contours += diag(cx - 130, mid_y - 70, cx + 130, mid_y + 70, w)
    elif body == "diagB":
        contours += diag(cx - 130, mid_y + 70, cx + 130, mid_y - 70, w)
    elif body == "loop":
        contours += loop(cx, mid_y, 100, w)

    if foot == "hookL":
        contours += hook_left(cx + 90, bot_y, 70, w)
    elif foot == "hookR":
        contours += hook_right(cx - 90, bot_y, 70, w)
    elif foot == "dot":
        contours += dot(cx, bot_y, 45)

    if not contours:
        # index 0 (none/none/none) would otherwise be blank -- give it a
        # plain dot so no code point in the block is ever truly empty ink.
        contours += dot(cx, mid_y, 55)

    return contours


# --------------------------------------------------------------- font build
def pen_from_contours(glyph_set, name, contours, advance):
    pen = TTGlyphPen(glyph_set)
    for c in contours:
        pen.moveTo(c[0])
        for pt in c[1:]:
            pen.lineTo(pt)
        pen.closePath()
    return pen.glyph()


def main():
    glyph_order = [".notdef", "space"]
    cmap = {0x20: "space"}

    LETTER_LO, LETTER_HI = 0x11003, 0x11037   # independent vowels + consonants
    for cp in range(0x11000, 0x11080):
        glyph_order.append(f"brahmi{cp:05X}")
        cmap[cp] = f"brahmi{cp:05X}"

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)

    glyphs = {}
    advances = {}

    glyphs[".notdef"] = pen_from_contours({}, ".notdef", rect(60, 0, 460, CAP), GLYPH_W)
    advances[".notdef"] = (GLYPH_W, 0)
    glyphs["space"] = pen_from_contours({}, "space", [], 400)
    advances["space"] = (400, 0)

    letter_i = 0
    mark_i = 0
    for cp in range(0x11000, 0x11080):
        name = f"brahmi{cp:05X}"
        if LETTER_LO <= cp <= LETTER_HI:
            contours = build_letter_contours(letter_i)
            letter_i += 1
        else:
            contours = build_mark_contours(mark_i)
            mark_i += 1
        glyphs[name] = pen_from_contours({}, name, contours, GLYPH_W)
        advances[name] = (GLYPH_W, 0)

    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(advances)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({
        "familyName": "MAATAA Brahmi Sans",
        "styleName": "Regular",
        "uniqueFontIdentifier": "MAATAA Brahmi Sans Regular 1.0",
        "fullName": "MAATAA Brahmi Sans Regular",
        "version": "Version 1.0",
        "psName": "MAATAABrahmiSans-Regular",
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, usWinAscent=ASCENT, usWinDescent=-DESCENT)
    fb.setupPost()

    out = "/home/claude/brahmi_font/MAATAA-Brahmi-Sans.ttf"
    fb.font.save(out)
    print(f"saved {out}  ({letter_i} letters, {mark_i} marks, {len(glyph_order)} glyphs total)")


if __name__ == "__main__":
    main()
