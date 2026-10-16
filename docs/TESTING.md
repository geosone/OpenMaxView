# Testing

## Host tests

Run:

```sh
make test
```

The catalogue, settings, automatic-detection and DVP modules are compiled as
strict C89 with warnings as errors. Tests cover valid and invalid records,
limits, duplicate handling, atomic-save behaviour and detection. Synthetic,
freely generated DVP data tests checksum rejection, bounded field parsing and
catalogue conversion. Python unit tests exercise the read-only QIP parser.

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
  conventional/expanded-memory status and attribute-preserving physical
  `DBGPOKE` output,
  nested `BEGINC`/`ENTERC` sections, `GETCRIT`, foreground `LOCATE`/`GETBUF`,
  `PROCESSMEM`, the `HANDLE` message stack ABI with valid/foreign/unavailable
  selectors, four-slot timer `NEW`/`FREE` exhaustion, identity, type,
  enumeration, reuse, stack popping, open/close, relative/absolute countdown and
  elapsed/remaining/state queries, foreground `PUSHKEY`,
  a two-slot mailbox lifecycle with exhaustion, type/identity checks,
  enumeration, four-entry by-value queues, count/length/status, full-queue
  failure, FIFO `READINTO` data/status delivery, empty-read failure, erase,
  close-time discard/preservation, closed-write flags, reuse and reset
  reclamation, and
  alternate video buffer, plus `SCRNINFO` and non-DV/X identity;
* absent and stubbed Open 386MAX backend reporting, including QPI version and
  active page-table frame, empty-token rejection, root-release and second-clone
  guards, verified clone/root switching, four-page private-pool exhaustion,
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

## Before a release

Run all four checks from a clean tree:

```sh
make clean
make package
make test
make test-dos
```

Also run `git diff --check`, inspect `build/OpenMaxView/`, install that exact
directory into a fresh DOSBox machine and exercise the full-screen tools with
a keyboard. The automated suite is strong on stable behaviour but does not
replace visual inspection of an 80x25 interface.

## Adding compatibility work

Every newly implemented DESQview call needs a small independent DOS probe, a
documented expected result and a negative/unsupported case. Backend additions
need tests for capability negotiation before tests for the capability itself;
an older Open 386MAX must fail closed rather than be misidentified.
