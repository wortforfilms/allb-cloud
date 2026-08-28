# Repository inventory

Baseline date: 2026-08-29

## Authority classification

| Path | Class | Baseline contents | Retention rule |
| --- | --- | ---: | --- |
| `src/` | Canonical runtime source | 13 files | Commit |
| `crates/` | Canonical shared contracts | 2 files | Commit |
| `data/` | Canonical runtime data | 1 file | Commit with provenance |
| `c_src/` | Canonical native HAL | 3 files | Commit |
| `hardware/` | Canonical RTL and verification | 20 files | Commit source; ignore output |
| `apps/` | Deployable product applications | 48 files | Commit source and intentional UI assets |
| `services/` | Edge service | 7 files | Commit source and generated binding |
| `sdk/`, `python/` | Supported clients | 10 files | Commit |
| `contracts/` | Specifications, schemas and fixtures | 5 files | Commit |
| `generated/` | Deterministic language projections | 2 files | Commit; never hand-edit |
| `tests/` | Cross-runtime verification | 4 files | Commit |
| `scripts/` | Build/generation/hygiene tools | 4 files before Phase 0 additions | Commit |
| `docs/` | Architecture, evidence and product boundaries | 9 files before Phase 0 additions | Commit |
| `demos/` | Controlled example surfaces | 15 files | Commit only when clearly labeled |
| `references/` | Non-runtime historical/design material | 33 files | Commit as reference; never operational authority |
| `infra/` | Environment-specific infrastructure source | 1 file | Commit; deployment remains approval-bound |
| `vendor/nextpnr` | Pinned upstream submodule | 2,012 upstream files | Preserve submodule pin |

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
was finalized. No external directory was deleted or moved. The consolidated
Siddham material is classified under `apps/`, `demos/` and `references/`.

## Known limitations

- The worktree must be committed and tagged before this inventory becomes an
  immutable baseline.
- Hosted clean-clone CI evidence is a Phase 1 gate.
- Reference licences and provenance require continuing review before any
  external redistribution or commercial use.
- File counts describe the baseline shape and will change through normal
  development; authority classifications are normative.
