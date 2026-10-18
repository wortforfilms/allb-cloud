# Repository inventory

Baseline date: 2026-08-29

Baseline tag: `baseline-2026-08-29` at `623ff64cf66ec8d85e4dbfae6162dd3811b36e58`

## Authority classification

| Path | Class | Baseline contents | Retention rule |
| --- | --- | ---: | --- |
| Repository root | Canonical manifests, licences and governance configuration | 17 files | Commit |
| `src/` | Canonical runtime source | 13 files | Commit |
| `crates/` | Canonical shared contracts | 2 files | Commit |
| `data/` | Canonical runtime data | 1 file | Commit with provenance |
| `c_src/` | Canonical native HAL | 3 files | Commit |
| `hardware/` | Canonical RTL and verification | 20 files | Commit source; ignore output |
| `apps/` | Deployable product applications | 45 files | Commit source and intentional UI assets |
| `services/` | Edge service | 7 files | Commit source and generated binding |
| `sdk/`, `python/` | Supported clients | 10 files | Commit |
| `contracts/` | Specifications, schemas and fixtures | 5 files | Commit |
| `generated/` | Deterministic language projections | 2 files | Commit; never hand-edit |
| `tests/` | Cross-runtime verification | 4 files | Commit |
| `scripts/` | Build/generation/hygiene tools | 7 files | Commit |
| `docs/` | Architecture, evidence and product boundaries | 15 files | Commit |
| `demos/` | Controlled example surfaces | 15 files | Commit only when clearly labeled |
| `references/` | Non-runtime historical/design material | 33 files | Commit as reference; never operational authority |
| `infra/` | Environment-specific infrastructure source | 1 file | Commit; deployment remains approval-bound |
| `vendor/nextpnr` | Pinned upstream submodule | 2,012 upstream files | Preserve submodule pin |

Counts above are from the Git tree at `baseline-2026-08-29` (commit
`623ff64`). The upstream submodule's internal file count is reported
separately because the canonical repository stores only its pinned reference.

## Generated and disposable content

The baseline intentionally excludes `target/`, `pkg/`, `node_modules/`,
`.wrangler/`, Python bytecode, simulator traces, FPGA caches and CMake `build/`.
The previously tracked CMake directory contained object files, compiler paths,
cache files and `libmaataa_hal.dylib`; it was removed because it is
machine-specific and fully reproducible from `CMakeLists.txt` and `c_src/`.

## Large files

`references/siddham/landing-pages.html` is the only non-Git file above 10 MiB
at baseline. It is a historical design archive, not a runtime dependency. The
`vendor/nextpnr` submodule has independent upstream history.

## External Siddham path

`/Users/vesahe/Documents/GitHub/siddhamsemiconductor` was absent when Phase 0
was finalized and remained absent when checked on 2026-10-18. No external
directory was deleted or moved. The Siddham material available in this
repository is classified under `apps/`, `demos/` and `references/`; this is not
an assertion that an external source archive exists.

## Known limitations

- This inventory describes the tagged 2026-08-29 baseline, not a live file
  count for later commits. The annotated baseline tag remains immutable.
- Hosted clean-clone CI evidence is a Phase 1 gate.
- Reference licences and provenance require continuing review before any
  external redistribution or commercial use.
- File counts describe the baseline shape and will change through normal
  development; authority classifications are normative.
