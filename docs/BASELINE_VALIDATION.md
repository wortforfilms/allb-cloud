# Phase 0 baseline validation

Validation date: 2026-08-29
Created annotated tag: `baseline-2026-08-29`
Tag target: `623ff64cf66ec8d85e4dbfae6162dd3811b36e58`

## Result

The consolidated source baseline passes the local validation gates below. It
is an engineering baseline, not production certification. Hosted clean-clone
matrix evidence remains the first Phase 1 gate.

| Gate | Result | Evidence |
| --- | --- | --- |
| Disk capacity preflight | Pass | 6 GiB minimum enforced before heavy CI jobs |
| Repository hygiene | Pass | 204 worktree files scanned; no secret-pattern match or prohibited generated directory retained |
| Large-file scan | Pass with documented reference | Only `references/siddham/landing-pages.html` exceeds 10 MiB; it is classified historical reference |
| Deletion review | Pass | Only machine-generated tracked CMake output was removed; no canonical source deletion |
| JSON validation | Pass | Root, desktop and contract JSON parsed |
| CI YAML validation | Pass | Workflow parsed successfully |
| Contract drift | Pass | Deterministic generated outputs match |
| Python contract tests | Pass | 2 tests |
| TypeScript/WASM consumer tests | Pass | 16 tests after WASM rebuild |
| TypeScript type-check | Pass | Root SDK/Worker surfaces |
| Rust format | Pass | Entire workspace |
| Rust Clippy | Pass | Workspace, all targets, warnings denied |
| Rust tests | Pass | 3 runtime + 10 Authority + 2 contract tests |
| Desktop frontend | Pass | Type-check and production Vite build |
| RTL verification | Pass | DMA regression, integrated DMA/NPU regression and top-level compile check |
| Worker bundle | Pass | Staging dry-run; 658.71 KiB upload, 203.51 KiB gzip |
| npm vulnerability audit | Pass | Root and desktop report zero vulnerabilities after lockfile remediation |
| RustSec vulnerability audit | Pass with warnings | Zero vulnerabilities; 18 allowed dependency warnings recorded below |
| Dependency licence metadata | Pass | 515 Rust packages and 318 npm package records declare licence metadata |

## RustSec warnings

The RustSec scan reports allowed warnings rather than known vulnerabilities:

- unmaintained GTK3-era transitive crates: `atk`, `atk-sys`, `gdk`, `gdk-sys`,
  `gdkwayland-sys`, `gdkx11`, `gdkx11-sys`, `gtk`, `gtk-sys`, `gtk3-macros`;
- unmaintained `proc-macro-error` and `unic-*` transitive crates;
- unsound `glib 0.18.5` advisory `RUSTSEC-2024-0429`;
- yanked `chacha20 0.10.1`.

These are baseline risks, not suppressed production findings. Phase 1 must map
their dependency paths and remove, upgrade or explicitly govern them before a
production candidate.

## Environment notes

- The repository pins Node 24; the local verification host had Node 22.22.3,
  so npm emitted an engine warning. CI is configured for Node 24.
- `wasm-pack 0.13.1` reported that 0.15.0 is available. The observed version is
  recorded in `TOOLCHAIN_BASELINE.md`; Phase 1 owns automation of auxiliary
  tool pins.
- The MAATAA HAL reported physical `/dev/mem` unavailable and ran its explicit
  hardware simulation path. This is not physical NPU evidence.
- The Worker command was `--dry-run`; it proves bundle construction only.

## External source archive

The former `/Users/vesahe/Documents/GitHub/siddhamsemiconductor` directory was
absent at validation time. No external directory was deleted or moved. The
consolidated Siddham content is classified within this repository, and the ADR
records that state.

## Phase 0 closeout verification

Verified 2026-10-18 against the local repository:

- The annotated `baseline-2026-08-29` tag exists and still targets
  `623ff64cf66ec8d85e4dbfae6162dd3811b36e58`; the tag was not moved.
- The checkout was clean before this documentation update. Later development
  commits remain descendants of the baseline and do not redefine its tag.
- The former external Siddham path remains absent. The in-repository
  `references/siddham/` material and canonical `apps/` and `demos/` trees are
  the preserved source available for this baseline. No external archive is
  claimed.

Phase 0 is closed as a **local engineering baseline**. For the source
preservation gate, a verified missing source path plus documented in-repository
classification is the recorded disposition; it does not imply an external
archive or hosted clean-clone certification. Hosted reproducibility remains a
Phase 1 evidence gate.
