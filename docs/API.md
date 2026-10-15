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
| `INT 15h AX=DE1Eh` | `CL=rows`, `CH=columns`, `BL=video mode` | Physical `SCRNINFO` |
| `INT 15h AX=DE26h` | `BX=segment` of the task handle (`BX:0000h`) | `GETFOREGROUND` |
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
`ISOBJ` and the object-type query therefore operate on a real resident object,
not a placeholder number. Dynamic `NEW`, `FREE` and message-object calls remain
unimplemented until their stack ABI and ownership rules have conformance
coverage.

## Open MaxView private diagnostics

Private calls use `INT 2Fh` and are for Open MaxView tools and tests, not for
applications expecting the DESQview interface.

| `AX` | Return |
|---|---|
| `D700h` | `BX=4F44h` (`OD`), `CX=0008h`, `DX=0280h` |
| `D701h` | `BX=FFFFh` capability bits, `CX=critical depth`, `DX=video segment` |
| `D702h` | Reset critical depth, API level and task modes to defaults |
| `D703h` | `BX=API level`, `CX=program number`, `DX=task-mode bits` |
| `D704h` | `BX=0007h` extended capability bits, `CX=DX=0` |

For `D703h`, bit 0 of `DX` is automatic viewport justification and bit 1 is
C-style linefeed interpretation. For `D704h`, bits 0 through 2 advertise
`ISOBJ`, object-type and foreground-handle support. The declarations are in
`include/odqapi.h`.

## Conformance probe

After loading `MAXVTSR`, run `DVPROBE`. It validates the presence/version
call, task defaults, `APPNUM`, `APILEVEL`, `JUSTIFY`, `CSTYLE`, error policy,
task/common-memory allocation, bounds and release, the resident
foreground task handle and its validation/type,
nested `BEGINC`/`ENTERC` regions, `GETCRIT`, `SCRNINFO`, video identity,
alternate video-buffer calls and foreground `PUSHKEY`. It also reports whether
the versioned Open 386MAX backend ABI is available.
