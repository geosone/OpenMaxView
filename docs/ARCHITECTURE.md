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

The 0.36 resident API tracks foreground task compatibility state and nested
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
256-byte task slots per task and eight global 256-byte common slots. The task
slots are part of the per-task state block (`D707h`) the multitasking core
swaps, as DESQview's system memory lives in the window's memory: every task
has its own eight, and they go with the task (and at the foreground-task
reset); common slots remain global until their owner releases them, also
after the task ended, as under DESQview. This supplies genuine backing memory for the documented
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
object header. Four equally stable timer headers form the first dynamic-object
pool. Their public handles are genuine `segment:0000` pointers, so
`GETFOREGROUND`, `DOSUSER`, `ISOBJ`, `OBJNEXT`, `WININFO` and the object-type
query share resident identities. Enumeration starts with the task and then
visits each live timer in stable slot order while continuing to label the
window foreground-only. The `AH=12h/BH=00h` `HANDLE` message implements the
caller-stack ABI for that window and live timers, including identity
validation and null results for object classes not yet present. `NEW` and
`FREE` provide bounded timer ownership, exhaustion and deterministic slot
reuse. `ADDTO` and `WRITE` drive relative and absolute countdowns from the BIOS
tick counter; `OPEN`/`CLOSE`, `SIZEOF`, `LEN` and `STATUS` expose nonblocking
control and state without calling DOS inside the resident handler. Blocking
waits remain deferred.

Two additional paragraph-aligned headers form a bounded mailbox pool. They
participate in validation, type queries and object enumeration. Each owns a
four-entry FIFO with records of up to 128 bytes. `ADDTO` enqueues a copied
value with a caller status; `WRITE` uses the shorter status-zero form, while
`SUBFROM` retains a caller-owned far pointer until consumption.
`SIZEOF` and `LEN` report queued records and bytes, and `ERASE` or
`CLOSE` discards the queue. `READ` returns a resident record pointer while
expanding the caller stack; `READINTO` consumes a ready record into caller
storage. Every queued record retains its producer task identity, and `ADDR`
returns the sender of the last record consumed by either read form. An empty
queue returns Carry instead of blocking. Scheduler-backed
waits and wakeups remain outside this layer. The three non-DV/X mailbox flag
bits are retained: common-memory placement is advisory for the fixed resident
pool, while closed writes and close-time queue preservation are enforced.
Each live mailbox also owns a copied name of up to 32 bytes. `SETNAME`,
`GETNAME` and `FINDMAIL` share that resident table; names contain explicit
lengths and are never treated as NUL-terminated strings.

The same foreground object now backs `LOCATE` and `GETBUF`: coordinates in the
physical text screen resolve to the one full-screen window, and its virtual
buffer aliases the active physical B000h/B800h page. This is deliberately a
single-window contract until private video pages exist.
TopView `PRINTC` writes through BIOS text services at that foreground cursor,
including geometry-aware wrap and full-screen scroll; foreign windows remain
available to an earlier provider in the interrupt chain. The overloaded
window `AT`/mailbox `SETNAME` message is resolved from its selector and live
handle before `AT` maps valid foreground coordinates to the BIOS cursor.
The foreground task also owns a bounded table of sixteen TopView second-level
callbacks. `SETBIT` drains requested live callbacks synchronously and defers
nested requests to the outer drain loop. Moving that drain to the hardware-IRQ
return path is intentionally coupled to the future scheduler.
A resident `INT 1Ch` hook advances the bounded 32-entry TopView `SOUND` queue
without DOS calls. It programs PIT channel 2 only when the active entry changes
and always silences the PC speaker when the queue is cancelled or exhausted.
The foreground task also owns a bounded 512-byte API stack. `OSTACK` rebuilds
the interrupt return frame on that resident stack, while `USTACK` rebuilds it
on the saved user stack so execution resumes with the original `SS:SP`.
Nested switches are excluded by the public contract and guarded as no-ops.

`MAXVIEW.EXE` owns the menu, catalogue and foreground compatibility mode. It
contains no memory-manager logic. A bounded 16-slot scheduler policy module
now gives the desktop and every launched child a generation-tagged handle,
tracks ready/running/waiting states, selects tasks in deterministic round-robin
order and pins the running task across nested critical regions. The current
launcher uses that lifecycle around DOS `EXEC`, then tears down the child and
returns the desktop to running state. Execution remains foreground-only: the
policy module retains a complete 32-bit V86 register image, virtual-PIC mask,
pending-interrupt word and one owned page-table token for every slot, but the
current launcher does not yet enter those saved register images or claim that
a child continues running while the desktop has control.

The separate VM-task coordinator binds one scheduler task to the existing
Open 386MAX QPI clone lifecycle. It permits activation only when that task is
the scheduler's current task, refuses task teardown while a context remains
attached, preserves ownership after backend failures and releases a clone only
after a verified root transition. Its Windows-preparation operation always
requests and verifies the root transition, even when the owned clone is
already marked inactive, because cached policy state cannot prove which QPI
context another layer left active. This coordinator is linked into the DOS
launcher and host-tested through an injected backend, but is not used for DOS
`EXEC` until the register-entry and private-memory-map layer is complete.

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
VCPI, the versioned Open 386MAX backend interface and QPI. It reports the
negotiated QPI version and current page-table frame when available, and
reports unavailable data explicitly instead of deriving unsupported VM state
from legacy APIs.

`MAXVSET.EXE` maintains the separate `MAXVSET.INI` global preference file.
Every exposed setting has a current launcher consumer: resident-API and ANSI
autoload, exit confirmation, post-child catalogue reload, memory-column
visibility, hotkey launching and Quick Help visibility.  VM scheduling,
swapping, private memory, video/I/O and interrupt options remain absent while
the private backend ABI exposes only its read-only status capability. QPI has
the VM primitives, but settings are withheld until MaxView has a tested
scheduler which consumes them.

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
profile is durable. `mvprocess` converts it into a per-launch resource
contract, binds that contract to the generation-tagged scheduler task and
tracks requested versus enforced feature classes. The launcher currently
leaves every class pending rather than treating stored metadata as enforced;
future backends enable a class only after its resources have been acquired.

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
reports its administrative context status. It then queries standard QPI
function `03h` for the interface version and `07h` for the active page-table
frame. The current capability mask of the
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
| Task enumeration and metadata | foreground implementation | `DOSUSER`, task/timer/mailbox `OBJNEXT`, version-1.00 `WININFO` |
| Window location and buffer | foreground implementation | Full-screen `LOCATE`; `GETBUF` aliases the active text page |
| Task-private API stack | bounded foreground implementation | `OSTACK`/`USTACK` switch to 512 resident bytes and restore exact user `SS:SP` |
| Foreground DOS EXEC | implemented | Ordinary COM/EXE/BAT programs run one at a time |
| Object messages | partial | `HANDLE` stack ABI plus bounded timer control and mailbox writes; blocking messages planned |
| Timers | nonblocking subset implemented | Four identities, relative/absolute countdown and elapsed/remaining/state queries; blocking wait planned |
| Mailboxes | bounded nonblocking queue subset implemented | Two identities, four copied messages each, lifecycle/query/read, erase and base `SETFLAGS`/`GETFLAGS`; empty blocking wait planned |
| Panels and further mailbox operations | planned | DESQview-specific dynamic object API |
| Scheduler policy | bounded foundation | 16 generation-tagged lifecycle slots, saved V86 register/PIC images, context ownership, round-robin dispatch and critical exclusion |
| VM context lifecycle | bounded foundation | Current-task activation, fail-closed root/Windows transition and ordered context teardown over the single owned QPI clone |
| Master IRQ calldowns | bounded foundation | Guarded QPI `1C01h` install, `1C04h` injection and `1C00h` removal with a copied non-null IRQ0-7 table |
| Concurrent V86 tasks | planned | Enter saved registers, build per-task DOS state/private maps and invoke dispatch from the IRQ0 calldown |
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

The first MaxView lifecycle wrapper now implements a deliberately bounded
part of point 2: one owned page-table frame is allocated with `04h`, cloned
with `06h`, switched with `08h`, verified with `07h`, restored to the captured
root with another verified `08h`/`07h` pair, and released with `05h`. A failed
clone immediately attempts to release its allocation; empty or foreign tokens,
a second clone and release while active are rejected. The developer probe
exercises this lifecycle, but the launcher remains foreground-only. Lifecycle
calls are enabled only when private ABI status identifies root context ID 1,
so a foreign startup context is never adopted as the baseline.

The next bounded layer owns up to four private 4 KiB data pages for point 3.
They are allocated with `04h` only after a clone exists and while root is
active. In the clone, the wrapper reads up to four original linear-page frames
with `09h`, installs only frames from that owned pool with `0Ah`, verifies each
with `09h`, and applies the same write/read-back discipline when restoring
them. Linear-page numbers are unique within this bounded table. Any live,
uncommitted or unverifiable replacement initially prevents root restoration.
Only after every entry has an explicit record-checked commit may the table
persist in the inactive clone while the verified root is active. Reactivating
the owned clone exposes the same mappings for verification and restoration.
Any installed mapping prevents page or clone release, and any allocated data
page continues to prevent clone release until all pool entries have been
released from root. This is a genuine private-page lifetime and persistent
mapping-table primitive, not yet a complete DOS memory map or runnable second
task.

The backend wrapper also owns a guarded master-PIC calldown lifecycle. It
validates all eight far handlers before enabling QPI `1C01h`, refuses duplicate
ownership, restricts `1C04h` injection to vectors `08h`-`0Fh`, and clears
ownership only after `1C00h` succeeds. A DOS probe installs a private IRQ0
callback, injects one tick, verifies its execution, chains the original BIOS
handler for normal clock/EOI processing and removes the table. Saving the
interrupted register frame and choosing another task are the next execution
layer rather than claims of this wrapper.

Points 1, 4, 7 and 8 stay with Open MaxView. The bounded scheduler now stores
the point-4 register/PIC image and implements point-7 policy independently of
the backend. The VM-task coordinator establishes the ownership and transition
guards for point 8. Entering and leaving those register images still needs the
V86 execution layer. Not available: the graphics virtualization
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
The backend conformance probe now verifies clone activation, a four-entry
mapping table backed by the owned private-page pool, refusal to leave a clone
before every mapping is committed, persistence in the inactive clone after a
verified root switch, pool/table exhaustion, and ordered page/context release.
A committed private
mapping does not weaken the Windows rule: it remains in the inactive clone,
while the root switch is verified before control returns. The VM-task
coordinator now implements that fail-closed preparation contract; the future
Windows-aware `EXEC` path must call it and treat false as fatal.

Services beyond QPI belong behind the Open-MaxView function range (`4Dxxh`).
Open 386MAX identifies as QEMM only for the functions whose observable
behaviour has conformance tests against QEMM 97.

## Roadmap

The detailed release criteria are maintained in [`ROADMAP.md`](ROADMAP.md).
Remote viewing is deliberately deferred to the 2.x design note and is not part
of the current backend contract.

1. Extend the tested timer foundation with scheduler-backed waits, then add
   keyboard queues, mailboxes and panels;
   provide tiny conformance programs for every call.
2. Carry the implemented `.DVP` parser's advanced fields into an internal
   process descriptor as scheduler and VM capabilities become available.
3. Add V86 register entry/exit and cooperative multi-process loading for Open
   MaxView-aware programs.
4. Extend the scheduler/VM-task ownership state over the tested QPI
   allocate/clone/guarded-switch/bounded-page-pool/map/commit/reactivate/
   restore/ordered-release wrapper, then wrap interrupt, timer and video
   primitives without weakening the private-ABI identity check.
5. Add preemptive scheduling, private DOS state, video virtualisation and
   foreground switching.
6. Test real applications and document deviations from DESQview 2.8.

