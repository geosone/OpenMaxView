# Programming DOS applications for Open MaxView

This handbook explains how to make a DOS program cooperate with Open MaxView.
Examples target Open Watcom C in 16-bit real mode. The public declarations are
in `include/odqapi.h`; no NASM dependency is required.

![DOS application compatibility levels](images/program-levels.svg)

## Compatibility levels

A program may be:

* **DOS-compatible**: uses DOS and BIOS services and runs in the current
  foreground launcher.
* **cooperative**: detects the resident API, yields during idle loops and uses
  short critical regions.
* **task-aware**: additionally uses documented memory, video, keyboard and
  task-object calls implemented by `MAXVTSR`.
* **1.x virtual-task ready**: declares direct video, I/O and serial needs and
  has been tested with isolated contexts and background scheduling.

Always retain an ordinary DOS fallback unless the program genuinely requires
the task API.

## Build environment

Compile for DOS with Open Watcom and link with JWlink from Open 386MAX. A
typical small-model command is:

```text
wcc -bt=dos -ms -0 -os -s -zq -w4 -i=include program.c
jwlink format dos name PROGRAM.EXE option stack=4096 file program.obj
```

The repository `GNUmakefile` contains complete library paths and reproducible
examples. Assembly modules use the embedded JWasm in 8086 mode.

## Detecting the environment

Use the standard presence call before any optional service:

```c
#include <dos.h>
#include <string.h>
#include "odqapi.h"

static int maxview_present(unsigned *version)
{
    union REGS inregs, outregs;
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = 0x2b01;
    inregs.x.cx = 0x4445;
    inregs.x.dx = 0x5351;
    int86(0x21, &inregs, &outregs);
    if (outregs.h.al == 0xff)
        return 0;
    *version = outregs.x.bx;
    return 1;
}
```

`BX=0280h` identifies the compatible API level. Open MaxView-private feature
negotiation uses `ODQ_MUX_STATUS`, `ODQ_MUX_INFO` and `ODQ_MUX_CAPS2`. A
portable application should prefer documented calls and treat private bits as
optional acceleration or diagnostics.

## Yielding instead of busy waiting

Call `PAUSE` when an idle loop has no immediate work:

```c
static void cooperative_pause(void)
{
    union REGS inregs, outregs;
    inregs.x.ax = ODQ_DVC_PAUSE;
    int86(0x15, &inregs, &outregs);
}
```

Recheck the program's condition after every return. A scheduler may wake a
task for input, a timer or another object. Do not assume a minimum sleep time.

## Critical regions

Use `BEGIN_CRITICAL` and `END_CRITICAL` around the smallest state update that
must not be sliced. Nesting is supported. Never surround user input, file I/O,
long calculations or an idle wait.

```c
inregs.x.ax = ODQ_DVC_BEGIN_CRITICAL;
int86(0x15, &inregs, &outregs);
/* update shared in-memory state */
inregs.x.ax = ODQ_DVC_END_CRITICAL;
int86(0x15, &inregs, &outregs);
```

`ENTERC` is the interrupt-safe increment form. The normal exit remains
`END_CRITICAL`. An unbalanced depth is a program defect even though the
launcher resets task state after a foreground child.

## Resident memory

The current allocator is deliberately bounded. `GET_MEMORY` accepts 1 to 256
bytes and returns a zero-filled `ES:DI` block; eight task slots exist.
`GET_COMMON` uses four global 256-byte slots. Common blocks survive a task
reset and must be released explicitly.

```c
union REGS inregs, outregs;
struct SREGS segs;
void far *block;

memset(&inregs, 0, sizeof(inregs));
segread(&segs);
inregs.x.ax = ODQ_DVC_GET_MEMORY;
inregs.x.bx = 128;
int86x(0x15, &inregs, &outregs, &segs);
block = MK_FP(segs.es, outregs.x.di);
if (segs.es == 0 && outregs.x.di == 0) {
    /* allocation failed */
}
```

Release the exact returned pointer with `ODQ_DVC_PUT_MEMORY`; interior,
duplicate and foreign pointers are invalid. The fixed slot size is a current
implementation limit, not a promise for the later variable-size allocator.

## Foreground task object

`GET_FOREGROUND` returns the segment of a `segment:0000` task handle. Validate
an arbitrary handle with `IS_OBJECT` before using it. `OBJECT_TYPE` returns
`ODQ_OBJECT_WINDOW_TASK` for the current resident task object.

The message calls `HANDLE`, `NEW`, `FREE`, mailboxes, timers and panels use a
special stack ABI and are not implemented yet. Do not substitute private
handles or assume that an integer is a valid object pointer.

## Text video

`INT 10h/AH=FEh` returns the active logical text buffer in `ES:DI`; in the
current foreground implementation it aliases B000h or B800h. After modifying
through the returned buffer, issue `INT 10h/AH=FFh` as the change
notification.

For 1.x readiness, prefer DOS/BIOS output or this logical-buffer query over a
hard-coded B800h pointer. Do not assume 80 columns, 25 rows or colour mode;
`ODQ_DVC_SCREEN_INFO` reports the physical parameters.

## Keyboard input

Use BIOS or DOS keyboard calls for ordinary input. `ODQ_DVC_PUSH_KEY` inserts
one BIOS-format scan/character pair for the foreground task. Programs must
handle extended keys and must not assume that injection succeeds when the BIOS
queue is full.

## Serial and BBS programs

An idle communications program must yield, but it must not poll so slowly
that a UART overruns. Prefer an interrupt-driven driver or FOSSIL provider.
Document whether the program uses BIOS `INT 14h`, direct UART I/O or FOSSIL.

For the 1.x backend:

* declare the port base and IRQ rather than assuming COM3/COM4 defaults;
* never access a UART owned by another task;
* keep hardware handlers bounded and defer disk/protocol work;
* tolerate background scheduling and loss of keyboard focus;
* cleanly handle carrier loss and a requested shutdown;
* do not request swap-out while a live connection depends on local buffers.

The full contract and test matrix are in `BBSGUIDE.TXT`.

## Program catalogue and migration

Ship a documented catalogue example or detection rule instead of modifying a
user file during installation. A rule in `MAXVAUTO.DAT` contains:

```text
filename|title|command|min-kb|max-kb
```

Use a DVP only when compatibility with existing installations is needed.
Validate with `MAXVDVP /CHECK`, inspect with `/LIST`, and remember that current
advanced scheduling and serial fields are diagnostic until 1.x enforces them.

## Rules for well-behaved tasks

* Use DOS/BIOS services where possible.
* Yield in empty polling loops.
* Keep interrupts disabled only for the few instructions that require it.
* Chain or restore interrupt vectors you replace.
* Avoid hard-coded video memory and undocumented DOS internals.
* Declare direct I/O, IRQ and serial requirements.
* Save files before requesting task termination.
* Treat capability absence and allocation failure as normal runtime cases.
* Keep an ordinary DOS execution path for optional integration.

## Testing checklist

1. Build with Open Watcom warnings enabled.
2. Run under plain DOS without `MAXVTSR`.
3. Run with `MAXVTSR` and verify the detection/fallback paths.
4. Exercise allocation failure and invalid-handle rejection.
5. Test monochrome and colour text modes when the program draws directly.
6. Run `DVPROBE` to confirm the environment before diagnosing the program.
7. For 1.x, test foreground/background switching, forced close, low memory,
   serial load and long-duration operation.

The precise implemented call table and register contracts are installed as
`API.TXT`. Code should depend on that table, not on planned roadmap entries.

