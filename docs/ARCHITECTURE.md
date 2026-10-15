# Open MaxView architecture

## Clean-room boundary

Quarterdeck binaries are treated as black-box compatibility references.  No
binary payload, disassembly, decompiled routine, artwork, help text, or serial
data belongs in this repository.  Behaviour is described by public API
documentation and independently written tests.  `tools/qipinfo.py` deliberately
reads only container metadata.

## Components

`MAXVTSR.COM` owns the stable real-mode compatibility entry points.  Keeping
these in a small resident component means DESQview-aware children see the API
while `MAXVIEW.EXE` is waiting for DOS `EXEC` to return.

The 0.2 resident API tracks nested critical sections and implements the
documented `INT 10h/AH=FEh` alternate-buffer query.  In foreground-only mode
the logical buffer aliases the active B000h/B800h text buffer; `AH=FFh`
change notifications are accepted.  MAXVIEW resets per-child critical state
on both sides of DOS `EXEC`, so an unbalanced child cannot leak state into the
next launch.

`MAXVIEW.EXE` owns the menu, catalogue and foreground compatibility mode.  It
contains no memory-manager logic.  In 0.1 it launches a child through DOS and
regains control when that child exits.

`SETUP.EXE` installs the runnable files from one directory into a chosen DOS
directory.  Its workflow and screen vocabulary follow Open 386MAX's
GPL-licensed INSTALL/QUILIB code, while omitting 386MAX-specific archive,
registration and CONFIG.SYS handling.  `/S /D:path` provides a testable
unattended path, and upgrades preserve the user's program catalogue.

Its 80x25 renderer uses the Open 386MAX QUILIB colour roles and screen
geometry: block-character background, blue data pane, gray quick-help pane,
red triggers, cyan selection, shadows, double dialog borders and bottom
buttons.  The renderer stays local so future builds can run without copying or
installing the full 386MAX user-interface library.

Open 386MAX is the intended 386 VMM.  Its `9x` branch supplies EMS, XMS, VCPI,
a small QPI I/O-trapping subset, and an Open-MaxView-specific ABI query.  The
launcher validates that query and reports its root-context status.  The
current capability mask intentionally exposes no multi-context service.

## Compatibility levels

| Level | State | Meaning |
|---|---|---|
| Presence query | implemented | `INT 21h AX=2B01h CX=4445h DX=5351h` |
| Cooperative pause | implemented | `INT 15h AX=1000h` returns safely |
| Critical markers | implemented | Saturating nested depth; reset around each child |
| Alternate video buffer | implemented for foreground | B000h/B800h alias plus change notification |
| Foreground DOS EXEC | implemented | Ordinary COM/EXE/BAT programs run one at a time |
| Panels, mailboxes, objects | planned | DESQview-specific object API |
| Concurrent V86 tasks | planned | Requires Open 386MAX extension |
| Per-task video and I/O | planned | Requires page mapping and port traps |
| DVP binary compatibility | planned | Plain-text ODP catalogue is used meanwhile |

## VM-backend contract (planned)

The interface must be implemented on both sides rather than guessed through
existing QPI calls:

1. feature negotiation and ABI version;
2. create/destroy a V86 context;
3. map private conventional-memory pages and shared ROM/device regions;
4. save/restore the V86 register set, interrupt state and virtual PIC state;
5. trap video memory and selected I/O ports per context;
6. inject virtual interrupts and timer ticks;
7. account for foreground/background priority;
8. return to the Open MaxView scheduler without exposing 386MAX internals.

The extension belongs behind a new function range and must not identify as a
legacy QEMM service until its observable behaviour has conformance tests.

## Roadmap

1. Expand the resident API from the 0.2 pause/critical/video baseline with
   object handles, timers, keyboard queues and mailboxes; provide tiny
   conformance programs for every call.
2. Parse documented `.DVP` fields and translate them into an internal process
   descriptor.
3. Add cooperative multi-process loading for Open MaxView-aware programs.
4. Define and implement the Open 386MAX VM extension.
5. Add preemptive scheduling, private DOS state, video virtualisation and
   foreground switching.
6. Test real applications and document deviations from DESQview 2.8.

