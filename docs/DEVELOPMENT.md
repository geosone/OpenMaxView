# Development guide

## Clean-room rule

Treat original DESQview binaries as black-box behavioural references. Public
API descriptions and independently written input/output tests may guide new
code. Do not commit binaries, extracted payloads, disassembly, decompiled
code, strings copied from manuals, artwork, registration data or serial
numbers. `tools/qipinfo.py` is intentionally limited to container metadata.

## Source layout

| Path | Purpose |
|---|---|
| `src/` | 16-bit DOS C programs and shared parsers. |
| `kernel/` | Resident and low-level JWasm modules. |
| `include/` | C interfaces and versioned contracts. |
| `examples/` | Small public API/backend probes. |
| `tests/` | Host tests, DOS probes and DOSBox smoke test. |
| `tools/` | Host-only clean-room inventory helpers. |
| `docs/` | User, developer and design documentation. |

DOS C remains portable C89. Keep warnings clean under the flags in
`GNUmakefile`. Assembly uses JWasm, linking uses JWlink, and DOS C uses Open
Watcom. Do not add NASM as an alternate hidden requirement.

## Design rules

* Negotiate a version and capability before invoking a backend service.
* Report missing data as unavailable; never infer a feature from an unrelated
  QPI/VCPI call.
* Keep resident code small and bound all buffers, tables and protocol inputs.
* Preserve user files through `.NEW`/`.BAK` replacement.
* Give command-line operations stable output so DOSBox can test them.
* Keep every screen in the shared Open 386MAX-inspired `mvui` vocabulary.
* Avoid a name such as `MAXMEM` that conflicts with 386MAX components.

## Change workflow

The main branch may receive unrelated work in parallel. Before committing,
fetch/pull the current remote state, integrate without discarding another
contributor's changes, run tests proportional to the change, and review the
exact diff. Never rewrite public history to solve a routine integration
problem.

For a compatibility feature, update the implementation, its probe or unit
test, the compatibility table, relevant user reference and architecture page
together. A roadmap entry is not evidence that code exists.
