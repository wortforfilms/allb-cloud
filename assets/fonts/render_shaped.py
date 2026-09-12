"""
Correct rendering pipeline: HarfBuzz shapes (real GSUB/GPOS applied), then
FreeType rasterizes each resulting glyph BY GLYPH ID and we composite the
bitmaps ourselves at HarfBuzz's computed positions. This is the same two-
stage pipeline a real terminal uses -- unlike PIL's plain ImageFont.text(),
which maps characters to glyphs via cmap only and does not reliably run
GSUB substitutions, so it can't be trusted to show what the font actually
does.
"""
import freetype
import uharfbuzz as hb
from PIL import Image

def render_line(font_path, text, px_size=120, pad=40):
    # shape
    with open(font_path, "rb") as f:
        fontdata = f.read()
    face_hb = hb.Face(fontdata)
    font_hb = hb.Font(face_hb)
    upm = face_hb.upem
    scale = px_size / upm
    font_hb.scale = (upm, upm)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font_hb, buf)
    infos = buf.glyph_infos
    positions = buf.glyph_positions

    # rasterize with FreeType, by glyph index (not by character)
    ft_face = freetype.Face(font_path)
    ft_face.set_char_size(px_size * 64)

    bitmaps = []
    cursor_x, cursor_y = 0, 0
    min_x = min_y = 10**9
    max_x = max_y = -10**9
    for info, pos in zip(infos, positions):
        ft_face.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
        bmp = ft_face.glyph.bitmap
        left = ft_face.glyph.bitmap_left
        top = ft_face.glyph.bitmap_top
        ox, oy = cursor_x + pos.x_offset * scale / 64.0 * (upm / px_size), 0
        # position (baseline-relative) where this glyph's bitmap top-left goes
        gx = cursor_x + (pos.x_offset / upm) * px_size + left
        gy = cursor_y - (pos.y_offset / upm) * px_size - top
        if bmp.width and bmp.rows:
            data = bytes(bmp.buffer)
            img = Image.frombytes("L", (bmp.width, bmp.rows), data)
            bitmaps.append((gx, gy, img))
            min_x, min_y = min(min_x, gx), min(min_y, gy)
            max_x, max_y = max(max_x, gx + bmp.width), max(max_y, gy + bmp.rows)
        cursor_x += (pos.x_advance / upm) * px_size
        cursor_y += (pos.y_advance / upm) * px_size

    if not bitmaps:
        return Image.new("RGB", (10, 10), "white")

    W = int(max_x - min_x) + 2 * pad
    H = int(max_y - min_y) + 2 * pad
    canvas = Image.new("L", (W, H), 0)
    for gx, gy, img in bitmaps:
        canvas.paste(img, (int(gx - min_x + pad), int(gy - min_y + pad)), img)
    # invert to black-on-white
    rgb = Image.new("RGB", (W, H), "white")
    black = Image.new("RGB", (W, H), "black")
    rgb.paste(black, (0, 0), canvas)
    return rgb
