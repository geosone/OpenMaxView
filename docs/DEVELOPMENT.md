# Development guide

## Clean-room rule

Treat original DESQview binaries as black-box behavioural references. Public
API descriptions and independently written input/output tests may guide new
code. Do not commit binaries, extracted payloads, disassembly, decompiled
code, strings copied from manuals, artwork, registration data or serial
numbers. `tools/qipinfo.py` is intentionally limited to container metadata.

## Public compatibility references

The following public material is useful for independent ABI and behaviour
cross-checks:

* [DOS Interrupts](https://ic.unicamp.br/~ducatte/mc404/Lampiao/docs/dosints.pdf)
  records register-level TopView and DESQview calls;
* [fone32/desqview-examples](https://github.com/fone32/desqview-examples)
  independently demonstrates presence detection, `PAUSE`, `BEGINC` and
  `ENDC` from FASM;
* the [ITTN DESQview archive index](https://www.ittnnet.com/downloads/DESQVIEW/desqview.html)
  helps identify public packages and examples for black-box testing.

These links are conformance references, not source dependencies. Do not copy
their code, binaries, prose or assets into Open MaxView without a separately
verified compatible licence. In particular, the fone32 include port describes
itself as incomplete and targets FASM; the Open MaxView toolchain remains Open
Watcom, JWasm and JWlink.

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
* Keep scheduler policy independent of QPI mechanics. A task becomes a real
  concurrent DOS task only after register state, DOS state and its verified
  private context are all owned by the same lifecycle.
* Use the injectable `mv_vm_backend_ops` boundary for VM lifecycle policy.
  DOS binds it to `maxbackend.asm`; host tests use deterministic fakes and
  exercise every fail-closed transition.
* Enable an `mv_process_descriptor` feature class only after its backing
  resource is acquired and verified. Parsed DVP data is a request, not proof
  of enforcement; raw flag bits remain grouped until independently specified.
* Before starting Windows from private-address-space mode `08h`, restore and
  verify the Open 386MAX standard/root context. Windows snapshots the page
  table for the first 4 MiB at startup, so this transition must fail closed.
  `odq_max_context_restore` provides the verified backend operation; a caller
  must abort the launch if it returns false.
* Treat QPI page-table frames as 32-bit physical page numbers. Release only
  frames allocated and owned by the same lifecycle layer, and never release
  the active or root context.
* Treat QPI `09h`/`0Ah` mapped-page frames as the interface's 16-bit values.
  Map only private pages allocated and owned by the same wrapper, inside the
  owned active clone. Keep linear-page numbers unique and save and verify every
  original frame. Never leave that clone until all replacements are committed;
  then switch only to the verified root and reactivate the clone before
  restoring its table. Do not map over caller records, backend code/data or
  the active stack.
* Assembly functions called by Open Watcom C must preserve every register not
  consumed by their declared parameters or return value. In particular, do
  not leak QPI's `CX`/`DX` working values into optimized C callers.

## Change workflow

The main branch may receive unrelated work in parallel. Before committing,
fetch/pull the current remote state, integrate without discarding another
contributor's changes, run tests proportional to the change, and review the
exact diff. Never rewrite public history to solve a routine integration
problem.

For a compatibility feature, update the implementation, its probe or unit
test, the compatibility table, relevant user reference and architecture page
together. A roadmap entry is not evidence that code exists.
