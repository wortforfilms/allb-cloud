#!/usr/bin/env python3
"""Builds data/ashtadhyayi.json from a licensed source. Run: python3 scripts/build_ashtadhyayi.py

Inputs
  data/sources/vidyut/sutrapatha.tsv   all 3,983 sutras (SLP1), from Vidyut by ambuda.org,
                                       MIT licence (data shared by ashtadhyayi.com)
  data/ashtadhyayi-curated.json        hand-curated category / gate / meanings for a few sutras

The sutra text always comes from the source file. Nothing here invents text:
a sutra without a curated category is "unclassified" (category null), and
meanings appear only where the curated file has them. build.rs refuses to
compile a dataset that is incomplete or has placeholder text.
"""
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slp1 import to_devanagari, to_iast  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data", "sources", "vidyut", "sutrapatha.tsv")
CURATED = os.path.join(ROOT, "data", "ashtadhyayi-curated.json")
OUT = os.path.join(ROOT, "data", "ashtadhyayi.json")
EXPECTED = 3983

SOURCE = {
    "name": "Vidyut (ambuda.org), vidyut-prakriya/data/sutrapatha.tsv",
    "url": "https://github.com/ambuda-org/vidyut",
    "commit": "8da2f90bee3ce1c07505fa432fc3729e3f7e02ea",
    "license": "MIT",
    "license_file": "data/sources/vidyut/LICENSE-vidyut.md",
    "attribution": "Ashtadhyayi text from Vidyut (https://github.com/ambuda-org/vidyut), (c) ambuda.org, MIT licence; data originally shared by ashtadhyayi.com.",
    "edition_note": "This edition has 3,983 sutras; other printed editions count about 3,959 to 3,996.",
}


def main():
    raw = open(SRC, "rb").read()
    rows = [line.split("\t") for line in raw.decode("utf-8").splitlines()[1:] if line.strip()]
    curated = json.load(open(CURATED, encoding="utf-8"))["sutras"]
    sutras, seen = [], set()
    for code, text in rows:
        a, p, n = (int(x) for x in code.split("."))
        if code in seen:
            sys.exit(f"duplicate sutra {code}")
        seen.add(code)
        c = curated.get(code, {})
        entry = {
            "id": code, "sutra": to_devanagari(text), "slp1": text, "iast": to_iast(text),
            "chapter": a, "pada": p, "number": n,
            "category": c.get("category"), "hardware_gate": c.get("hardware_gate"),
        }
        for k in ("pada_patha", "arth_hindi", "arth_sanskrit", "arth_status"):
            if k in c:
                entry[k] = c[k]
        sutras.append(entry)
    unknown = sorted(set(curated) - seen)
    if unknown:
        sys.exit(f"curated entries for sutras that do not exist: {unknown}")
    if len(sutras) != EXPECTED:
        sys.exit(f"expected {EXPECTED} sutras, found {len(sutras)}")
    data = {
        "system": "PANINI_ASHTADHYAYI_SUTRAPATHA",
        "version": "3.0.0",
        "total_sutras": len(sutras),
        "source": {**SOURCE, "sha256": hashlib.sha256(raw).hexdigest()},
        "fields": {
            "sutra": "Devanagari, converted from the source's SLP1 by scripts/slp1.py",
            "category": "null = not yet classified; set only in data/ashtadhyayi-curated.json",
            "hardware_gate": "null = DEFAULT_GATE",
            "arth_*": "present only where curated; arth_status says whether reviewed",
        },
        "sutras": sutras,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"Wrote {OUT}: {len(sutras)} sutras, {sum(1 for s in sutras if s['category'])} classified, "
          f"{sum(1 for s in sutras if 'arth_hindi' in s)} with meanings.")


if __name__ == "__main__":
    main()
