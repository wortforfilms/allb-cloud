# ADR 0002: One home for the Brahmi tokenizer

- Status: Accepted
- Date: 2026-10-31

## Context

Brahmi akshara segmentation existed in four places with different rules:

- `src/brahmi_tokenizer.rs`, used by `maataa_runtime_node` and `replay_test`.
  It treated U+11038 (vowel sign AA) as a consonant and split it from its
  base, and it left anusvara and visarga as separate tokens.
- A second `BrahmiScriptTokenizer` inside `src/maataa_runtime_pipeline.rs`
  with corrected boundaries and L2-normalised embeddings.
- `sdk/python/brahmi_tokenizer.py`, which also split anusvara and visarga,
  and whose own self-test failed because multi-code-point aksharas encoded
  to `[UNK]`.
- The `maataa-apps` repository (`core/python-ml/maataa_ml/script_matrices.py`
  and `packages/lipi-runtime`), which annotates script datasets and holds the
  Lipi registry, glyph and learning data.

## Decision

- `allb.xyz` `src/brahmi_tokenizer.rs` is the only implementation of Brahmi
  akshara segmentation. It carries the corrected pipeline rules.
- `src/maataa_runtime_pipeline.rs` re-exports that type and has no copy.
- `tests/fixtures/brahmi_aksharas.json` is the shared contract. The Rust
  module and the Python SDK are both tested against it.
- `sdk/python/brahmi_tokenizer.py` is a mirror. A rule change goes into the
  Rust module and the fixture first, then the mirror.
- The WASM exports `tokenize_brahmi_script`, `tokenize_brahmi_metadata` and
  `tokenize_brahmi_zerocopy` stay code-point filters. Their names do not
  promise aksharas and the edge contract depends on them.
- `maataa-apps` does not implement Brahmi tokenization. `lipi-runtime` keeps
  the script registry, lessons, lineage and glyph data. `script_matrices.py`
  stays a dataset annotator (transliteration, phoneme class). If an app needs
  aksharas it calls the allb WASM package or the edge API.

## Known limits

- Conjuncts are not merged: a virama stays with its consonant and the next
  consonant starts a new token.
- The embedding vocabulary holds single code points, so multi-code-point
  aksharas map to `[UNK]` in `tokens_to_embedding`.
