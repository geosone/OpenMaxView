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

The 0.3 resident API tracks nested critical sections and implements the
documented `INT 10h/AH=FEh` alternate-buffer query.  In foreground-only mode
the logical buffer aliases the active B000h/B800h text buffer; `AH=FFh`
change notifications are accepted.  MAXVIEW resets per-child critical state
on both sides of DOS `EXEC`, so an unbalanced child cannot leak state into the
next launch. The documented `PUSHKEY` call adds a BIOS-format scan/character
pair to the foreground keyboard buffer; task-private queues remain a 1.x
multi-context requirement.

`MAXVIEW.EXE` owns the menu, catalogue and foreground compatibility mode.  It
contains no memory-manager logic.  In 0.8 it launches a child through DOS and
regains control when that child exits.

`SETUP.EXE` installs the runnable files from one directory into a chosen DOS
directory.  Its workflow and screen vocabulary follow Open 386MAX's
GPL-licensed INSTALL/QUILIB code, while omitting 386MAX-specific archive,
registration and CONFIG.SYS handling.  `/S /D:path` provides a testable
unattended path, and upgrades preserve the user's catalogue and global
preferences.

`MAXVAPP.EXE` owns interactive program-catalogue maintenance.  It provides the
independently implemented equivalent of the essential Add/Change/Delete
Program utilities and writes updates through `.NEW` while retaining `.BAK`.
`MAXVMEM.EXE` is a read-only status client for DOS, EMS, XMS, the resident API,
VCPI and the versioned Open 386MAX backend interface.  It reports unavailable
data explicitly instead of deriving unsupported VM state from legacy APIs.

`MAXVSET.EXE` maintains the separate `MAXVSET.INI` global preference file.
Every exposed setting has a current launcher consumer: resident-API and ANSI
autoload, exit confirmation, post-child catalogue reload, memory-column
visibility, hotkey launching and Quick Help visibility.  VM scheduling,
swapping, private memory, video/I/O and interrupt options remain absent while
backend ABI 1.0 exposes only its read-only status capability.

`MAXVAUTO.EXE` provides clean-room automatic program setup.  Its declarative
`MAXVAUTO.DAT` database maps DOS 8.3 filenames to catalogue records.  The
scanner checks the current directory and `PATH`, with explicitly requested
recursive roots, but never opens or executes a detected third-party binary.
It filters existing catalogue commands, allocates an unused hotkey, and uses
the catalogue module's atomic save path.  The database remains separate and
is preserved by upgrades so users and distributors can add local rules.

`MAXVFILE.EXE` provides the subset of DOS Services which is meaningful in the
current foreground execution model: directory browsing, binary file copy,
rename, directory creation and guarded deletion.  It uses DOS file APIs only
and has no dependency on unavailable V86 context services.  Scriptable list,
copy and delete modes make its file operations testable inside DOSBox.

`MAXVANSI.COM` is a small JWasm/JWlink resident foreground console.  It owns a
versioned private `INT 2Fh` presence query and parses common ANSI sequences on
the DOS fast-console `INT 29h` path.  Character rendering and attributes go
through BIOS video services.  It intentionally makes no claim of per-task
ANSI state: direct video writes and future concurrent contexts belong to the
Open 386MAX video-virtualisation boundary.

`MAXVDVP.EXE` and the host-testable `dvp` module parse the documented binary
TopView/DESQview program-information layout without using Quarterdeck code.
The parser validates the base checksum and bounded ASCIZ fields. Import maps
only fields represented by the open catalogue; it exposes advanced DVP values
for diagnostics rather than pretending that foreground mode enforces them.

The shared 80x25 renderer uses the Open 386MAX QUILIB colour roles and screen
geometry: block-character background, blue data pane, gray quick-help pane,
red triggers, cyan selection, shadows, double dialog borders and bottom
buttons.  The renderer stays local so future builds can run without copying or
installing the full 386MAX user-interface library.

New tools share the small `mvui` renderer so menu bars, blue data panes, gray
quick-help panes, cyan dialogs, red hotkeys, shadows and bottom buttons remain
consistent across the suite.

Open 386MAX is the intended 386 VMM.  Its `9x` branch supplies EMS, XMS, VCPI,
a small QPI I/O-trapping subset, and an Open-MaxView-specific ABI query.  The
launcher validates that query and reports its root-context status.  The
current capability mask intentionally exposes no multi-context service.

Open 386MAX remains the memory manager/VM foundation. Even for the optional
2.x Remote View design, NDIS, ODI, Packet Driver, TCP, TLS and application
protocol code belongs exclusively to Open MaxView. No network stack or
network-specific ABI is to be added to Open 386MAX.

## Compatibility levels

| Level | State | Meaning |
|---|---|---|
| Presence query | implemented | `INT 21h AX=2B01h CX=4445h DX=5351h` |
| Cooperative pause | implemented | `INT 15h AX=1000h` returns safely |
| Critical markers | implemented | Saturating nested depth; reset around each child |
| Alternate video buffer | implemented for foreground | B000h/B800h alias plus change notification |
| Keyboard `PUSHKEY` | implemented for foreground | BIOS buffer injection; no per-task queue yet |
| Foreground DOS EXEC | implemented | Ordinary COM/EXE/BAT programs run one at a time |
| Panels, mailboxes, objects | planned | DESQview-specific object API |
| Concurrent V86 tasks | planned | Requires Open 386MAX extension |
| Per-task video and I/O | planned | Requires page mapping and port traps |
| `.DVP` import | basic fields implemented | Advanced VM/scheduler fields decoded but not enforced |

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

The detailed release criteria are maintained in [`ROADMAP.md`](ROADMAP.md).
Remote viewing is deliberately deferred to the 2.x design note and is not part
of the current backend contract.

1. Expand the resident API from the 0.2 pause/critical/video baseline with
   object handles, timers, keyboard queues and mailboxes; provide tiny
   conformance programs for every call.
2. Carry the implemented `.DVP` parser's advanced fields into an internal
   process descriptor as scheduler and VM capabilities become available.
3. Add cooperative multi-process loading for Open MaxView-aware programs.
4. Define and implement the Open 386MAX VM extension.
5. Add preemptive scheduling, private DOS state, video virtualisation and
   foreground switching.
6. Test real applications and document deviations from DESQview 2.8.

