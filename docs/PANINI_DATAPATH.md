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
- **ण् closes two sutras**, अइउण् and लण्. The marker is given as a sutra number, so aṇ(1) = अ इ उ (used by 1.1.51 उरण् रपरः) and aṇ(6) = अ … ल are different inputs.

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

## Not modelled yet

- The vārttika that makes ऋ and ऌ savarṇa.
- Pluta and nasal vowels.
- Consonant and visarga sandhi.
- The state-dependent precedence principles *nitya* and *antaraṅga*. These need speculative evaluation (try both orders and compare), which is the next step for the arbiter.

Licences: the sutra text and the Vidyut golden vectors are MIT (ambuda.org); see `data/sources/vidyut/LICENSE-vidyut.md`.
