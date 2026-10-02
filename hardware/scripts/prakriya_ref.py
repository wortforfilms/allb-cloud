#!/usr/bin/env python3
"""Reference prakriyā core: present tense (laṭ), active voice (kartari), 3rd person singular,
for roots of the first class (bhvādi). The specification for hardware/rtl/prakriya_core.v.

The state is a list of terms (dhātu, affixes), each with its text in SLP1 (upadeśa form,
with markers and accents, until 1.3.9 removes the markers) and a set of tags.

Rules are of three kinds:
  labels       saṃjñā and it rules, applied as soon as their condition holds
               (1.3.1, 1.3.2, 1.3.3, 1.3.5, 1.3.8, 1.3.9, 1.3.12, 1.3.72, 1.3.78, 3.4.113,
               1.2.4, 1.4.13, 1.4.14, and the Dhātupāṭha gaṇasūtra 01.0933)
  operations   Saptādhyāyī vidhis that compete each step:
               6.1.64, 6.1.65 (on the root as taught, applied with its markers' removal),
               7.1.58, 3.2.123, 3.4.78, 3.1.68, 3.4.79, 7.3.84, 7.3.86, 6.1.78
  Tripādī      8.3.24, 8.4.58, 8.4.68, once each, in order, at the end (8.2.1)
               (Vidyut also notes 8.3.110 / 8.3.111 where they bar ṣatva; they change nothing
               and are not modelled.)

When two or more operations can apply, the engine resolves them by the paribhāṣā
परनित्यान्तरङ्गापवादानामुत्तरोत्तरं बलीयः ("of para, nitya, antaraṅga and apavāda, each later
one is stronger"):
  apavāda   an exception beats its general rule (none occur in this slice)
  antaraṅga the rule whose condition spans fewer terms applies first
  nitya     tested by speculative evaluation: apply each rule in a copy of the state and
            check whether the other one still applies *with the same trigger* (nimitta).
            A rule that applies whether or not the other has applied is nitya and wins.
            (After śap, guṇa would be triggered by śap instead of tip: a different trigger,
            so guṇa is not nitya, and 3.1.68 śap applies first.)
  para      otherwise the later sutra wins (1.4.2 विप्रतिषेधे परं कार्यम्)
"""
import copy

VOWELS = set("aAiIuUfFxXeEoO")
IK = set("iIuUfFxX")
GUNA = {"i": "e", "I": "e", "u": "o", "U": "o", "f": "ar", "F": "ar", "x": "al", "X": "al"}
AYADI = {"e": "ay", "o": "av", "E": "Ay", "O": "Av"}
JHAL = set("JBGQDjbgqdKPCWTcwtkpSzsh")
YAY = set("yvrlYmNRnJBGQDjbgqdKPCWTcwtkp")
CLASS_NASAL = {**{c: "N" for c in "kKgG"}, **{c: "Y" for c in "cCjJ"}, **{c: "R" for c in "wWqQ"},
               **{c: "n" for c in "tTdD"}, **{c: "m" for c in "pPbB"}, **{c: c for c in "NYRnm"}}
GHATADI = ("01.0867", "01.0932")           # Dhātupāṭha: घटादयो मितः (01.0933), a label in this slice


def tokens(u):
    """upadeśa → [(letter, nasal, accent)]."""
    out = []
    for ch in u:
        if ch == "~" and out:
            out[-1] = (out[-1][0], True, out[-1][2])
        elif ch in "\\^" and out:
            out[-1] = (out[-1][0], out[-1][1], ch)
        else:
            out.append((ch, False, None))
    return out


class Term:
    def __init__(self, text, kind, tags=()):
        self.text, self.kind, self.tags, self.id = text, kind, set(tags), None


class State:
    def __init__(self, root, code, pada_choice=None):
        self.terms = [Term(root, "dhatu")]
        self.terms[0].id = 0
        self.next_id = 1
        self.code = code
        self.pada_choice = pada_choice      # for ubhayapada roots: "atmane" or "parasmai"
        self.trace = []
        self.done = set()                   # (rule, term id) already applied
        self.labelled = set()
        self.decisions = []                 # (operation, candidates, deciding principle)

    def add(self, i, term):
        term.id = self.next_id; self.next_id += 1
        self.terms.insert(i, term)

    def snapshot(self):
        return [t.text for t in self.terms]

    def log(self, rule):
        self.trace.append((rule, self.snapshot()))


# ---------------------------------------------------------------------------------- labels
def it_rules(s, t):
    """1.3.2 / 1.3.3 / 1.3.5 / 1.3.8 mark markers on a fresh term, then 1.3.9 removes them."""
    toks = tokens(t.text)
    it = set()
    if any(n for _, n, _ in toks):
        it |= {i for i, (_, n, _) in enumerate(toks) if n}; s.log("1.3.2")
    last = len(toks) - 1
    if toks and toks[last][0] not in VOWELS:
        it.add(last); s.log("1.3.3")
        if toks[last][0] in "NY":
            t.tags.add("Nit" if toks[last][0] == "N" else "Yit")
    if t.kind == "dhatu" and t.text[:2] in ("Yi", "wu", "qu"):
        it |= {0, 1}; s.log("1.3.5")
    if t.kind == "pratyaya" and "lakara" not in t.tags and toks and toks[0][0] in "lSkKgGN":
        it.add(0); s.log("1.3.8")
    for i in it:                                           # what the markers tell later rules
        ch, nas, acc = toks[i]
        if nas and ch in VOWELS:
            t.tags.add(ch + "dit")                         # idit, udit, Idit …
            if acc == "\\": t.tags.add("anudattet")
            if acc == "^": t.tags.add("svaritet")
    if it:
        t.text = "".join(ch for i, (ch, _, _) in enumerate(toks) if i not in it)
        s.log("1.3.9")
    else:
        t.text = "".join(ch for ch, _, _ in toks)


def labels(s):
    """Apply every label whose condition holds and that has not applied yet."""
    changed = True
    while changed:
        changed = False
        for t in s.terms:
            if "fresh" in t.tags:
                t.tags.discard("fresh")
                if t.kind == "dhatu":
                    s.log("1.3.1"); t.tags.add("dhatu")
                it_rules(s, t)
                if t.kind == "dhatu":
                    upadesha_rules(s, t)
                    if GHATADI[0] <= s.code <= GHATADI[1]:
                        s.log("01.0933")
                changed = True
        for i, t in enumerate(s.terms):
            nxt = s.terms[i + 1] if i + 1 < len(s.terms) else None
            if t.kind == "pratyaya" and "lakara" in t.tags and t.text == "l" and "pada" not in t.tags:
                d = s.terms[0]
                if "anudattet" in d.tags or "Nit" in d.tags:
                    t.tags |= {"pada", "atmane"}; s.log("1.3.12")
                elif ("svaritet" in d.tags or "Yit" in d.tags) and s.pada_choice != "parasmai":
                    t.tags |= {"pada", "atmane"}; s.log("1.3.72")
                else:
                    t.tags |= {"pada", "parasmai"}; s.log("1.3.78")
                changed = True
            if t.kind == "pratyaya" and ("tin" in t.tags or "Sit" in t.tags) and "sarvadhatuka" not in t.tags:
                t.tags.add("sarvadhatuka"); s.log("3.4.113"); changed = True
            if "sarvadhatuka" in t.tags and "pit" not in t.tags and "Nidvat" not in t.tags:
                t.tags.add("Nidvat"); s.log("1.2.4"); changed = True   # सार्वधातुकमपित्
        d = s.terms[0]
        if len(s.terms) >= 2 and "anga" not in d.tags and "fresh" not in s.terms[1].tags:
            d.tags.add("anga"); s.log("1.4.13"); changed = True        # यस्मात्प्रत्ययविधिस्तदादि प्रत्ययेऽङ्गम्
    return s


def upadesha_rules(s, t):
    """6.1.64 धात्वादेः षः सः and 6.1.65 णो नः act on the root as taught."""
    if t.text[:1] == "z":
        t.text = "s" + t.text[1:]; s.log("6.1.64")
    elif t.text[:1] == "R":
        t.text = "n" + t.text[1:]; s.log("6.1.65")


# ------------------------------------------------------------------------------ operations
# Each returns None (not applicable) or (trigger, scope_in_terms, action)
def op_7_1_58(s):
    d = s.terms[0]
    if "idit" in d.tags and (("7.1.58", d.id) not in s.done):
        def act(s):
            d = s.terms[0]
            last_v = max(i for i, ch in enumerate(d.text) if ch in VOWELS)
            d.text = d.text[:last_v + 1] + "n" + d.text[last_v + 1:]
            s.done.add(("7.1.58", d.id))
        return (d.id, 1, act)


def op_3_2_123(s):
    if len(s.terms) == 1:
        def act(s):
            s.add(1, Term("la~w", "pratyaya", {"lakara", "Wit", "fresh"}))
        return (None, 2, act)


def op_3_4_78(s):
    for i, t in enumerate(s.terms):
        if "lakara" in t.tags and t.text == "l" and "pada" in t.tags:
            atm = "atmane" in t.tags
            def act(s, i=i, atm=atm):
                old = s.terms[i]
                tags = {"tin", "pratyaya", "fresh", "Wit_lakara"} | ({"atmane"} if atm else {"parasmai", "pit"})
                s.terms[i] = Term("ta" if atm else "tip", "pratyaya", tags); s.terms[i].id = old.id
            return (t.id, 1, act)


def op_3_1_68(s):
    if len(s.terms) == 2 and "sarvadhatuka" in s.terms[1].tags:
        def act(s):
            s.add(1, Term("Sap", "pratyaya", {"Sit", "pit", "vikarana", "fresh"}))
        return (s.terms[1].id, 2, act)


def op_3_4_79(s):
    t = s.terms[-1]
    if "atmane" in t.tags and "tin" in t.tags and "e_done" not in t.tags and "fresh" not in t.tags:
        def act(s):
            t = s.terms[-1]
            last_v = max(i for i, ch in enumerate(t.text) if ch in VOWELS)
            t.text = t.text[:last_v] + "e"; t.tags.add("e_done")
        return (t.id, 1, act)


def guna_trigger(s):
    """The affix right after the aṅga, if it can trigger guṇa (sārvadhātuka, not ṅit-like: 1.1.5)."""
    if len(s.terms) < 2:
        return None
    nxt = s.terms[1]
    if "sarvadhatuka" in nxt.tags and "Nidvat" not in nxt.tags:       # 1.1.5 क्ङिति च
        return nxt
    return None


def op_7_3_84(s):
    d, nxt = s.terms[0], guna_trigger(s)
    if nxt and d.text[-1] in IK and ("guna", d.id) not in s.done:
        def act(s):
            d = s.terms[0]; d.text = d.text[:-1] + GUNA[d.text[-1]]; s.done.add(("guna", d.id))
        return (nxt.id, 2, act)


def op_7_3_86(s):
    d, nxt = s.terms[0], guna_trigger(s)
    if nxt and len(d.text) >= 2 and d.text[-1] not in VOWELS and d.text[-2] in "iufx" and ("guna", d.id) not in s.done:
        def act(s):
            d = s.terms[0]; d.text = d.text[:-2] + GUNA[d.text[-2]] + d.text[-1]; s.done.add(("guna", d.id))
        return (nxt.id, 2, act)


def op_6_1_78(s):
    for i in range(len(s.terms) - 1):
        a, b = s.terms[i], s.terms[i + 1]
        if a.text and b.text and a.text[-1] in AYADI and b.text[0] in VOWELS and "fresh" not in b.tags:
            def act(s, i=i):
                a = s.terms[i]; a.text = a.text[:-1] + AYADI[a.text[-1]]
            return (b.id, 2, act)


OPERATIONS = {"7.1.58": op_7_1_58, "3.2.123": op_3_2_123, "3.4.78": op_3_4_78, "3.1.68": op_3_1_68,
              "3.4.79": op_3_4_79, "7.3.84": op_7_3_84, "7.3.86": op_7_3_86, "6.1.78": op_6_1_78}
NUM = lambda r: tuple(int(x) for x in r.split("."))


def applicable(s):
    return {r: v for r, f in OPERATIONS.items() if (v := f(s))}


def still_applies(s, first, second):
    """After applying `first` in a copy, does `second` still apply with the same trigger?"""
    trig = applicable(s)[second][0]
    t = copy.deepcopy(s)
    applicable(t)[first][2](t); labels(t)
    again = applicable(t).get(second)
    return bool(again) and again[0] == trig


def compare(s, a, b, cand):
    """(a wins over b?, deciding principle) — paribhāṣā: para < nitya < antaraṅga < apavāda."""
    sa, sb = cand[a][1], cand[b][1]
    if sa != sb:
        return sa < sb, "antaranga"                      # narrower condition
    na, nb = still_applies(s, b, a), still_applies(s, a, b)
    if na != nb:
        return na, "nitya"                               # applies whether or not the other has
    return NUM(a) > NUM(b), "para"                       # 1.4.2 विप्रतिषेधे परं कार्यम्


def choose(s, cand):
    names = list(cand)
    for a in names:
        results = [compare(s, a, b, cand) for b in names if b != a]
        if all(w for w, _ in results):
            order = ["para", "nitya", "antaranga"]
            return a, max((p for _, p in results), key=order.index)
    raise AssertionError(f"no winner among {names}")


class Unsupported(Exception):
    pass


def derive(root, code, pada_choice=None, order=None):
    """Derive the 3rd singular present active form. `order`, if given, is a list of operation
    names to apply in exactly that order instead of arbitrating (used to replay Vidyut)."""
    if "H" in root:
        raise Unsupported(root)                          # Dhātupāṭha notation outside this slice
    s = State(root, code, pada_choice)
    s.terms[0].tags.add("fresh")
    labels(s)
    for _ in range(40):
        cand = applicable(s)
        if not cand:
            break
        if order is not None:
            if not order:
                break
            r = order.pop(0)
            if r not in cand:
                raise AssertionError(f"{r} is not applicable here; applicable: {sorted(cand)}")
        else:
            r, why = choose(s, cand) if len(cand) > 1 else (next(iter(cand)), "single")
            s.decisions.append((r, sorted(cand), why))
        cand[r][2](s); s.log(r)
        labels(s)
    s.log("1.4.14")                                        # सुप्तिङन्तं पदम्
    # Tripādī (8.2.1: once each, in order, after every earlier rule)
    word = "".join(t.text for t in s.terms)
    d = s.terms[0]
    for i in range(len(d.text) - 1):                    # 8.3.24 नश्चापदान्तस्य झलि (inside the root)
        if d.text[i] in "nm" and d.text[i + 1] in JHAL:
            d.text = d.text[:i] + "M" + d.text[i + 1:]; s.log("8.3.24")
            if d.text[i + 1] in YAY:                     # 8.4.58 अनुस्वारस्य ययि परसवर्णः
                d.text = d.text[:i] + CLASS_NASAL[d.text[i + 1]] + d.text[i + 1:]; s.log("8.4.58")
            break
    word = "".join(t.text for t in s.terms)
    if "a" in word:
        s.log("8.4.68")                                   # अ अ
    derive.last = s
    return word, s.trace


# --------------------------------------------------------------------------------------
# Test vectors for hardware/tb/tb_prakriya_core.v, and the comparison with Vidyut
# --------------------------------------------------------------------------------------
import os
import sys
import shutil
import tempfile
import collections

HERE = os.path.dirname(os.path.abspath(__file__))
VEC = os.path.join(os.path.dirname(HERE), "tb", "vectors")
DATA = os.path.join(os.path.dirname(os.path.dirname(HERE)), "data", "sources", "vidyut", "dhatupatha.tsv")
LETTER = {**{v: i for i, v in enumerate("aAiIuUfFxXeEoO")},
          "h": 14, "y": 15, "v": 16, "r": 17, "l": 18, "Y": 19, "m": 20, "N": 21, "R": 22, "n": 23,
          "J": 24, "B": 25, "G": 26, "Q": 27, "D": 28, "j": 29, "b": 30, "g": 31, "q": 32, "d": 33,
          "K": 34, "P": 35, "C": 36, "W": 37, "T": 38, "c": 39, "w": 40, "t": 41, "k": 42, "p": 43,
          "S": 44, "z": 45, "s": 46, "M": 47}
RULE_ID = {r: i + 1 for i, r in enumerate(["1.3.1", "1.3.2", "1.3.3", "1.3.5", "1.3.8", "1.3.9", "6.1.64", "6.1.65",
           "01.0933", "7.1.58", "3.2.123", "1.3.12", "1.3.72", "1.3.78", "1.4.13", "3.4.78", "3.4.113", "1.2.4",
           "3.1.68", "3.4.79", "7.3.84", "7.3.86", "6.1.78", "1.4.14", "8.3.24", "8.4.58", "8.4.68"])}
WHY = {"single": 0, "antaranga": 1, "nitya": 2, "para": 3}
T1 = {None: 0, "Sap": 1, "a": 2}
T2 = {None: 0, "la~w": 1, "l": 2, "tip": 3, "ti": 4, "ta": 5, "te": 6}
DMAX, TMAX, SMAX = 12, 12, 26


def snapshot_words(texts):
    d = [ch for ch in texts[0] if ch not in "~\\^"]
    t1 = texts[1] if len(texts) == 3 else None
    t2 = texts[-1] if len(texts) >= 2 else None
    assert len(d) <= DMAX, texts
    return [len(d)] + [LETTER[c] for c in d] + [63] * (DMAX - len(d)) + [T1[t1], T2[t2]]


def form_vector(root, code, choice):
    word, trace = derive(root, code, choice)
    toks = tokens(root)
    assert len(toks) <= TMAX
    ins = [len(toks)]
    for ch, nas, acc in toks + [("", False, None)] * (TMAX - len(toks)):
        ins += [LETTER.get(ch, 63), int(nas), {None: 0, "\\": 1, "^": 2}[acc]]
    ins += [int(GHATADI[0] <= code <= GHATADI[1]), {None: 0, "atmane": 1, "parasmai": 2}[choice]]
    decisions = iter(derive.last.decisions)
    steps = []
    for rule, texts in trace:
        why = WHY[next(decisions)[2]] if rule in OPERATIONS else 0
        steps.append([RULE_ID[rule], why] + snapshot_words(texts))
    assert len(steps) <= SMAX
    return word, ins, steps


def roots_in_slice():
    """First-class roots whose Vidyut derivation (3rd sg. present active) uses only rules this core has."""
    import vidyut.prakriya as P
    folder = tempfile.mkdtemp()
    shutil.copyfile(DATA, os.path.join(folder, "dhatupatha.tsv"))
    entries = [e for e in P.Data(folder).load_dhatu_entries() if e.code.startswith("01.")]
    shutil.rmtree(folder, ignore_errors=True)
    v = P.Vyakarana()
    have = set(OPERATIONS) | set(RULE_ID) | {"8.3.110", "8.3.111"}
    out, outside = [], 0
    for e in entries:
        u = e.dhatu.aupadeshika
        fs = v.derive(P.Pada.Tinanta(e.dhatu, P.Prayoga.Kartari, P.Lakara.Lat, P.Purusha.Prathama, P.Vacana.Eka))
        if "H" in u or not fs or not all({s.code for s in f.history} <= have for f in fs):
            outside += 1; continue
        out.append((e, fs))
    return out, outside, len(entries)


def main():
    os.makedirs(VEC, exist_ok=True)
    try:
        import vidyut.prakriya  # noqa: F401
    except ImportError:
        print("prakriya_ref: vidyut is not installed (pip install vidyut==0.4.0); using the committed vectors")
        return
    roots, outside, total = roots_in_slice()
    notes = {"8.3.110", "8.3.111"}
    stats = collections.Counter(); swaps = collections.Counter(); vectors = []
    for e, fs in roots:
        u = e.dhatu.aupadeshika
        for f in fs:
            choice = ("atmane" if f.text.endswith("te") else "parasmai") if len(fs) > 1 else None
            word, ins, steps = form_vector(u, e.code, choice)
            vc = [s.code for s in f.history if s.code not in notes]
            mc = [r for r, _ in derive.last.trace]
            ops = lambda seq: [c for c in seq if c in OPERATIONS]
            rword, rtrace = derive(u, e.code, choice, order=ops(vc))            # replay Vidyut's order
            key = lambda c: c in OPERATIONS or c in ("6.1.64", "6.1.65", "8.3.24", "8.4.58")
            replay = rword == f.text and [(s.code, list(s.result)) for s in f.history if key(s.code)] == [(r, x) for r, x in rtrace if key(r)]
            stats["forms"] += 1
            stats["form"] += word == f.text
            stats["rules"] += collections.Counter(vc) == collections.Counter(mc)
            stats["replay"] += replay
            if ops(vc) == ops(mc):
                stats["same_order"] += 1
            else:
                a, b = ops(vc), ops(mc)
                i = next(k for k in range(len(a)) if a[k] != b[k])
                swaps[(a[i], a[i + 1])] += 1
                assert a[:i] + [a[i + 1], a[i]] + a[i + 2:] == b, (u, a, b)   # one adjacent swap only
            vectors.append((ins, steps))
    with open(os.path.join(VEC, "prakriya_ref.mem"), "w") as fh:
        fh.write("// per form: ntok, 12 x (letter nasal accent), ghatadi, pada_choice, nsteps, then 26 x "
                 "(rule why dlen d[12] t1 t2) — hex, generated by hardware/scripts/prakriya_ref.py\n")
        for ins, steps in vectors:
            words = ins + [len(steps)]
            for st in steps + [[0] * 17] * (SMAX - len(steps)):
                words += st
            fh.write(" ".join(f"{w:x}" for w in words) + "\n")
    with open(os.path.join(VEC, "prakriya_counts.vh"), "w") as fh:
        fh.write(f"`define PRAKRIYA_FORMS {len(vectors)}\n")
    print(f"slice: {len(roots)} of {total} first-class roots ({outside} use rules outside it); {stats['forms']} forms")
    print(f"vs Vidyut: forms {stats['form']}, rule sets {stats['rules']}, Vidyut's order replayed {stats['replay']}, "
          f"same operation order {stats['same_order']}; differences: {dict(swaps)}")
    if not (stats["form"] == stats["rules"] == stats["replay"] == stats["forms"]):
        sys.exit("The reference model disagrees with Vidyut.")


if __name__ == "__main__":
    main()
