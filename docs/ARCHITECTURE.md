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

The 0.17 resident API tracks foreground task compatibility state and nested
critical sections, and implements the documented `INT 10h/AH=FEh`
alternate-buffer query. In foreground-only mode
the logical buffer aliases the active B000h/B800h text buffer; `AH=FFh`
change notifications are accepted.  MAXVIEW resets per-child critical state
on both sides of DOS `EXEC`, so an unbalanced child cannot leak state into the
next launch. It implements `APPNUM`, `APILEVEL`, `JUSTIFY`, `CSTYLE` and
`GETCRIT`, `ENTERC` and the error-return policy; mode changes are retained even though their visible windowing
effects need the future virtual console. The documented `PUSHKEY` call adds a
BIOS-format scan/character pair to the foreground keyboard buffer. `PUTKEY`
does the same only for the exact resident task handle and returns a full-buffer
or invalid-handle status; task-private queues remain a 1.x multi-context
requirement.

Keyboard-mouse control currently records the documented disabled/enabled
foreground-task mode and resets it at the child boundary. It does not claim
mouse-event synthesis before the task-private input backend exists.

Before installation, the resident captures the directory component of its
DOS executable path. `GETDVPATH` can therefore answer from resident storage
without invoking DOS from an interrupt handler.

The resident also owns a deliberately bounded allocation foundation: eight
256-byte task slots and four 256-byte common slots. Task slots are reclaimed
at the foreground-task reset boundary; common slots remain global until their
owner releases them. This supplies genuine backing memory for the documented
`GETMEM`, `PUTMEM`, `GETCOMMON` and `PUTCOMMON` calls without pretending that
the variable-sized multi-task allocator already exists.

`PROCESSMEM` combines the current foreground DOS process allocation with this
bounded task-system pool. It validates the real task handle, reads the owning
MCB in normal process context, and reports slot use and the largest available
slot without claiming swap or shared-memory state.

The related `DE05h` and `DE06h` services expose conventional and EMS capacity
in the documented KB units. Conventional free space comes from a guarded DOS
MCB walk; EMS values come from the standard page-count query and do not depend
on private Open 386MAX internals.

The `DE0Ah` debug service writes a character directly to the bottom physical
text row while preserving its attribute. Its resident cursor follows the BIOS
geometry and the handler becomes a no-op outside known text modes.

The sole foreground task is represented by a paragraph-aligned resident
object header. Its public handle is a genuine `segment:0000` pointer, so
`GETFOREGROUND`, `DOSUSER`, `ISOBJ`, `OBJNEXT`, `WININFO` and the object-type
query share one identity. This exposes honest one-item enumeration and task
metadata while continuing to label the window foreground-only. Dynamic
objects are not exposed until the message-call stack ABI is implemented and
tested.

The same foreground object now backs `LOCATE` and `GETBUF`: coordinates in the
physical text screen resolve to the one full-screen window, and its virtual
buffer aliases the active physical B000h/B800h page. This is deliberately a
single-window contract until private video pages exist.

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
launch fields into the open catalogue and retains scheduler, video, EMS,
serial, protection and raw flag values in a versioned process profile. The
profile is durable but not treated as enforced until the corresponding
backend capability exists.

The shared 80x25 renderer uses the Open 386MAX QUILIB colour roles and screen
geometry: block-character background, blue data pane, gray quick-help pane,
red triggers, cyan selection, shadows, double dialog borders and bottom
buttons.  The renderer stays local so future builds can run without copying or
installing the full 386MAX user-interface library.

New tools share the small `mvui` renderer so menu bars, blue data panes, gray
quick-help panes, cyan dialogs, red hotkeys, shadows and bottom buttons remain
consistent across the suite.

Open 386MAX is the intended 386 VMM.  Its `9x` branch supplies EMS, XMS, VCPI,
the QEMM programming interface (QPI) as QEMM 97 behaves (mapping contexts,
port trapping, IRQ calldowns, timer and video virtualization; every group is
checked against QEMM 97 by a conformance test, see Open 386MAX `docs/qpi.md`)
and an Open-MaxView-specific ABI query.  The launcher validates that query and
reports its root-context status.  The current capability mask of the
Open-MaxView ABI intentionally exposes no multi-context service; the QPI
functions below are the documented way to build one.

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
| Foreground task metadata | implemented | `APPNUM`, `APILEVEL`, modes and error policy |
| Critical-state queries | implemented | `BEGINC`, `ENDC`, `ENTERC`, `GETCRIT` |
| Alternate video buffer | implemented for foreground | B000h/B800h alias plus change notification |
| Physical video queries | implemented for foreground | `SCRNINFO`, `VIDEONOTIFY`, non-DV/X identity |
| Keyboard injection | implemented for foreground | Global `PUSHKEY` and handle-validated `PUTKEY` use the BIOS queue |
| Keyboard-mouse mode | foreground state implemented | Query/enable/disable state; event synthesis awaits task-private input |
| System/common memory | bounded foreground implementation | Resident 256-byte slots with allocation, release and status |
| Process memory status | foreground implementation | Current DOS allocation plus bounded task-system slot accounting |
| DOS/EMS capacity status | foreground implementation | Guarded MCB accounting and standard EMS page counts |
| Physical debug status | implemented | Attribute-preserving `DBGPOKE` on the bottom text row |
| Foreground task object | implemented | Pointer-compatible handle, validation and type query |
| Task enumeration and metadata | foreground implementation | `DOSUSER`, one-item `OBJNEXT`, version-1.00 `WININFO` |
| Window location and buffer | foreground implementation | Full-screen `LOCATE`; `GETBUF` aliases the active text page |
| Foreground DOS EXEC | implemented | Ordinary COM/EXE/BAT programs run one at a time |
| Panels, mailboxes, objects | planned | DESQview-specific object API |
| Concurrent V86 tasks | planned | Backend primitives available through QPI (contexts, IRQ calldowns); scheduler pending |
| Per-task video and I/O | planned | Page mapping and port/CRTC traps available through QPI; use pending |
| `.DVP` import | versioned profile implemented | Advanced VM/scheduler fields retained but not yet enforced |

## VM-backend contract

The interface must be implemented on both sides rather than guessed:

1. feature negotiation and ABI version;
2. create/destroy a V86 context;
3. map private conventional-memory pages and shared ROM/device regions;
4. save/restore the V86 register set, interrupt state and virtual PIC state;
5. trap video memory and selected I/O ports per context;
6. inject virtual interrupts and timer ticks;
7. account for foreground/background priority;
8. return to the Open MaxView scheduler without exposing 386MAX internals.

### Available today through QPI

Open 386MAX answers QEMM's detection (`INT 2Fh AX=D200h/D201h`) and offers
the QPI functions DESQview uses on QEMM.  DESQview 2.80 itself detects QEMM
on Open 386MAX and makes exactly the QPI calls it makes on QEMM 97.  Points
of the contract covered by documented, conformance-tested QPI functions:

| Contract point | QPI functions |
|---|---|
| 2. create/destroy a V86 context | `04h` allocate a page, `06h` clone the active 0-4 MB page table into it, `05h` free it |
| 3. map private and shared pages | `0Ah` set a PTE, `1F00h`/`1F01h` raw PTEs (MMIO with PCD/PWT), `0Bh` map an EMS handle, `0Fh` restore defaults (dirty flag) |
| switch the context | `07h` get, `08h` set the active page table |
| 5. trap video and I/O ports | `1A06h`-`1A0Ah` port traps with a V86 callback, `1A00h`-`1A05h` I/O past the traps, `0Dh`/`0Eh` CRTC/DAC trapping with cursor callbacks, `1301h` dirty video pages, `1308h` all video ports, `130Ah` DAC buffer |
| 6. virtual interrupts and timer ticks | `1C01h`/`1C03h` IRQ calldowns (IRQ0 for the scheduler), `1C04h` inject an interrupt, `15h` record a task's PIT divisor |

Points 1, 4, 7 and 8 stay with Open MaxView (the scheduler runs in V86, as
DESQview's does on QEMM: it saves and restores a task's registers itself)
or need the Open-MaxView ABI.  Not available: the graphics virtualization
of `13h` (`1302h`-`1310h`) and enforced protection levels (`14h` is
accepted but does not write-protect); the EMS mapping state is kept once,
not per context, so EMS memory is mapped into a task with `0Bh`.

### Windows startup invariant

When MaxView private-address-space mode `08h` is active, the scheduler must
restore the Open 386MAX standard/root context before launching Windows. The
386MAX Windows support records the page table for the first 4 MiB during
Windows startup; allowing it to start in a private MaxView context would make
the wrong mapping its baseline. The launcher must verify the context switch
and fail the Windows launch if the standard context cannot be established.
Open 386MAX enforces the invariant as well: its `INT 2Fh AX=1605h` handler
refuses the Windows start (`CX` non-zero) while a QPI context other than the
root one is active.
This transition requires a backend conformance test before multi-context
Windows support can be declared compatible.

Services beyond QPI belong behind the Open-MaxView function range (`4Dxxh`).
Open 386MAX identifies as QEMM only for the functions whose observable
behaviour has conformance tests against QEMM 97.

## Roadmap

The detailed release criteria are maintained in [`ROADMAP.md`](ROADMAP.md).
Remote viewing is deliberately deferred to the 2.x design note and is not part
of the current backend contract.

1. Expand the resident API from the foreground task-state baseline with
   object handles, timers, keyboard queues and mailboxes; provide tiny
   conformance programs for every call.
2. Carry the implemented `.DVP` parser's advanced fields into an internal
   process descriptor as scheduler and VM capabilities become available.
3. Add cooperative multi-process loading for Open MaxView-aware programs.
4. Define and implement the Open 386MAX VM extension.
5. Add preemptive scheduling, private DOS state, video virtualisation and
   foreground switching.
6. Test real applications and document deviations from DESQview 2.8.

