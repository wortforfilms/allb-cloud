import uharfbuzz as hb

FONT = "/home/claude/brahmi_font/MAATAA-Brahmi-Sans.ttf"

with open(FONT, "rb") as f:
    fontdata = f.read()

face = hb.Face(fontdata)
font = hb.Font(face)

samples = {
    "vowel a + consonant ka + consonant ma": "\U00011003\U00011011\U00011026",
    "candrabindu + anusvara + visarga": "\U00011000\U00011001\U00011002",
    "full run across the block": "".join(chr(c) for c in range(0x11000, 0x11080)),
}

for label, text in samples.items():
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf)
    infos = buf.glyph_infos
    positions = buf.glyph_positions
    notdef_count = sum(1 for i in infos if i.codepoint == 0)
    print(f"{label}: {len(text)} chars -> {len(infos)} glyphs, .notdef count = {notdef_count}")
    if notdef_count:
        print("  !! contains .notdef -- shaping/cmap problem")

print("\nHarfBuzz version:", hb.version_string())
