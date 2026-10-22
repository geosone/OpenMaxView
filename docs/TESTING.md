# Testing

## Host tests

Run:

```sh
make test
```

The catalogue, settings, automatic-detection, DVP and scheduler-policy modules
are compiled as strict C89 with warnings as errors. Tests cover valid and
invalid records, limits, duplicate handling, atomic-save behaviour and
detection. Scheduler tests cover table exhaustion, deterministic round-robin
selection, wait/wake transitions, nested critical exclusion, teardown, slot
reuse, stale-handle rejection, V86 register images and QPI-token attachment.
The injected VM-backend test covers current-task-only activation, failed-root
retention, mandatory Windows root verification, failed-release retention and
ordered detach/release. Synthetic, freely generated DVP data tests
checksum rejection, bounded field parsing and catalogue conversion. Process
descriptor tests cover profile classification, scheduler binding, partial
enforcement, unknown feature rejection and teardown reset. Python unit tests
exercise the read-only QIP parser.

## DOS integration tests

Run:

```sh
make test-dos
```

The target builds the full suite and executes headless DOSBox sessions. It
checks:

* first and repeated installation of `MAXVTSR` and `MAXVANSI`;
* API version, pause, `APPNUM`, keyboard-mouse mode, `APILEVEL`, `JUSTIFY`,
  `CSTYLE`, error policy,
  all three bounded system-memory allocation entry points,
  conventional/expanded-memory status and attribute-preserving physical
  `DBGPOKE` output,
  nested `BEGINC`/`ENTERC` sections, `GETCRIT`, foreground `LOCATE`/`GETBUF`,
  `PROCESSMEM`, the `HANDLE` message stack ABI with valid/foreign/unavailable
  selectors, four-slot timer `NEW`/`FREE` exhaustion, identity, type,
  enumeration, reuse, stack popping, open/close, relative/absolute countdown and
  elapsed/remaining/state queries, foreground `PUSHKEY`,
  a two-slot mailbox lifecycle with exhaustion, type/identity checks,
  enumeration, `WRITE` status-zero delivery, copied `ADDTO` and referenced
  `SUBFROM` records, four-entry queues,
  count/length/status, full-queue
  failure, FIFO pointer-return `READ` and `READINTO` data/status delivery,
  last-read `ADDR` sender identity, failed-read retention and lifecycle reset,
  empty-read failure, erase,
  close-time discard/preservation, closed-write flags, bounded
  `SETNAME`/`GETNAME` and `FINDMAIL`, reuse and reset
  reclamation, and
  alternate video buffer, plus `SCRNINFO` and non-DV/X identity;
* foreground window `AT` with explicit/default selectors, plus `PRINTC`
  character/attribute output, cursor advancement and `BX=0` synchronization;
* all 16 second-level callback allocations, exhaustion, masked dispatch,
  foreground-task `ES`, release/reuse and reset cleanup;
* PC-speaker `SOUND` normalization, queued silence, current/all cancellation,
  32-entry saturation and task-reset cleanup;
* `OSTACK`/`USTACK` segment switching, resident-stack data use, nested API
  entry, exact user `SS:SP` restoration and stack reuse;
* absent and stubbed Open 386MAX backend reporting, including QPI version and
  active page-table frame, empty-token rejection, root-release and second-clone
  guards, master-IRQ table validation, duplicate install rejection, synchronous
  IRQ0 injection, invalid-vector rejection and ordered removal, verified
  clone/root switching, four-page private-pool exhaustion,
  a four-entry verified map/restore cycle in an exclusively reserved DOS test
  area, refusal to restore root with a partially committed table, committed
  table persistence across a root/clone switch, out-of-order release refusal
  and final ordered release;
* installer completeness and preservation of all three user files;
* catalogue, settings and automatic-detection command modes;
* duplicate-free automatic application;
* file list, copy, overwrite, self-copy guard and guarded deletion;
* ANSI cursor, character and colour behaviour;
* DVP validation, field listing, catalogue import and imported-catalogue check.

Temporary DOS trees are created below `build/`. The test does not touch a
real DOS installation or proprietary reference media.

## Multitasking tests on Open 386MAX

`tests/qemu/mvtest.sh` boots MS-DOS 6.22 with Open 386MAX in QEMU through
Open386MAX's `linux/test/dosboot.sh` (`MAXROOT`, default `../Open386MAX`,
needs its `build/bin` and `build/TESTS`). The cases follow Open386MAX's
DESQview test:

| Case | Checks |
|---|---|
| `two` | two TICK tasks count side by side, COM1 output of one |
| `mem` | each task its own conventional memory (same PSP, patterns kept) and text pages 1-7 |
| `serial` | a background task receives COM1 by IRQ4 and echoes 3000 bytes |
| `keys` | screen and keys only for the foreground; Ctrl+Alt+n; waiting tasks yield |
| `kill` | killed tasks end through DOS, a new one starts in a freed slot |
| `crit` | a background critical error comes to the front |
| `desk` | MAXVIEW.EXE starts programs as tasks, Alt, task list, exit |
| `win` | MAXVIEW windows: two tasks on one screen, typing, move, zoom, close |
| `dvapi` | DESQview PAUSE, BEGINC/ENDC, APPNUM per task (with MAXVTSR) |
| `cwd` | current directory per task (CDS), MVRUN's unchanged |
| `ems` | EMS page frame mapping per task, with 47h/48h save/restore |
| `gfx` | VGA mode 13h task and text task:  each one's mode on switching, graphics held in the background, drawn again |
| `progs` | Open386MAX's regression tests (XMS, EMS, VCPI, VDS, DPMI, ...) each in a task, compared with plain DOS |

`MVDEBUG=1` assembles the core with trace characters on port E9h; the
script stores them as `build/test-qemu/<case>.e9`.

## Before a release

Run the complete build and test sequence from a clean tree:

```sh
make clean
make package
make test
make test-dos
make setup-package
```

Also run `git diff --check`, inspect `build/OpenMaxView/`, install that exact
directory into a fresh DOSBox machine and exercise the full-screen tools with
a keyboard. The automated suite is strong on stable behaviour but does not
replace visual inspection of an 80x25 interface.

For a release candidate, `make release-check` performs the clean automated
sequence and writes the DOS ZIP, HTML, PDF, EPUB and `SHA256SUMS.txt` below
`build/releases/<version>/`. Verify the checksums, install from the extracted
DOS ZIP, and retain the exact tested artifacts for the GitHub release.

## Adding compatibility work

Every newly implemented DESQview call needs a small independent DOS probe, a
documented expected result and a negative/unsupported case. Backend additions
need tests for capability negotiation before tests for the capability itself;
an older Open 386MAX must fail closed rather than be misidentified.
