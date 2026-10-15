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
| `INT 15h AX=101Bh` | Increments a saturating nesting count | `BEGINC` |
| `INT 15h AX=101Ch` | Decrements the count without underflow | `ENDC` |
| `INT 15h AX=1022h BX=0000h` | `BX=0A01h` | TopView-compatible `GETVER` identity |
| `INT 15h AX=DE04h` | `BX=free bytes`, `CX=largest block`, `DX=total bytes` | Common-memory status |
| `INT 15h AX=DE07h` | `AX=0001h` | `APPNUM`; one foreground program |
| `INT 15h AX=DE0Bh BH=major BL=minor` | Records the requested level; returns `AX=0280h` | `APILEVEL` |
| `INT 15h AX=DE0Ch BX=bytes` | `ES:DI=block`, null on failure; `AX=0/1` mirrors status | `GETMEM` |
| `INT 15h AX=DE0Dh ES:DI=block` | Releases an exact block; `AX=0/1` is an Open MaxView status extension | `PUTMEM` |
| `INT 15h AX=DE10h BH=scan BL=character` | Adds one BIOS-format keyboard entry | Foreground `PUSHKEY` |
| `INT 15h AX=DE11h BL=mode` | Zero disables, nonzero enables cursor-follow mode | `JUSTIFY` state |
| `INT 15h AX=DE12h BX=mode` | Zero selects normal, nonzero C-style linefeeds | `CSTYLE` state |
| `INT 15h AX=DE13h` | `BX=critical nesting count` | `GETCRIT` |
| `INT 15h AX=DE14h ES:DI=handle` | `BL=08h` for the foreground task, otherwise zero | Object type |
| `INT 15h AX=DE15h BL=mode` | Selects error-return policy 0, 1 or 2 | `SET ERROR HANDLING` state |
| `INT 15h AX=DE16h` | `BL=error-return policy` | `GET ERROR HANDLING` |
| `INT 15h AX=DE19h BX=bytes` | `AX=0`, `ES:DI=block`; null pointer and `AX=1` on failure | `GETCOMMON` |
| `INT 15h AX=DE1Ah ES:DI=block` | `AX=0` on release, `AX=1` for an invalid pointer | `PUTCOMMON` |
| `INT 15h AX=DE1Ch` | Increments the critical count | Interrupt-safe `ENTERC` |
| `INT 15h AX=DE1Dh DX=task BH=scan BL=character` | `AX=0` when queued, nonzero if invalid or full | Targeted foreground `PUTKEY` |
| `INT 15h AX=DE1Eh` | `CL=rows`, `CH=columns`, `BL=video mode` | Physical `SCRNINFO` |
| `INT 15h AX=DE1Fh` | `BX=segment` of the task handle | `DOSUSER`; the foreground task owns the single DOS session |
| `INT 15h AX=DE25h ES:DI=67-byte buffer` | Installation directory as a terminated DOS path | `GETDVPATH` |
| `INT 15h AX=DE26h` | `BX=segment` of the task handle (`BX:0000h`) | `GETFOREGROUND` |
| `INT 15h AX=DE2Bh ES:DI=object` | `AX=0`, `ES:DI=next object`; `AX=1` for an invalid handle | `OBJNEXT`; one-item foreground task list |
| `INT 15h AX=DE2Ch DX=0100h BX=task ES:DI=buffer` | `AX=0` and an 11-byte task description | `WININFO`; zero in `BX` selects the foreground task |
| `INT 15h AX=DE2Fh` | `BX=0000h` | No direct-window switch in foreground mode |
| `INT 15h AX=DE30h` | `BX=0000h` | Correctly identifies as not DESQview/X |
| `INT 10h AH=FEh` | `ES:DI` points to the active text buffer | Foreground buffer alias |
| `INT 10h AH=FFh` | Notification accepted | No separate virtual buffer yet |

The default API level is 1.00, automatic viewport justification starts
enabled, C-style linefeeds start disabled, and error policy 0 is selected.
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

The foreground task has a paragraph-aligned, pointer-compatible object handle
with the documented `FEDCh` signature and window/task type. `GETFOREGROUND`,
`DOSUSER`, `ISOBJ`, `OBJNEXT`, `WININFO` and the object-type query therefore
operate on one real resident identity, not placeholder numbers. Starting
`OBJNEXT` at `0000:0000` returns that task; traversing from the returned handle
produces the null end marker. The version-1.00 `WININFO` record identifies task
1, its owner handle, process status bit and the foreground-only constraint.
Dynamic `NEW`, `FREE` and message-object calls remain unimplemented until
their stack ABI and ownership rules have conformance coverage.

Both keyboard injection calls use the real BIOS-format foreground queue.
`PUSHKEY` addresses the current task implicitly; `PUTKEY` additionally
requires the exact foreground task-handle segment and reports a full buffer.
Per-task queues will replace this shared foreground backing only when multiple
Open 386MAX contexts exist.

`GETDVPATH` captures the directory containing `MAXVTSR.COM` before the loader
becomes resident. It always clears the unused part of the caller's 67-byte
buffer and includes a terminating NUL. A root installation is returned in
drive-root form such as `C:\`.

## Open MaxView private diagnostics

Private calls use `INT 2Fh` and are for Open MaxView tools and tests, not for
applications expecting the DESQview interface.

| `AX` | Return |
|---|---|
| `D700h` | `BX=4F44h` (`OD`), `CX=000Ch`, `DX=0280h` |
| `D701h` | `BX=FFFFh` capability bits, `CX=critical depth`, `DX=video segment` |
| `D702h` | Reset critical depth, API level and task modes to defaults |
| `D703h` | `BX=API level`, `CX=program number`, `DX=task-mode bits` |
| `D704h` | `BX=01FFh` extended capability bits, `CX=DX=0` |

For `D703h`, bit 0 of `DX` is automatic viewport justification and bit 1 is
C-style linefeed interpretation. For `D704h`, bits 0 through 8 advertise
`ISOBJ`, object-type, foreground-handle, `GETVER`, `DOSUSER`, `OBJNEXT` and
`WININFO`, targeted `PUTKEY`, and `GETDVPATH` support. The declarations are
in `include/odqapi.h`.

## Conformance probe

After loading `MAXVTSR`, run `DVPROBE`. It validates the presence/version
call, resident installation path, task defaults, `APPNUM`, `APILEVEL`,
`JUSTIFY`, `CSTYLE`, error policy,
task/common-memory allocation, bounds and release, the resident
foreground task handle and its validation/type,
navigates the one-item object list, validates DOS ownership and the versioned
window-information record,
nested `BEGINC`/`ENTERC` regions, `GETCRIT`, `SCRNINFO`, video identity,
alternate video-buffer calls, foreground `PUSHKEY` and targeted `PUTKEY`,
including invalid-handle rejection. It also reports whether the versioned
Open 386MAX backend ABI is available.
