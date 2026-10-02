#!/usr/bin/env python3
"""Reference model: consonant and visarga sandhi at a word boundary (hal sandhi).

Written from the sutras, in Panini's order. It is the specification for
hardware/rtl/hal_sandhi_*.v, and is compared with Vidyut's word-boundary rules.

Model of a juncture, with fixed slots:
    V   last vowel of the first word (or none)
    C1  its final consonant (k ṭ t p n m s r, or none for a vowel ending)
    C2  a second junction consonant that rules may insert (tuk, dhuṭ, s from ru, …)
    R   first sound of the second word (none = pause, avasāna)
    R2  the sound after R (context only; 8.3.7 and 8.4.63 need it)

Stages, in the order the rules apply:
    A  Saptādhyāyī: 6.1.73 / 6.1.76 tuk before छ; then 8.2.39 jaś, 8.2.66 s → ru
    B  8.3, plus the three Saptādhyāyī rules that name a Tripādī result and so
       must see it despite 8.2.1 (6.1.113 and 6.1.114 name ru; 6.3.111 names the
       loss of r by 8.3.14). Hardware needs an explicit bypass for exactly these.
    C  8.4
Optional rules (vā, vibhāṣā, anyatarasyām, a named teacher) fork a new candidate,
so the result is a set of correct forms; candidate 0 never takes an optional rule.

SLP1 tokens; M = anusvāra, H = visarga, Z = jihvāmūlīya, V = upadhmānīya,
L = nasal l (l̐), ru = the ru substitute (internal).
"""
import itertools

VOWELS = list("aAiIuUfFxXeEoO")
SHORT = set("aiufx")
DIRGHA = {"a": "A", "i": "I", "u": "U", "f": "F", "x": "X"}
KHAR = set("kKcCwWtTpPSzs")                 # voiceless: खर्
HASH = set("hyvrlYmNRnJBGQDjbgqd")          # voiced consonants: हश्
AS_ = set(VOWELS) | HASH                    # अश्
HAL = set("kKgGNcCjJYwWqQRtTdDnpPbBmyrlvSzsh")
NASAL = set("NYRnm")
CVARGA = set("cCjJY")
TVARGA_RETRO = set("wWqQR")                 # ṭ-varga
TVARGA = set("tTdDn")                        # t-varga
CHAV = set("cCwWtT")                         # छव्
AM = set(VOWELS) | set("hyvrlYmNRn")         # अम्
AT = set(VOWELS) | set("hyvr")               # अट्
YAY = (HAL - set("Szsh"))                    # यय्
JHAY = set("kKgGcCjJwWqQtTdDpPbB")          # झय् (stops)
JAS = {"k": "g", "w": "q", "t": "d", "p": "b"}                       # 8.2.39
CAR = {"g": "k", "q": "w", "d": "t", "b": "p", "j": "c", "D": "t"}   # 8.4.55 (D = dhuṭ)
NASAL_OF = {"g": "N", "q": "R", "d": "n", "b": "m", "j": "Y"}         # 8.4.45
ASPIRATE = {"g": "G", "q": "Q", "d": "D", "b": "B", "j": "J"}        # 8.4.62
STOP_CLASS_NASAL = {**{c: "N" for c in "kKgG"}, **{c: "Y" for c in "cCjJ"}, **{c: "R" for c in "wWqQ"},
                    **{c: "n" for c in "tTdD"}, **{c: "m" for c in "pPbB"}, **{c: c for c in "NYRnm"}, "l": "L"}


def hal_sandhi(v, c1, r, r2):
    """All correct forms at the juncture. Returns a list of (tokens, avagraha, trace)."""
    cand = [dict(V=v, C1=c1, C2=None, R=r, avg=False, trace=[])]

    def fork(c, rule, **changes):
        n = dict(c, trace=c["trace"] + [rule + " (optional)"]); n.update(changes); cand.append(n)

    # ---- Stage A: Saptādhyāyī, then 8.2 ---------------------------------------------
    for c in list(cand):
        if c["C1"] is None and c["R"] == "C" and c["V"]:
            if c["V"] in SHORT:
                c["C1"] = "t"; c["trace"].append("6.1.73")          # छे च: tuk
            else:
                fork(c, "6.1.76", C1="t")                            # पदान्ताद्वा
    for c in cand:
        if c["C1"] in JAS:
            c["C1"] = JAS[c["C1"]]; c["trace"].append("8.2.39")     # झलां जशोऽन्ते
        if c["C1"] == "s":
            c["C1"] = "ru"; c["trace"].append("8.2.66")             # ससजुषो रुः

    assert len(cand) <= 2                       # at most one optional rule per stage (the hardware has one fork slot)
    # ---- Stage B: 8.3 (with the named-result bypass) --------------------------------------
    n_before = len(cand)
    for c in list(cand):
        V, R = c["V"], c["R"]
        if c["C1"] == "ru" and V == "a" and R == "a":                # 6.1.113 + 6.1.87 + 6.1.109
            c.update(V="o", C1=None, R=None, avg=True); c["trace"] += ["6.1.113", "6.1.87", "6.1.109"]; continue
        if c["C1"] == "ru" and V == "a" and R in HASH:               # 6.1.114 + 6.1.87
            c.update(V="o", C1=None); c["trace"] += ["6.1.114", "6.1.87"]; continue
        if c["C1"] == "n" and R in CHAV and r2 in AM:                # 8.3.7 नश्छव्यप्रशान्, 8.3.4 anusvāra
            c.update(C1="M", C2="ru"); c["trace"] += ["8.3.7", "8.3.4"]
        if c["C1"] in ("r", "ru") and R == "r":                      # 8.3.14 रो रि, 6.3.111
            c["C1"] = None; c["trace"].append("8.3.14")
            if V in ("a", "i", "u"):                                  # aṇ = अ इ उ (the earlier ण्)
                c["V"] = DIRGHA[V]; c["trace"].append("6.3.111")
        for slot in ("C1", "C2"):                                    # 8.3.15 खरवसानयोर्विसर्जनीयः
            if c[slot] in ("r", "ru") and (R is None or R in KHAR):
                c[slot] = "H"; c["trace"].append("8.3.15")
        if c["C1"] == "ru" and V in ("a", "A") and R in AS_:          # 8.3.17 भोभगोअघोअपूर्वस्य योऽशि
            c["C1"] = "y"; c["trace"].append("8.3.17")
            if R in VOWELS:
                fork(c, "8.3.19", C1=None)                            # लोपः शाकल्यस्य
            else:
                c["C1"] = None; c["trace"].append("8.3.22")           # हलि सर्वेषाम्
        if c["C1"] == "ru":
            c["C1"] = "r"                                             # ru remains r
        if c["C1"] == "m" and R in HAL:
            c["C1"] = "M"; c["trace"].append("8.3.23")                # मोऽनुस्वारः
        if c["C1"] == "n" and c["C2"] is None:
            if R == "s":
                fork(c, "8.3.30", C2="D")                             # नश्च: dhuṭ
            if R == "S":
                fork(c, "8.3.31", C2="t")                             # शि तुक्
            if V in SHORT and R in VOWELS:
                c["C2"] = "n"; c["trace"].append("8.3.32")            # ङमो ह्रस्वादचि ङमुण्नित्यम्
        for slot in ("C1", "C2"):                                    # 8.3.34–8.3.37 on the visarga
            if c[slot] == "H" and R in KHAR:
                if R in "kKpP":
                    fork(c, "8.3.37", **{slot: "Z" if R in "kK" else "V"})
                elif R in "Szs":
                    c[slot] = "s"; c["trace"].append("8.3.34")
                    fork(dict(c, trace=c["trace"][:-1]), "8.3.36", **{slot: "H"})
                else:
                    c[slot] = "s"; c["trace"].append("8.3.34")

    assert len(cand) <= n_before + 1
    # ---- Stage C: 8.4 ---------------------------------------------------------------------
    n_before = len(cand)
    for c in list(cand):
        def before_r():
            return "C2" if c["C2"] else "C1"
        # 8.4.40 स्तोः श्चुना श्चुः, right to left (a changed sound can feed the one before it)
        for slot, nxt in (("C2", "R"), ("C1", "C2" if c["C2"] else "R")):
            x, y = c[slot], c[nxt]
            if x and y and (x == "s" or x in TVARGA) and (y == "S" or y in CVARGA):
                c[slot] = {"s": "S", "t": "c", "T": "C", "d": "j", "D": "J", "n": "Y"}[x]; c["trace"].append("8.4.40")
        # 8.4.41 ष्टुना ष्टुः (s / t-varga before ṣ / ṭ-varga). The other direction, ṭ-varga before
        # t-varga, is barred after a pada-final ṭ-varga by 8.4.42 न पदान्ताट्टोरनाम्, which is always
        # the case at this juncture, so it is not applied.
        for slot, nxt in (("C2", "R"), ("C1", "C2" if c["C2"] else "R")):
            x, y = c[slot], c[nxt]
            if x and y and (x == "s" or x in TVARGA) and (y == "z" or y in TVARGA_RETRO):
                c[slot] = {"s": "z", "t": "w", "T": "W", "d": "q", "D": "Q", "n": "R"}[x]; c["trace"].append("8.4.41")
        s = before_r(); x, R = c[s], c["R"]
        if x in NASAL_OF and R in NASAL:
            fork(c, "8.4.45", **{s: NASAL_OF[x]})                     # यरोऽनुनासिकेऽनुनासिको वा
        if c["C1"] in CAR and c["C2"] and c["C2"] in KHAR:            # 8.4.55 inside the junction
            c["C1"] = CAR[c["C1"]]; c["trace"].append("8.4.55")
        x = c[s]
        if x in CAR and R in KHAR:
            c[s] = CAR[x]; c["trace"].append("8.4.55")                # खरि च
        elif x in CAR and R is None:
            fork(c, "8.4.56", **{s: CAR[x]})                          # वावसाने
        if c["C1"] == "M" and c["C2"] is None and R in YAY and R in STOP_CLASS_NASAL:
            fork(c, "8.4.59", C1=STOP_CLASS_NASAL[R])                  # वा पदान्तस्य
        if c[s] in ("d", "n") and R == "l":                           # 8.4.60 तोर्लि
            c[s] = "l" if c[s] == "d" else "L"; c["trace"].append("8.4.60")
        x = c[s]
        if R == "h" and x in ASPIRATE:
            fork(c, "8.4.62", R=ASPIRATE[x])                          # झयो होऽन्यतरस्याम्
        if R == "S" and x in JHAY and r2 in AT:
            fork(c, "8.4.63", R="C")                                  # शश्छोऽटि

    assert len(cand) <= n_before + 1
    out = []
    for c in cand:
        toks = [t for t in (c["V"], c["C1"], c["C2"], c["R"]) if t]
        assert "ru" not in toks, c
        out.append((toks, c["avg"], c["trace"]))
    hal_sandhi.slots = [(c["V"], c["C1"], c["C2"], c["R"], c["avg"], c["trace"]) for c in cand]
    return out


def as_text(toks, avg=False):
    return "".join(toks).replace("L", "~l") + ("'" if avg else "")


# --------------------------------------------------------------------------------------
# Test vectors for hardware/tb/tb_hal_sandhi.v, and the comparison with Vidyut
# --------------------------------------------------------------------------------------
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VEC = os.path.join(os.path.dirname(HERE), "tb", "vectors")
CODES = {**{v: i for i, v in enumerate("aAiIuUfFxXeEoO")},
         "h": 14, "y": 15, "v": 16, "r": 17, "l": 18, "Y": 19, "m": 20, "N": 21, "R": 22, "n": 23,
         "J": 24, "B": 25, "G": 26, "Q": 27, "D": 28, "j": 29, "b": 30, "g": 31, "q": 32, "d": 33,
         "K": 34, "P": 35, "C": 36, "W": 37, "T": 38, "c": 39, "w": 40, "t": 41, "k": 42, "p": 43,
         "S": 44, "z": 45, "s": 46, "M": 47, "H": 48, "Z": 49, "V": 50, "L": 51, None: 63}
TRACE_BITS = ["6.1.73", "6.1.76", "8.2.39", "8.2.66", "6.1.113", "6.1.114", "6.1.87", "6.1.109", "8.3.7", "8.3.4",
              "8.3.14", "6.3.111", "8.3.15", "8.3.17", "8.3.19", "8.3.22", "8.3.23", "8.3.30", "8.3.31", "8.3.32",
              "8.3.34", "8.3.36", "8.3.37", "8.4.40", "8.4.41", "8.4.45", "8.4.55", "8.4.56", "8.4.59", "8.4.60",
              "8.4.62", "8.4.63"]
LANES = 3

# Where this model and Vidyut differ, and why (checked by hand; the script fails on anything new).
KNOWN = {
    ("fr", "r"): "6.3.111 lengthens only aṇ = अ इ उ (the earlier ण्, as everywhere except 1.1.69); Vidyut also lengthens ऋ",
    ("fs", "r"): "same as above",
    ("t", "Y"): "8.4.40 makes त् + ञ into ज्ञ (or ञ्ञ by 8.4.45); Vidyut skips 8.4.40 here. No word begins with ञ",
    ("t", "R"): "8.4.41 makes त् + ण into ड्ण (or ण्ण); Vidyut skips 8.4.41 here. No word begins with ण",
    ("n", "Y"): "8.4.40 makes न् + ञ into ञ्ञ; Vidyut keeps न्. No word begins with ञ",
    ("n", "R"): "8.4.41 makes न् + ण into ण्ण; Vidyut keeps न्. No word begins with ण",
    ("n", "S"): "Vidyut lists 'c C' (from its त् rules); with 8.3.31 शि तुक् the form is ञ्च्छ, keeping ञ्. Its other entry ञ्श agrees",
    ("n", "h"): "Vidyut lists 'd D' (from its त् rules); 8.4.62 needs a झय् stop before ह, and न् is not one, so न् + ह stays",
    ("n", "l"): "Vidyut's extra 'Ml l' is a fallback for scripts without nasal vowels; its main entry ल्ँल agrees",
}


def trace_mask(trace):
    m = 0
    for t in trace:
        m |= 1 << TRACE_BITS.index(t.replace(" (optional)", ""))
    return m


def vectors():
    vs = list("aAiIuUfFxeEoO")
    cases = []
    for v in [None] + vs:
        for c1 in [None, "k", "w", "t", "p", "n", "m", "s", "r"]:
            for r in [None] + vs + list("kKgGNcCjJYwWqQRtTdDnpPbBmyrlvSzsh"):
                for r2 in ("a", "k"):
                    hal_sandhi(v, c1, r, r2)
                    forms = hal_sandhi.slots
                    assert len(forms) <= LANES, (v, c1, r, r2, forms)
                    cases.append(((v, c1, r, r2), forms))
    return cases


def compare_vidyut(path):
    agree, diffs = 0, []
    for line in open(path, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        f, s, res = line.rstrip("\n").split("\t")
        if len(f) == 1 and f in "aAiIuUfFxXeEoO" and s in "aAiIuUfFxXeEoO":
            continue                                    # vowel + vowel: sandhi_engine, checked separately
        v, c1 = (f[0], f[1]) if len(f) == 2 else ((f, None) if f in "aAiIuUfFxXeEoO" else (None, f))
        forms = {as_text(t, a) for t, a, _ in hal_sandhi(v, c1, s or None, "a")}
        if res.replace(" ", "") in forms:
            agree += 1
        else:
            diffs.append((f, s, res, sorted(forms)))
    return agree, diffs


def main():
    os.makedirs(VEC, exist_ok=True)
    cases = vectors()
    with open(os.path.join(VEC, "hal_ref.mem"), "w") as fh:
        fh.write("// per case: V C1 R R2 count, then 4 x (V C1 C2 R avagraha trace) — hex, generated by hardware/scripts/hal_ref.py\n")
        for (v, c1, r, r2), forms in cases:
            words = [CODES[v], CODES[c1], CODES[r], CODES[r2], len(forms)]
            for i in range(LANES):
                if i < len(forms):
                    fv, fc1, fc2, fr, avg, tr = forms[i]
                    words += [CODES[fv], CODES[fc1], CODES[fc2], CODES[fr], int(avg), trace_mask(tr)]
                else:
                    words += [63, 63, 63, 63, 0, 0]
            fh.write(" ".join(f"{w:x}" for w in words) + "\n")
    agree, diffs = compare_vidyut(os.path.join(VEC, "vidyut_sandhi_all.tsv"))
    unknown = [d for d in diffs if (d[0], d[1]) not in KNOWN]
    with open(os.path.join(VEC, "hal_vidyut_report.md"), "w", encoding="utf-8") as fh:
        fh.write(f"# Consonant and visarga sandhi: reference model vs Vidyut\n\nAgree: {agree} of {agree + len(diffs)} word-boundary rules "
                 "(vowel + vowel pairs are checked separately by tb_panini_datapath).\n\n| First | Second | Vidyut | This model | Why |\n| --- | --- | --- | --- | --- |\n")
        for f, s, res, forms in diffs:
            fh.write(f"| {f} | {s} | {res} | {' / '.join(forms)} | {KNOWN.get((f, s), 'UNEXPLAINED')} |\n")
    with open(os.path.join(VEC, "hal_counts.vh"), "w") as fh:
        fh.write(f"`define HAL_REF_CASES {len(cases)}\n")
    print(f"hal_ref.mem: {len(cases)} cases · Vidyut: {agree} agree, {len(diffs)} differ ({len(diffs) - len(unknown)} explained)")
    if unknown:
        sys.exit(f"Unexplained differences from Vidyut: {unknown}")


if __name__ == "__main__":
    main()
