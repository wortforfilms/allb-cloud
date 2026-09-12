from PIL import Image, ImageDraw, ImageFont

FONT = "/home/claude/brahmi_font/MAATAA-Brahmi-Sans.ttf"
SIZE = 90

# a grid of sample chars: all 14 independent vowels, first 20 consonants,
# and a handful of marks/numbers, so we can eyeball variety + legibility.
vowels = [chr(c) for c in range(0x11003, 0x11011)]
consonants = [chr(c) for c in range(0x11011, 0x11011 + 20)]
marks = [chr(c) for c in range(0x11038, 0x11038 + 14)]
digits = [chr(c) for c in range(0x11066, 0x11070)]

rows = [vowels, consonants, marks, digits]
labels = ["independent vowels (U+11003-11010)", "consonants ka.. (U+11011+)",
          "vowel-sign / mark range (U+11038+)", "Brahmi digit range (U+11066-1106F)"]

font = ImageFont.truetype(FONT, SIZE)
cell = SIZE + 40
cols = max(len(r) for r in rows)
img = Image.new("RGB", (cols * cell + 40, len(rows) * (cell + 30) + 40), "white")
draw = ImageDraw.Draw(img)
label_font = ImageFont.load_default()

y = 20
for row, label in zip(rows, labels):
    draw.text((20, y), label, fill="black", font=label_font)
    y += 22
    x = 20
    for ch in row:
        draw.rectangle([x, y, x + SIZE + 10, y + SIZE + 10], outline="lightgray")
        draw.text((x + 5, y), ch, fill="black", font=font)
        x += cell
    y += cell + 10

img.save("/home/claude/brahmi_font/preview.png")
print("saved preview.png", img.size)
