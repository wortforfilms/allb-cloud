"""SLP1 → Devanagari and IAST.

A copy of brahmini/guru/guru/slp1.py (Guru), kept identical apart from this note
and without the convert() helper, which needs Guru-Lipi.

SLP1 is the one-ASCII-letter-per-sound scheme that Sanskrit data sets
(including the Panini data in data/panini) use. Guru works in Devanagari, so
the data is converted when it is loaded. (Copied from brahmini/guru/guru/slp1.py.)

Covered: all vowels and consonants, anusvara M, visarga H, candrabindu ~,
avagraha ', the Paninian accent marks \\ (anudatta) and ^ (svarita), pluta 3,
the jihvamuliya / upadhmaniya written as ≍ before k/kh or p/ph, and . / ..
as danda / double danda (not inside numbers like 6.4.15).
Anything else (spaces, digits, punctuation) passes through unchanged.
"""

VOWELS = {
    "a": ("अ", "", "a"), "A": ("आ", "ा", "ā"), "i": ("इ", "ि", "i"), "I": ("ई", "ी", "ī"),
    "u": ("उ", "ु", "u"), "U": ("ऊ", "ू", "ū"), "f": ("ऋ", "ृ", "ṛ"), "F": ("ॠ", "ॄ", "ṝ"),
    "x": ("ऌ", "ॢ", "ḷ"), "X": ("ॡ", "ॣ", "ḹ"), "e": ("ए", "े", "e"), "E": ("ऐ", "ै", "ai"),
    "o": ("ओ", "ो", "o"), "O": ("औ", "ौ", "au"),
}
CONSONANTS = {
    "k": ("क", "k"), "K": ("ख", "kh"), "g": ("ग", "g"), "G": ("घ", "gh"), "N": ("ङ", "ṅ"),
    "c": ("च", "c"), "C": ("छ", "ch"), "j": ("ज", "j"), "J": ("झ", "jh"), "Y": ("ञ", "ñ"),
    "w": ("ट", "ṭ"), "W": ("ठ", "ṭh"), "q": ("ड", "ḍ"), "Q": ("ढ", "ḍh"), "R": ("ण", "ṇ"),
    "t": ("त", "t"), "T": ("थ", "th"), "d": ("द", "d"), "D": ("ध", "dh"), "n": ("न", "n"),
    "p": ("प", "p"), "P": ("फ", "ph"), "b": ("ब", "b"), "B": ("भ", "bh"), "m": ("म", "m"),
    "y": ("य", "y"), "r": ("र", "r"), "l": ("ल", "l"), "v": ("व", "v"),
    "S": ("श", "ś"), "z": ("ष", "ṣ"), "s": ("स", "s"), "h": ("ह", "h"),
}
MARKS = {  # after a vowel (or a consonant's inherent a)
    "M": ("ं", "ṃ"), "H": ("ः", "ḥ"), "~": ("ँ", "m̐"),
    "\\": ("॒", ""), "^": ("॑", ""), "3": ("३", "3"),
}
VIRAMA = "्"


def to_devanagari(s: str) -> str:
    out, i, n = [], 0, len(s)
    while i < n:
        ch = s[i]
        if ch == "≍":  # jihvamuliya before k/kh, upadhmaniya before p/ph
            nxt = s[i + 1] if i + 1 < n else ""
            out.append("ᳶ" if nxt in "pP" else "ᳵ"); i += 1; continue
        if ch in CONSONANTS:
            out.append(CONSONANTS[ch][0])
            nxt = s[i + 1] if i + 1 < n else ""
            if nxt in VOWELS:
                out.append(VOWELS[nxt][1]); i += 2
            else:
                if nxt not in MARKS:
                    out.append(VIRAMA)
                i += 1
            continue
        if ch in VOWELS:
            out.append(VOWELS[ch][0]); i += 1; continue
        if ch in MARKS:
            out.append(MARKS[ch][0]); i += 1; continue
        if ch == "'":
            out.append("ऽ"); i += 1; continue
        if ch == "." and not (i and s[i - 1].isdigit()):  # sentence stops; 6.4.15-style numbers stay
            if s[i:i + 2] == "..":
                out.append("॥"); i += 2
            else:
                out.append("।"); i += 1
            continue
        out.append(ch); i += 1
    return "".join(out)


def to_iast(s: str) -> str:
    out, i, n = [], 0, len(s)
    while i < n:
        ch = s[i]
        if ch == "≍":
            nxt = s[i + 1] if i + 1 < n else ""
            out.append("ḫ" if nxt in "pP" else "ẖ"); i += 1; continue
        if ch in CONSONANTS:
            out.append(CONSONANTS[ch][1])
            nxt = s[i + 1] if i + 1 < n else ""
            if nxt not in VOWELS and nxt in MARKS:
                out.append("a")  # a mark directly after a consonant sits on its inherent a
            i += 1; continue
        if ch in VOWELS:
            out.append(VOWELS[ch][2]); i += 1; continue
        if ch in MARKS:
            out.append(MARKS[ch][1]); i += 1; continue
        out.append(ch); i += 1
    return "".join(out)
