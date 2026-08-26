#!/usr/bin/env python3
"""
Brahmi-Z0-Micro Font Assembly & Optimization Engine
Target Payload: <= 12 KB WOFF2
Unicode Range: U+11000..U+1107F (Brahmi) + Standard Telemetry/Numeric Glyphs
"""

import sys
import os
import base64
import brotli

from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen


# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================
TARGET_UPM = 1024
OUTPUT_WOFF2_PATH = "dist/BrahmiZ0Micro.woff2"
OUTPUT_CSS_PATH = "dist/brahmi_micro.css"

# Unicode Ranges to retain (Brahmi Core + Numerals + Telemetry Icons + Digits/Colon)
EXPLICIT_UNICODES = (
    # Brahmi Block Core (U+11000 - U+1104D)
    set(range(0x11000, 0x1104E))
    # Brahmi Numerals (U+11052 - U+1106F)
    | set(range(0x11052, 0x11070))
    # Standard ASCII Digits (0-9) & Colon (:)
    | set(range(0x0030, 0x003A))
    | {0x003A}
    # Telemetry UI Icons: Checkmark (✓), Lightning (⚡), Shield (🛡️)
    | {0x2713, 0x26A1, 0x1F6E1}
)

# OpenType Layout Features to preserve for essential Matra stacking & Ligatures
PRESERVED_LAYOUT_FEATURES = [
    "akhn",  # Akhanda (consonant conjuncts)
    "haln",  # Halant / Virama form
    "abvs",  # Above-base substitutions
    "blws",  # Below-base substitutions
    "psts",  # Post-base substitutions
    "mktu",  # Mark to upper anchor
    "mktp",  # Mark to position anchor
]

# Non-essential OpenType tables to drop completely
TABLES_TO_DROP = [
    "DSIG", "hdmx", "VDMX", "LTSH", "PREP", "cvt ", "fpgm",
    "gasp", "kern", "PCLT", "post", "VORG", "BASE"
]


# ==============================================================================
# PIPELINE FUNCTIONS
# ==============================================================================

def rescale_and_quantize_upm(font: TTFont, target_upm: int = 1024) -> None:
    """
    Rescales font outlines to a 1024 Em Square grid to allow fast bit-shift division
    in browser rasterizers while reducing coordinate integer data footprint.
    """
    current_upm = font["head"].unitsPerEm
    if current_upm == target_upm:
        return

    scale_factor = target_upm / float(current_upm)
    glyph_set = font.getGlyphSet()

    for glyph_name in font.getGlyphOrder():
        glyph = font["glyf"][glyph_name]
        if glyph.isComposite():
            # Adjust composite component offsets
            for component in glyph.components:
                component.x = int(round(component.x * scale_factor))
                component.y = int(round(component.y * scale_factor))
        elif glyph.numberOfContours > 0:
            # Scale simple glyph contours
            pen = TTGlyphPen(glyph_set)
            transform_pen = TransformPen(pen, (scale_factor, 0, 0, scale_factor, 0, 0))
            glyph_set[glyph_name].draw(transform_pen)
            font["glyf"][glyph_name] = pen.glyph()

    # Rescale horizontal metrics (hmtx table)
    for glyph_name in font["hmtx"].metrics:
        advance_width, lsb = font["hmtx"].metrics[glyph_name]
        font["hmtx"].metrics[glyph_name] = (
            int(round(advance_width * scale_factor)),
            int(round(lsb * scale_factor)),
        )

    font["head"].unitsPerEm = target_upm


def execute_subsetting(input_ttf_path: str) -> TTFont:
    """
    Applies fontTools Subsetter to strip unneeded glyphs, tables, and OT features.
    """
    options = Options()
    options.drop_tables = TABLES_TO_DROP
    options.layout_features = PRESERVED_LAYOUT_FEATURES
    options.hinting = False  # Purge bytecode instructions
    options.desubroutinize = True
    options.recalc_glyph_bounds = True
    options.recalc_timestamp = False
    options.name_IDs = [1, 2]  # Retain only Family and Subfamily name strings

    subsetter = Subsetter(options=options)
    subsetter.populate(unicodes=EXPLICIT_UNICODES)

    font = TTFont(input_ttf_path)
    subsetter.subset(font)

    return font


def compile_and_generate_css(font: TTFont, output_woff2: str, output_css: str) -> None:
    """
    Compiles font to WOFF2 using max Brotli compression and emits inline Base64 CSS.
    """
    os.makedirs(os.path.dirname(output_woff2), exist_ok=True)

    # 1. Set WOFF2 flavor and save binary
    font.flavor = "woff2"
    font.save(output_woff2)

    file_size_bytes = os.path.getsize(output_woff2)
    file_size_kb = file_size_bytes / 1024.0

    print(f"[✓] Successfully compiled WOFF2: {output_woff2}")
    print(f"[✓] Output Binary Size: {file_size_kb:.2f} KB ({file_size_bytes} bytes)")

    if file_size_kb > 12.0:
        print(f"[⚠️ WARNING] File size exceeds 12 KB target! ({file_size_kb:.2f} KB)")
    else:
        print(f"[★ PASSED] Binary conforms strictly to <= 12 KB payload constraint.")

    # 2. Base64 encode for zero-render-blocking inline CSS injection
    with open(output_woff2, "rb") as f:
        encoded_b64 = base64.b64encode(f.read()).decode("utf-8")

    css_content = f"""/* Generated BrahmiZ0Micro Webfont - Base64 Payload ({file_size_kb:.2f} KB) */
@font-face {{
  font-family: 'BrahmiZ0Micro';
  src: url('data:font/woff2;base64,{encoded_b64}') format('woff2');
  font-weight: 400;
  font-style: normal;
  font-display: block;
  unicode-range: U+11000-1107F, U+0030-0039, U+003A, U+2713, U+26A1, U+1F6E1;
}}

.brahmi-z0-title {{
  font-family: 'BrahmiZ0Micro', monospace;
  font-size: 18px;
  letter-spacing: 0.5px;
  color: #00e5ff;
}}
"""
    with open(output_css, "w", encoding="utf-8") as f:
        f.write(css_content)

    print(f"[✓] Base64 inline CSS generated: {output_css}")


# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================
def main():
    if len(sys.argv) < 2:
        print("Usage: python3 build_brahmi_micro.py <path_to_input_noto_brahmi.ttf>")
        sys.exit(1)

    input_ttf = sys.argv[1]
    if not os.path.exists(input_ttf):
        print(f"Error: Input font file '{input_ttf}' not found.")
        sys.exit(1)

    print(f"[*] Beginning Brahmi-Z0-Micro build pipeline from '{input_ttf}'...")

    # Step 1: Subset unicode ranges and OpenType tables
    font = execute_subsetting(input_ttf)

    # Step 2: Rescale and quantize grid to 1024 UPM
    rescale_and_quantize_upm(font, target_upm=TARGET_UPM)

    # Step 3: Compress to WOFF2 and write Base64 CSS artifact
    compile_and_generate_css(font, OUTPUT_WOFF2_PATH, OUTPUT_CSS_PATH)


if __name__ == "__main__":
    main()