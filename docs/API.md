# Resident compatibility API

`MAXVTSR.COM` supplies the stable foreground compatibility entry points used
by milestone 0.8. It reports DESQview API 2.80 so software can perform the
standard presence check, but only the calls listed as implemented below are
intercepted. Every other `INT 15h` call is chained to the previous handler.

## DESQview-compatible calls

| Interrupt input | Result or effect | Current scope |
|---|---|---|
| `INT 21h AX=2B01h CX=4445h DX=5351h` | `AL=00h`, `BX=0280h` | Presence and version |
| `INT 15h AX=1000h` | Returns safely | Foreground `PAUSE`; no scheduler yet |
| `INT 15h AX=1001h BX=bytes` | `AX=0`, `ES:DI=block`; `AX=1`, `ES:DI=0000:0000` on failure | TopView `GETMEM` alias |
| `INT 15h AX=1002h ES:DI=block` | Releases an exact block; `AX=0/1` is an Open MaxView status extension | TopView `PUTMEM` alias |
| `INT 15h AX=1016h ES:DI=handle` | `BX=FFFFh` if valid, otherwise zero | `ISOBJ` |
| `INT 15h AX=1018h BH=column BL=row ES=window-below` | `ES=window` or zero | `LOCATE`; foreground full-screen window |
| `INT 15h AX=101Bh` | Increments a saturating nesting count | `BEGINC` |
| `INT 15h AX=101Ch` | Decrements the count without underflow | `ENDC` |
| `INT 15h AX=1022h BX=0000h` | `BX=0A01h` | TopView-compatible `GETVER` identity |
| `INT 15h AX=1024h BX=window` | `ES:DI=buffer`, `CX=bytes`, `DL=0` | `GETBUF`; foreground text buffer |
| `INT 15h AX=102Dh BL=operation` | Query returns `BL=0/1`; 1 enables, 2 disables | Keyboard-mouse compatibility state |
| `INT 15h AH=12h BH=00h BL=selector`, object DWORD on caller stack | Replaces or validates the DWORD | `HANDLE`; selector 00h validates task/timer handles, selector 01h returns the foreground window |
| `INT 15h AH=12h BH=01h BL=0Bh`, reserved DWORD on caller stack | Replaces the DWORD with a timer handle or null | `NEW`; bounded four-object timer pool |
| `INT 15h AH=12h BH=02h BL=00h`, timer DWORD on caller stack | Releases a live timer and pops the DWORD; invalid handles are ignored | `FREE`; timer lifecycle only |
| `INT 15h AH=12h BH=05h BL=00h`, timer then time DWORDs on caller stack | Starts at an absolute hundredths-since-midnight deadline and pops both DWORDs | Timer `WRITE`; time below handle |
| `INT 15h AH=12h BH=08h BL=00h`, timer DWORD on caller stack | Replaces handle with elapsed hundredths | Timer `SIZEOF` |
| `INT 15h AH=12h BH=09h BL=00h`, timer DWORD on caller stack | Replaces handle with remaining hundredths | Timer `LEN` |
| `INT 15h AH=12h BH=0Ah BL=00h`, timer then duration DWORDs on caller stack | Starts a relative timer and pops both DWORDs | Timer `ADDTO`; duration below handle |
| `INT 15h AH=12h BH=0Ch/0Dh BL=00h`, timer DWORD on caller stack | Opens/closes timer and pops handle | Timer `OPEN`/`CLOSE` |
| `INT 15h AH=12h BH=0Fh BL=00h`, timer DWORD on caller stack | Replaces handle with state DWORD | Timer `STATUS`: closed `80000000h`, running `40000000h`, idle zero |
| `INT 15h AX=DE04h` | `BX=free bytes`, `CX=largest block`, `DX=total bytes` | Common-memory status |
| `INT 15h AX=DE05h` | `BX=free KB`, `CX=largest block KB`, `DX=total KB` | Conventional-memory status |
| `INT 15h AX=DE06h` | `BX=free KB`, `CX=largest block KB`, `DX=total KB` | Expanded-memory status |
| `INT 15h AX=DE07h` | `AX=0001h` | `APPNUM`; one foreground program |
| `INT 15h AX=DE0Ah BL=character` | Registers preserved | `DBGPOKE`; append on physical bottom text row |
| `INT 15h AX=DE0Bh BH=major BL=minor` | Records the requested level; returns `AX=0280h` | `APILEVEL` |
| `INT 15h AX=DE0Ch BX=bytes` | `ES:DI=block`, null on failure; `AX=0/1` mirrors status | `GETMEM` |
| `INT 15h AX=DE0Dh ES:DI=block` | Releases an exact block; `AX=0/1` is an Open MaxView status extension | `PUTMEM` |
| `INT 15h AX=DE10h BH=scan BL=character` | Adds one BIOS-format keyboard entry | Foreground `PUSHKEY` |
| `INT 15h AX=DE11h BL=mode` | Zero disables, nonzero enables cursor-follow mode | `JUSTIFY` state |
| `INT 15h AX=DE12h BX=mode` | Zero selects normal, nonzero C-style linefeeds | `CSTYLE` state |
| `INT 15h AX=DE13h` | `BX=critical nesting count` | `GETCRIT` |
| `INT 15h AX=DE14h ES:DI=handle` | `BL=08h` for the task, `0Bh` for a live timer, otherwise zero | Object type |
| `INT 15h AX=DE15h BL=mode` | Selects error-return policy 0, 1 or 2 | `SET ERROR HANDLING` state |
| `INT 15h AX=DE16h` | `BL=error-return policy` | `GET ERROR HANDLING` |
| `INT 15h AX=DE19h BX=bytes` | `AX=0`, `ES:DI=block`; null pointer and `AX=1` on failure | `GETCOMMON` |
| `INT 15h AX=DE1Ah ES:DI=block` | `AX=0` on release, `AX=1` for an invalid pointer | `PUTCOMMON` |
| `INT 15h AX=DE1Ch` | Increments the critical count | Interrupt-safe `ENTERC` |
| `INT 15h AX=DE1Dh DX=task BH=scan BL=character` | `AX=0` when queued, nonzero if invalid or full | Targeted foreground `PUTKEY` |
| `INT 15h AX=DE1Eh` | `CL=rows`, `CH=columns`, `BL=video mode` | Physical `SCRNINFO` |
| `INT 15h AX=DE1Fh` | `BX=segment` of the task handle | `DOSUSER`; the foreground task owns the single DOS session |
| `INT 15h AX=DE22h DX=task` | `DX=process paragraphs`, `BX=used system paragraphs`, `CX=largest free system block`, `AX=flags` | Foreground `PROCESSMEM` |
| `INT 15h AX=DE25h ES:DI=67-byte buffer` | Installation directory as a terminated DOS path | `GETDVPATH` |
| `INT 15h AX=DE26h` | `BX=segment` of the task handle (`BX:0000h`) | `GETFOREGROUND` |
| `INT 15h AX=DE2Bh ES:DI=object` | `AX=0`, `ES:DI=next object`; `AX=1` for an invalid handle | `OBJNEXT`; task followed by live timers |
| `INT 15h AX=DE2Ch DX=0100h BX=task ES:DI=buffer` | `AX=0` and an 11-byte task description | `WININFO`; zero in `BX` selects the foreground task |
| `INT 15h AX=DE2Fh` | `BX=0000h` | No direct-window switch in foreground mode |
| `INT 15h AX=DE30h` | `BX=0000h` | Correctly identifies as not DESQview/X |
| `INT 10h AH=FEh` | `ES:DI` points to the active text buffer | Foreground buffer alias |
| `INT 10h AH=FFh` | Notification accepted | No separate virtual buffer yet |

The default API level is 1.00, automatic viewport justification starts
enabled, C-style linefeeds start disabled, and error policy 0 is selected.
Keyboard-mouse mode also starts disabled.
`MAXVIEW` resets these values and the critical count before and after each DOS
child. In foreground mode
`JUSTIFY` and `CSTYLE` preserve compatibility state; their visible windowing
effects require the future per-task virtual console. Requesting an API level
above 2.80 returns the supported maximum but does not yet display DESQview's
error dialog. The selected error policy is observable now. Allocation failure
returns a null pointer/status in foreground mode; it does not display an
interactive DESQview error dialog.

The current bounded allocator provides eight 256-byte task-memory slots and
four 256-byte common-memory slots. Requests from 1 through 256 bytes occupy
one slot and are zero-filled; larger requests fail without partial
allocation. `D702h` releases every task-memory slot when the launcher resets
the foreground task. Common memory deliberately survives a task reset and
must be returned explicitly. This is a real resident backing store suitable
for early API clients, but it is not yet DESQview's variable-size memory
manager; that requires the multi-context Open 386MAX backend.

The conventional-memory status call walks the validated DOS MCB chain and
uses BIOS `INT 12h` for the installed total. It is therefore a normal
process-context call, not an interrupt-handler service. The expanded-memory
status call translates standard EMS page counts to KB; in the current
foreground EMS model, all unallocated pages form the largest available block.
Unavailable or malformed providers return zero available/largest values.

`DBGPOKE` keeps a resident column, writes only the character byte on the
bottom row of the active physical text page, and wraps at the BIOS column
count. Existing attributes are preserved. Calls in graphics or unknown video
modes are harmless no-ops.

The foreground task and four timer slots have paragraph-aligned,
pointer-compatible object handles with the documented `FEDCh` signature. The
task reports type `08h`; allocated timers report type `0Bh`. `GETFOREGROUND`,
`DOSUSER`, `ISOBJ`, `OBJNEXT`, `WININFO` and the object-type query therefore
operate on real resident identities, not placeholder numbers. Starting
`OBJNEXT` at `0000:0000` returns the task, followed by allocated timers in
stable pool order and then the null end marker. The version-1.00 `WININFO` record identifies task
1, its owner handle, process status bit and the foreground-only constraint.
The `HANDLE` message implements the original caller-stack ABI. Selector `00h`
validates and returns a live task or timer pointer already in the DWORD;
selector `01h` returns the current task's window. Selectors `02h` through
`07h` return `0000:0000` because mailbox, keyboard and OBJECTQ objects do not
exist yet. `NEW` class `0Bh` allocates one of four timers and `FREE` class
`00h` releases it. A fifth allocation returns null, released handles stop
passing `ISOBJ`, and task reset reclaims every timer. `OPEN`, `CLOSE`, absolute
`WRITE` and relative `ADDTO` control timers; `SIZEOF`, `LEN` and `STATUS` query
them using the BIOS clock without a resident DOS call. Deadlines and durations
are bounded to one midnight wrap. Blocking `READ` remains unimplemented until
its scheduling and task-wakeup rules have conformance coverage.

Both keyboard injection calls use the real BIOS-format foreground queue.
`PUSHKEY` addresses the current task implicitly; `PUTKEY` additionally
requires the exact foreground task-handle segment and reports a full buffer.
Per-task queues will replace this shared foreground backing only when multiple
Open 386MAX contexts exist.

`LOCATE` treats the foreground task as one full-screen window. Starting at the
top of the window list (`ES=0`) returns its handle for coordinates inside the
physical text screen; searching below that sole window or outside the screen
returns zero. `GETBUF` accepts either zero for the default window or the exact
foreground handle and returns the active B000h/B800h text buffer and its
BIOS-reported size. An invalid handle returns a null, empty buffer.

`PROCESSMEM` accepts the exact foreground task handle. It reports the current
DOS process allocation from its owning memory-control block and accounts for
the resident task-system slots in paragraphs. No shared or swapped-memory flag
is set in foreground mode. Because current-PSP discovery is a DOS call, invoke
this service from normal process context, not a hardware interrupt handler.
An invalid handle returns `AX=FFFFh` and zero counts as an Open MaxView error
extension.

`GETDVPATH` captures the directory containing `MAXVTSR.COM` before the loader
becomes resident. It always clears the unused part of the caller's 67-byte
buffer and includes a terminating NUL. A root installation is returned in
drive-root form such as `C:\`.

## Open MaxView private diagnostics

Private calls use `INT 2Fh` and are for Open MaxView tools and tests, not for
applications expecting the DESQview interface.

| `AX` | Return |
|---|---|
| `D700h` | `BX=4F44h` (`OD`), `CX=0015h`, `DX=0280h` |
| `D701h` | `BX=FFFFh` capability bits, `CX=critical depth`, `DX=video segment` |
| `D702h` | Reset critical depth, API level and task modes; release task memory and timers |
| `D703h` | `BX=API level`, `CX=program number`, `DX=task-mode bits` |
| `D704h` | `BX=FFFFh` extended capability bits, `CX=DX=0` |
| `D705h` | `BX=0007h` object-message capability bits, `CX=DX=0` |

For `D703h`, bit 0 of `DX` is automatic viewport justification and bit 1 is
C-style linefeed interpretation. For `D704h`, bits 0 through 15 advertise
`ISOBJ`, object-type, foreground-handle, `GETVER`, `DOSUSER`, `OBJNEXT`,
`WININFO`, targeted `PUTKEY`, `GETDVPATH`, `LOCATE`, `GETBUF` and `PROCESSMEM`
plus conventional-memory, expanded-memory, `DBGPOKE` status-line output and
keyboard-mouse mode. The declarations are in `include/odqapi.h`.
For `D705h`, bit 0 advertises the bounded `HANDLE` message subset, bit 1
advertises timer `NEW`/`FREE`, and bit 2 advertises nonblocking timer control
and queries. Later message classes receive separate bits rather than being
inferred from API version 2.80.

## Open 386MAX QPI wrapper

`include/maxbackend.h` separates the private Open-MaxView identity/status ABI
from standard QPI operations. `odq_max_backend_query` must succeed before any
context call. Its `qpi_context` member and the context token are 32-bit
physical page-frame numbers, matching QPI's `EDX` contract.

`odq_max_context_clone` uses QPI `04h` to allocate one page and `06h` to clone
the active 0-4 MB page table into it. It never invokes `08h`, so the clone is
not made active. This first wrapper owns at most one clone. If `06h` fails it
immediately attempts to roll the `04h` allocation back through `05h`.

`odq_max_context_activate` accepts only the owned clone, calls QPI `08h` and
then verifies the active frame through `07h`. `odq_max_context_restore` uses
`08h` to return to the root frame captured by the first successful backend
query while private status identifies context ID 1. A query made from any
other administrative context reports status but does not enable lifecycle
calls. If activation verification fails, the wrapper immediately attempts
root restoration. Callers must treat a failed restoration as fatal and must
not start Windows or free the clone.

`odq_max_context_release` accepts only that owned, non-active clone and clears
the caller's token after QPI `05h` succeeds. Empty, foreign and duplicate
tokens fail closed. These calls establish safe resource lifetime only; they
are not a scheduler or permission to free the root/active context. Release is
explicitly rejected until a verified root restoration has cleared the active
state. It is also rejected while any owned private data page remains allocated.

`odq_max_page_allocate` and `odq_max_page_release` manage a fixed pool of four
private 4 KiB data pages with QPI `04h`/`05h`. Allocation requires an existing
clone and the verified root context; release additionally requires that no
replacement mapping is active. Pool overflow, release from the active clone,
and empty or foreign page tokens fail closed. Slots are independently owned
and may be released in any order after mappings have been restored. Because
QPI `0Ah` accepts a 16-bit physical page frame, mapping an allocated frame
outside that representable range is rejected rather than truncated; the full
32-bit allocation token remains available for release.

`odq_max_mapping_query`, `odq_max_mapping_install`,
`odq_max_mapping_commit` and `odq_max_mapping_restore` provide the first
bounded part of the task-memory map. They accept a 4 KiB linear-page number
from `0000h` through `03FFh` and use QPI `09h`/`0Ah` only while this wrapper's
owned clone is active. The mapping record contains the linear page, the saved
original 16-bit physical frame, the requested frame, an installed flag and a
committed flag. The requested frame must be the private page owned by this
wrapper. Up to four replacements may be outstanding, and their linear-page
numbers must be unique.

Installation reads the old frame and verifies the new frame, but initially
leaves that table entry uncommitted. Any uncommitted or unverifiable entry
blocks root restoration. `odq_max_mapping_commit` validates the complete
record against backend-owned state; a verified switch back to root is
permitted only after every installed entry is committed. The replacements
then remain in the inactive clone. The clone must be reactivated before
querying or restoring them. Restoration writes each saved frame and reads it
back before clearing that entry's two flags. Any installed mapping, committed
or not, blocks release of all data pages and the clone.

The mapping record and the backend code, data and active stack must remain
reachable while these calls run; callers therefore must not use this
low-level operation to replace a page containing any of them. The wrapper
currently tracks frame identity, not raw PTE flag bits. Use of QPI
`1F00h`/`1F01h` will be required before mappings with special cache or device
attributes are supported.

These assembly entry points follow Open Watcom's 16-bit register calling
convention. Registers not used for parameters or the `AX` return value are
preserved across the public wrapper even when an underlying QPI call uses
them. This is part of the C API contract, not merely an optimization detail.

## Conformance probe

After loading `MAXVTSR`, run `DVPROBE`. It validates the presence/version
call, resident installation path, task defaults, keyboard-mouse mode,
`APPNUM`, `APILEVEL`,
`JUSTIFY`, `CSTYLE`, error policy,
task/common-memory allocation, bounds and release, the resident
conventional- and expanded-memory status services,
physical status-line debug output,
foreground task handle and its validation/type,
navigates physical coordinates and validates the foreground text buffer,
navigates current-process and bounded system-memory accounting,
navigates the resident object list, validates DOS ownership and the versioned
window-information record,
nested `BEGINC`/`ENTERC` regions, `GETCRIT`, `SCRNINFO`, video identity,
alternate video-buffer calls, foreground `PUSHKEY`, targeted `PUTKEY` and the
`HANDLE` caller-stack ABI, including valid, foreign and unavailable object
selectors. The separate `OBJPROBE.COM` exhausts the four-timer pool, checks
unique pointer-compatible handles, validates object identity/type and
enumeration, exercises open/close, relative and absolute countdown starts,
elapsed/remaining/state queries and stack consumption, frees and reuses a slot, verifies reset
reclamation, and cleans up its final timer. `DVPROBE` also reports whether the versioned
Open 386MAX backend ABI is available and, when it is, the standard QPI version
and active page-table frame. Against a context-capable provider it also checks
active/root and empty-token rejection, rejection of a second outstanding
clone, allocation and exhaustion of the four-page private pool, a four-entry
saved/set/read-back/restored mapping table backed by those QPI data pages,
rejection of a root switch before every entry is committed, persistence across
a verified root/clone switch after full commit, refusal to release resources
while any mapping remains installed, and page/context release only after
verified restoration.
