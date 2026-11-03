# Paninian datapath (Maataa AAI × Siddham)

This is a small piece of hardware that applies Panini's vowel-sandhi rules exactly. It is checked against an independent reference model and against Vidyut, the open-source Sanskrit engine (MIT), on every vowel pair.

## Architecture

| Panini | Hardware |
| --- | --- |
| Shiva Sutras and pratyāhāras (1.1.71) | `sivasutra_rom.v`: position-range comparators over the 43 Shiva Sutra slots |
| Each sutra's conditions, read with anuvṛtti | One parallel match block per sutra in `sandhi_engine.v`. Anuvṛtti is expanded when the logic is written, so it costs nothing at run time |
| Exception beats the general rule (apavāda > utsarga) | An override matrix after the match blocks |
| Saptādhyāyī (1.1–8.1): rules compete and repeat | Phase 1 of `panini_datapath.v`: match, arbitrate, latch, re-check, until no rule fires |
| Tripādī (8.2–8.4), invisible to earlier rules (8.2.1 पूर्वत्रासिद्धम्) | Phase 2: ordered stages with no feedback |
| Optional rules | Two outputs: the result and, when it applies, the alternative |

### Pratyāhāra ROM

A pratyāhāra is a range in a fixed order. Membership therefore needs two 6-bit comparisons per slot, not a CAM. Two known quirks are handled exactly:

- **ह appears twice**, in हयवरट् (slot 9) and in हल् (slot 42). ह is a member if either slot is in range, so शल् is श ष स ह, and हश् starts at the first ह.
- **ण् closes two sutras**, अइउण् and लण्. The marker is given as a sutra number, so aṇ(1) = अ इ उ and aṇ(6) = अ … ल are different inputs. By the traditional rule, every aṇ in the grammar means aṇ(1), for example 1.1.51 उरण् रपरः and 6.3.111. The one exception is 1.1.69 अणुदित् सवर्णस्य, which means aṇ(6). Every iṇ uses the later ण्.

When `savarna_expand` is on, 1.1.69 adds the long vowels, so ac includes आ ई ऊ ॠ ॡ.

### Rules in the sandhi engine (Phase 1)

| Rule | Condition, with anuvṛtti | Result |
| --- | --- | --- |
| 6.1.77 इको यणचि | इक् + अच् | य व र ल of the first vowel's place, then the second vowel |
| 6.1.78 एचोऽयवायावः | एच् + अच् | अय् अव् आय् आव्, then the second vowel |
| 6.1.87 आद्गुणः | अ/आ + अच् (अचि inherited from 6.1.77) | the nearest guṇa vowel: अ ए ओ अर् अल् |
| 6.1.88 वृद्धिरेचि | अ/आ + एच् | ऐ or औ |
| 6.1.101 अकः सवर्णे दीर्घः | अक् + a vowel of the same place | the long vowel of that place |
| 6.1.109 एङः पदान्तादति | pada-final ए/ओ + अ | ए/ओ, with the अ written as ऽ |

The override matrix works as follows:

- 6.1.101 overrides 6.1.77 (इ + इ gives ई) and 6.1.87 (अ + अ gives आ).
- 6.1.88 overrides 6.1.87 (अ + ए gives ऐ).
- 6.1.109 overrides 6.1.78 (pada-final ए + अ gives एऽ).

After the override, at most one rule is left, so 1.4.2 (the later rule wins) is never needed for this set. The `conflict` output flags it if a future rule set ever leaves two.

### Tripādī stage (Phase 2)

The first stage is 8.3.19 लोपः शाकल्यस्य. It optionally drops a pada-final य or व after अ/आ before a vowel: ए + इ gives अयि, or अ इ. Phase 1 cannot see this stage, so अ इ is not merged again into ए. This is pūrvatrāsiddham in hardware.

## Verification

Run `make sim-panini` (also part of `npm run test:rtl`). It does three things:

1. `hardware/scripts/panini_ref.py` writes the test vectors. It is a separate Python implementation written from the sutras, and it checks itself against Vidyut first.
2. Icarus Verilog runs `hardware/tb/tb_panini_datapath.v`:
   - 13 pratyāhāra checks on the ROM, including ह and both ण् readings;
   - 338 cases against the reference: all 13 × 13 vowel pairs, both inside a word and at a word boundary. Each case checks the winning rule, the result, the avagraha, the 8.3.19 alternative and the loop count;
   - 143 cases against Vidyut's word-boundary vowel sandhi (`vidyut-sandhi` `generate_rules()` at commit 8da2f90, saved in `hardware/tb/vectors/vidyut_vowel_sandhi.tsv`). Vidyut's result must be the datapath's result or its 8.3.19 alternative.
3. Any mismatch stops the run.

The testbench catches injected bugs. For example, removing the 6.1.101-over-6.1.77 override, or writing आव् for ऐ, each gives 26 mismatches against the reference.

### Current result

```
Shiva Sutra ROM: 13 pratyahara checks passed
Reference model: 338 of 338 cases agree
Vidyut golden: 143 of 143 word-boundary cases agree
PANINI DATAPATH: PASS
```

### Size

Yosys `synth_ice40`, whole datapath: 208 LUT4s, 94 flip-flops and 14 carry cells. That is about 4% of an iCE40 UP5K. The generic ROM on its own, with variable inputs, is 169 LUT4s. Inside the engine its inputs are constants, so it reduces to fixed masks.

## Consonant and visarga sandhi (hal sandhi)

`hal_sandhi_pipeline.v` (with `hal_sandhi_stages.v` and `hal_classes.vh`) handles the word boundary. The juncture is held in fixed slots:

| Slot | What it holds |
| --- | --- |
| V | the last vowel of the first word |
| C1 | its final consonant: क ट त प न म स र, or none |
| C2 | a sound that rules insert |
| R | the next word's first sound, or a pause |
| R2 | the sound after R, for the two rules that look ahead |

### Three registered stages, in Panini's order

| Stage | Rules |
| --- | --- |
| A | 6.1.73 छे च and 6.1.76 पदान्ताद्वा (tuk before छ), then 8.2.39 झलां जशोऽन्ते and 8.2.66 ससजुषो रुः |
| B (8.3) | 8.3.4, 8.3.7 नश्छव्यप्रशान्, 8.3.14 रो रि, 8.3.15, 8.3.17 भोभगोअघोअपूर्वस्य योऽशि, 8.3.19, 8.3.22, 8.3.23 मोऽनुस्वारः, 8.3.30 नश्च, 8.3.31 शि तुक्, 8.3.32 ङमो ह्रस्वादचि ङमुण्नित्यम्, 8.3.34 विसर्जनीयस्य सः, 8.3.36 वा शरि, 8.3.37 कुप्वोः ≍क≍पौ च |
| C (8.4) | 8.4.40 स्तोः श्चुना श्चुः, 8.4.41 ष्टुना ष्टुः (with 8.4.42), 8.4.45, 8.4.55 खरि च, 8.4.56 वावसाने, 8.4.59 वा पदान्तस्य, 8.4.60 तोर्लि, 8.4.62 झयो होऽन्यतरस्याम्, 8.4.63 शश्छोऽटि |

One juncture enters per clock, and its forms come out three clocks later. Every form carries a 32-bit trace with one bit per sutra applied.

### Where the strict two-phase model breaks

Three Saptādhyāyī rules have to act on a result of the Tripādī:

- 6.1.113 अतो रोरप्लुतादप्लुते and 6.1.114 हशि च act on *ru*, which only 8.2.66 creates. That is how रामः + अपि gives रामोऽपि and रामः + गच्छति gives रामो गच्छति.
- 6.3.111 ढ्रलोपे पूर्वस्य दीर्घोऽणः lengthens the vowel before an r lost by 8.3.14. That is how पुनर् + रमते gives पुना रमते.

By 8.2.1 पूर्वत्रासिद्धम् the Tripādī is invisible to earlier rules. The tradition resolves the conflict this way: a rule that names a Tripādī result must be able to see it. The hardware has an explicit bypass for exactly these three rules. Everything else in the Tripādī stays feed-forward.

### Optional rules as lanes

Many rules here are optional (वा, विभाषा, अन्यतरस्याम्, or a named teacher). Each one forks a candidate into the next free lane, so the output is the set of correct forms. Lane 0 never takes an optional rule. Three forms is the most any juncture produces: न् + श gives ञ्श, ञ्च्श or ञ्च्छ, by 8.3.31 and 8.4.63. The reference model checks, on every juncture, that each stage applies at most one optional rule. The hardware therefore needs only one fork slot per stage.

### Verification

`hardware/scripts/hal_ref.py` is the reference model, written from the sutras.

**Against the hardware** (`tb_hal_sandhi.v`, streaming one juncture per clock):

- 11,844 junctures agree: 14 left vowels (or none) × 9 endings × 47 next sounds (or a pause) × 2 look-ahead contexts.
- That covers 13,940 forms.
- For each form the testbench checks every slot, the avagraha, the form count and the full sutra trace.
- Injected bugs are caught: removing 6.3.111 gives 10 mismatches, and dropping the look-ahead from 8.4.63 gives 70.

**Against Vidyut** (all 1,468 entries of `generate_rules()`, saved in `hardware/tb/vectors/vidyut_sandhi_all.tsv`):

- 1,305 of the 1,314 consonant and visarga entries agree.
- The other 9 are listed with reasons in `hardware/tb/vectors/hal_vidyut_report.md`.
- The script fails if a new, unexplained difference appears.
- The 9 differences fall into three groups:
  - **ऋ before a lost r (2):** 6.3.111 lengthens only aṇ = अ इ उ, but Vidyut also lengthens ऋ.
  - **त् or न् before ञ or ण (4):** Vidyut skips 8.4.40 and 8.4.41 here. No Sanskrit word begins with ञ or ण.
  - **Entries Vidyut itself marks as fallbacks, or copied from its त् rules (3):** न् + ह → द्ध, न् + श → च्छ, and न् + ल → ंल.

### Size

Yosys `synth_ice40` with 3 lanes: 1,550 LUT4s, 358 flip-flops and 175 carry cells. An earlier version that packed lanes by computed index took more than 23,000 LUTs. Placing the one fork after the mains brought it down to this.

## Not modelled yet

- The vārttika that makes ऋ and ऌ savarṇa.
- Pluta vowels.
- Optional anunāsika vowels (8.3.2): only the anusvāra forms are produced.
- Nasal य and व by 8.4.59.
- Sandhi inside a word, such as ṇatva (8.4.1) and ṣatva (8.3.59).
- Chains of more than one juncture.

## Prakriyā core: derivation with speculative precedence

`prakriya_core.v` (with `prakriya_ops.vh`) derives a whole word from a root. The current slice is:

- present tense (laṭ), active voice (kartari), 3rd person singular;
- roots of the first class (bhvādi);
- input: the root as taught (upadeśa), letter by letter with its nasal and accent marks;
- output: one step per clock, each with the sutra applied, how it was chosen, and the full state after it (root text, vikaraṇa, ending).

| Kind | Rules | How they run |
| --- | --- | --- |
| Labels | 1.3.1, 1.3.2, 1.3.3, 1.3.5, 1.3.8, 1.3.9, 1.3.12, 1.3.72, 1.3.78, 3.4.113, 1.2.4, 1.4.13, the gaṇasūtra 01.0933 | emitted right after the step that creates their condition |
| The root as taught | 6.1.64 धात्वादेः षः सः, 6.1.65 णो नः | applied when its markers are removed |
| Operations | 7.1.58, 3.2.123, 3.4.78, 3.1.68, 3.4.79, 7.3.84, 7.3.86, 6.1.78 | compete each step |
| Tripādī | 8.3.24, 8.4.58, 8.4.68 | once each, in order, at the end |

### Choosing between operations

When more than one operation applies, the core decides by परनित्यान्तरङ्गापवादानामुत्तरोत्तरं बलीयः (each later principle is stronger than the ones before it):

- **antaraṅga:** the operation whose condition spans fewer terms goes first.
- **nitya:** decided by speculative evaluation.
  - The core applies each candidate, with its labels, to a shadow copy of the state, one candidate per clock.
  - It then re-evaluates every operation block on that shadow.
  - An operation that still applies after the other one, with the same trigger, is nitya and goes first. "Same trigger" means the same *nimitta*, the affix that sets it off.
  - Example, भू + तिप्: after śap (3.1.68), guṇa would be triggered by śap instead of तिप्. That is a different trigger, so guṇa is not nitya, and 3.1.68 goes first. This is how भवति is derived.
- **para (1.4.2):** if neither of the above decides, the later sutra goes first.
- **apavāda:** no exception pair occurs in this slice.

One shared action unit and one extra operation-block unit serve every candidate. A fully parallel version, with eight shadow copies, took 9,734 LUT4s.

### Verification

`hardware/scripts/prakriya_ref.py` is the reference engine. Its rules are separate functions, and it uses the same arbitration as the hardware.

**Against Vidyut's own derivations:**

- The slice covers 981 of the 1,156 first-class roots, which give 1,042 forms. The other 175 roots use rules the core does not have yet.
- All 1,042 forms are identical, and every form applies the same multiset of rules.
- Vidyut's own order replays step by step through this engine's rules, with an identical state after every step.
- The order of operations is the same in 651 forms. In the other 391, the engine applies 3.4.79 (त → ते) before 3.1.68 (śap), because 3.4.79 is antaraṅga; Vidyut applies śap first. The two steps commute, so the result is the same either way. The engine's order matches the Siddhānta-kaumudī derivation of एधते.
- The script fails on any other difference.

**Against the hardware** (`tb_prakriya_core.v`):

- All 1,042 forms agree, step by step: 21,707 steps.
- Each step checks the sutra, the deciding principle and the complete state.
- 573 steps are decided by antaraṅga and 127 by nitya. Para never decides in this slice.
- Disabling the speculative nitya test breaks 127 forms: guṇa would come before śap, triggered by तिप्. The words come out the same, but the derivation is wrong.
- Disabling antaraṅga breaks 501 forms. Para happens to give the same order there, but the reason recorded for each step is then wrong.

### Size

Yosys `synth_ice40` (0.33): 6,176 LUT4s, 246 flip-flops and 1,078 carry cells. That fits an iCE40 HX8K (7,680 LUTs) or an ECP5, but not an iCE40 UP5K.

### Next for the prakriyā core

- All nine person and number forms. These need 7.1.3, 6.1.97, 7.3.101, 3.4.80, 7.2.81 and visarga at the end.
- The 175 first-class roots outside the slice (6.1.97, 7.3.78, 8.3.59, 8.4.2 …), then the other classes.
- Apavāda pairs in the arbiter.
- Feeding the finished word into the sandhi engines.

Licences: the sutra text and the Vidyut golden vectors are MIT (ambuda.org); see `data/sources/vidyut/LICENSE-vidyut.md`.
