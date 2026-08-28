# ADR 0001: allb.xyz is the canonical MAATAA × Siddham repository

- Status: Accepted
- Date: 2026-08-29

## Context

MAATAA runtime, Siddham Authority, hardware, demonstrations and historical
design material previously existed across separate locations. That made source
authority, build order and product claims ambiguous.

## Decision

`allb.xyz` is the canonical repository for the combined ecosystem.

- Runtime authority lives in `src/`, `data/`, `c_src/` and `hardware/`.
- Shared governed-operation authority lives in `crates/siddham-contracts/`.
- Deployable applications live in `apps/`; Edge services live in `services/`.
- Supported client surfaces live in `sdk/`, `python/` and generated bindings.
- Controlled examples live in `demos/` and cannot establish operational facts.
- Historical design and marketing source lives in `references/` and cannot
  establish implementation, availability or certification.
- Reproducible output such as `target/`, `pkg/`, `build/`, `node_modules/`,
  simulator traces and Wrangler state is never source authority.
- `vendor/nextpnr` remains a pinned upstream submodule.

The former `/Users/vesahe/Documents/GitHub/siddhamsemiconductor` path was not
present at baseline finalization. Its intended content is represented by the
classified `apps/`, `demos/` and `references/siddham/` trees; no claim is made
that an external archive was created during this phase.

## Consequences

Changes to canonical contracts, routing, ownership or truth boundaries must
update the ecosystem documentation and CI. Generated and reference content
cannot silently become canonical runtime input. Software, staging, FPGA and
physical-silicon claims remain separately gated.
