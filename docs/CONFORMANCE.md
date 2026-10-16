# Clean-room conformance matrix

This chapter is the implementation inventory for the DESQview 2.80-compatible
1.x goal. It records observable contracts rather than original implementation
details. A checked API row requires independently written tests; detecting a
version number alone is not evidence of compatibility.

## Reference method

Original media may be installed only in an isolated DOS guest and used as a
black box. Probes supply documented inputs and record public register, stack,
screen, timing and file-system results. The same probe is then run against
Open MaxView and its normalized output is compared. Reference executables,
help files, registration data and captured screens are not copied into the
repository.

Ghidra, a debugger or a monitor may be used on Open MaxView itself. They must
not be used to derive code, data structures, strings or control flow from the
proprietary reference. Disassembly and decompilation are outside this
project's clean-room evidence model and cannot close a conformance row.

Reference runs should identify the observed product and version in private
lab notes. DESQview 2.80 is the primary public-API oracle. Older DESQview/386
releases are useful only for version-qualified scheduler, communications and
386 behavior; an older result must not silently override a 2.80 contract.

## Direct TopView-compatible services

| Family | Current state | Missing acceptance evidence |
|---|---|---|
| Presence, `PAUSE`, `GETVER` | Implemented | Multi-task scheduling effect of `PAUSE` |
| `GETMEM`/`PUTMEM` | Bounded foreground implementation | Variable sizes, per-task ownership and exhaustion behavior |
| `PRINTC` | Missing | Character/attribute rendering and clipping |
| `GETBIT`/`FREEBIT`/`SETBIT` | Missing | Second-level interrupt allocation, dispatch and release |
| `ISOBJ`, `LOCATE`, `GETBUF` | Foreground implementation | Multiple overlapping windows and private video buffers |
| `SOUND` | Missing | Ownership, duration and background scheduling |
| `OSTACK`/`USTACK` | Missing | Nested internal-stack switching and interrupt interaction |
| `BEGINC`/`ENDC` | State implemented | Scheduler exclusion across real task switches |
| `STOP`/`START`, `POSTTASK` | Missing | Runnable/waiting transitions and wakeups |
| `DISPEROR` | Missing | Error-window result and task interaction |
| `PGMINT` | Missing | Cross-task interrupt delivery and saved registers |
| `POSWIN` | Missing | Move/resize, clipping, redraw and focus behavior |
| `NEWPROC` | Missing | Child process/task creation and failure cleanup |
| `KMOUSE` | State implemented | Per-task event synthesis |
| extended `102Eh` allocation | Missing | Version-qualified allocation semantics |

## Object messages (`INT 15h/AH=12h`)

| Message | Current state | Remaining work |
|---|---|---|
| `HANDLE` | Explicit task/timer/mailbox handles | Task-default mailbox, keyboard and OBJECTQ selectors |
| `NEW`/`FREE` | Bounded timer and mailbox pools | Window, keyboard, pointer, panel and OBJECTQ classes |
| `ADDR` / window `CONNECT` | Missing | Sender identity and attached-window behavior |
| `READ` | Missing | Pointer-return buffers and scheduler-backed empty waits |
| `WRITE` | Absolute timers and status-zero mailbox records | Window streams and other writable object classes |
| `SETPRI`/`GETPRI` | Missing | OBJECTQ ordering |
| `SIZEOF`/`LEN` | Timer and mailbox subset | Window, keyboard, pointer, panel and OBJECTQ meanings |
| `ADDTO` | Timers and by-value mailbox records | Window data/attribute writes and other object classes |
| `SUBFROM` | Missing | By-reference mailbox records, object flags and OBJECTQ removal |
| `OPEN`/`CLOSE` | Timer and mailbox subset | Window, keyboard, pointer, panel and OBJECTQ behavior |
| `ERASE` | Timer and mailbox subset | Windows, input queues, pointers and OBJECTQs |
| `STATUS` | Timer/mailbox subset | Keyboard, pointer, panel and OBJECTQ status contracts |
| `EOF` | Missing | Window and mailbox results |
| `SETNAME`/`GETNAME` | Bounded explicit-handle implementation | Task-default selectors and names over 32 bytes |
| `READN` | Missing | Bounded window/object reads |
| `READINTO` | Ready mailbox records | True blocking/wakeup behavior when empty |
| `REDRAW` | Missing | Damage tracking and repaint ordering |
| `LOCK`/`SETESC` | Missing | Ownership, contention and callback rules |
| `SETFLAGS`/`GETFLAGS` | Mailbox bits 0-2 | DV/X stream, EMS and non-owned modes; keyboard/pointer flags |
| error-recovery messages `80h`-`96h` | Missing | Stack recovery and error-policy interaction |
| panel `DIR`/`APPLY` | Missing | Panel files, fields, returned window/keyboard handles |

## DESQview-specific services

The implemented `DEh` group covers memory status, foreground identity,
task-state modes, keyboard injection, screen information, process memory,
installation path, named-mailbox lookup, object traversal and versioned window
information. The next public-API probes must cover second-level interrupt
services, task/process creation and control, additional window metadata,
mouse/pointer delivery and version-qualified error behavior. DESQview/X socket
and X-server calls are not part of the local 1.x completion gate.

## System behavior needed for 1.x

| Subsystem | Required result |
|---|---|
| Scheduler | Multiple runnable/waiting V86 tasks, preemption, fair `PAUSE`, critical-region exclusion and deterministic teardown |
| Address spaces | Private conventional memory with verified Open 386MAX root/clone transitions and no cross-task leakage |
| Windows launch | Restore and verify the standard/root context before launch; abort if restoration fails |
| DOS state | Per-task PSP/DTA/current-directory/file context and serialized non-reentrant DOS entry |
| Video | Per-task text buffers, overlapping window composition, clipping, cursor state, direct-video detection and redraw |
| Input | Focused per-task keyboard queues, pointer events and keyboard-mouse mode |
| Serial/BBS | UART ownership, virtual IRQ delivery, buffered COM traffic and sustained multi-node transfer tests |
| Program profiles | Enforce imported memory, swap, graphics, virtualization, serial and scheduling fields |
| Manager UI | Open/switch/rearrange/close tasks, help, mark-and-transfer and failure recovery in the shared Open 386MAX design language |

## Probe rules

1. Prefer a minimal Open Watcom/JWasm probe that reports stable `KEY=VALUE`
   lines and restores any state it changes.
2. Never call a documented blocking service without first arranging its wakeup
   event; a hung guest is not a useful observation.
3. Record stack deltas, Carry, returned object types and buffer lifetime where
   the ABI uses the caller stack.
4. Run boundary values: zero, one, maximum, maximum plus one, stale handles,
   closed objects, pool exhaustion and repeated cleanup.
5. Treat timing as ranges and event ordering, not exact host milliseconds.
6. Add the Open MaxView regression before marking a matrix row implemented.

## Public references

The register-level baseline is Ralf Brown's Interrupt List and the public
DOS Interrupts compilation. Freely available examples may clarify call
construction, but their code is not imported. Useful indexes include:

* <https://fd.lod.bz/rbil/interrup/quarterdeck/index.html>
* <https://ic.unicamp.br/~ducatte/mc404/Lampiao/docs/dosints.pdf>
* <https://github.com/fone32/desqview-examples>
* <https://www.ittnnet.com/downloads/DESQVIEW/desqview.html>

