# Testing

## Host tests

Run:

```sh
make test
```

The catalogue, settings, automatic-detection, DVP and scheduler-policy modules
are compiled as strict C89 with warnings as errors. Tests cover valid and
invalid records, limits, duplicate handling, atomic-save behaviour and
detection. Scheduler tests cover table exhaustion, deterministic round-robin
selection, wait/wake transitions, nested critical exclusion, teardown, slot
reuse, stale-handle rejection, V86 register images and QPI-token attachment.
The injected VM-backend test covers current-task-only activation, failed-root
retention, mandatory Windows root verification, failed-release retention and
ordered detach/release. Synthetic, freely generated DVP data tests
checksum rejection, bounded field parsing and catalogue conversion. Process
descriptor tests cover profile classification, scheduler binding, partial
enforcement, unknown feature rejection and teardown reset. Python unit tests
exercise the read-only QIP parser.

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
  all three bounded system-memory allocation entry points,
  conventional/expanded-memory status and attribute-preserving physical
  `DBGPOKE` output,
  nested `BEGINC`/`ENTERC` sections, `GETCRIT`, foreground `LOCATE`/`GETBUF`,
  `PROCESSMEM`, the `HANDLE` message stack ABI with valid/foreign/unavailable
  selectors, four-slot timer `NEW`/`FREE` exhaustion, identity, type,
  enumeration, reuse, stack popping, open/close, relative/absolute countdown and
  elapsed/remaining/state queries, foreground `PUSHKEY`,
  a two-slot mailbox lifecycle with exhaustion, type/identity checks,
  enumeration, `WRITE` status-zero delivery, copied `ADDTO` and referenced
  `SUBFROM` records, four-entry queues,
  count/length/status, full-queue
  failure, FIFO pointer-return `READ` and `READINTO` data/status delivery,
  last-read `ADDR` sender identity, failed-read retention and lifecycle reset,
  empty-read failure, erase,
  close-time discard/preservation, closed-write flags, bounded
  `SETNAME`/`GETNAME` and `FINDMAIL`, reuse and reset
  reclamation, and
  alternate video buffer, plus `SCRNINFO` and non-DV/X identity;
* foreground window `AT` with explicit/default selectors, plus `PRINTC`
  character/attribute output, cursor advancement and `BX=0` synchronization;
* all 16 second-level callback allocations, exhaustion, masked dispatch,
  foreground-task `ES`, release/reuse and reset cleanup;
* PC-speaker `SOUND` normalization, queued silence, current/all cancellation,
  32-entry saturation and task-reset cleanup;
* `OSTACK`/`USTACK` segment switching, resident-stack data use, nested API
  entry, exact user `SS:SP` restoration and stack reuse;
* absent and stubbed Open 386MAX backend reporting, including QPI version and
  active page-table frame, empty-token rejection, root-release and second-clone
  guards, master-IRQ table validation, duplicate install rejection, synchronous
  IRQ0 injection, invalid-vector rejection and ordered removal, verified
  clone/root switching, four-page private-pool exhaustion,
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

## Multitasking tests on Open 386MAX

`tests/qemu/mvtest.sh` boots MS-DOS 6.22 with Open 386MAX in QEMU through
Open386MAX's `linux/test/dosboot.sh` (`MAXROOT`, default `../Open386MAX`,
needs its `build/bin` and `build/TESTS`). The cases follow Open386MAX's
DESQview test:

| Case | Checks |
|---|---|
| `two` | two TICK tasks count side by side, COM1 output of one |
| `mem` | each task its own conventional memory (same PSP, patterns kept) and text pages 1-7 |
| `serial` | a background task receives COM1 by IRQ4 and echoes 3000 bytes |
| `nodes` | tests/SERPRB as two BBS nodes, COM1 (IRQ4) and COM2 (IRQ3), and TICK; the foreground switched during the transfer:  every byte of 3000 on each line echoed unchanged, both count 3000, TICK counts (DESQview 2.80 the same; `NCOUNT=30000 NRATE=960` for 9600 baud, an IRQ per byte) |
| `samecom` | two SERPRB tasks hook COM1's IRQ4, the first in front:  as under DESQview 2.80 the one that hooked it last (task 3, in the background) gets all 3000 bytes, task 1 none |
| `keys` | screen and keys only for the foreground; Ctrl+Alt+n; waiting tasks yield |
| `kill` | killed tasks end through DOS, a new one starts in a freed slot |
| `crit` | a background critical error comes to the front |
| `desk` | MAXVIEW.EXE starts programs as tasks, Alt, task list, exit |
| `deskmany` | MAXVIEW.EXE with 12 programs:  the task list scrolls, IDs 1-9 then A-C, Ctrl+Alt only for 1-9, Enter on C gives KEYPROBE the keys, all TICKs count |
| `win` | MAXVIEW windows: two tasks on one screen, typing, move, zoom, close; the title's blank a double line ("1══Probe═A", as DV's "1══DOS═(128K)") |
| `dvapi` | DESQview PAUSE, BEGINC/ENDC, APPNUM per task (with MAXVTSR) |
| `cwd` | current directory per task (CDS), MVRUN's unchanged |
| `ems` | EMS page frame mapping per task, with 47h/48h save/restore |
| `gfx` | VGA mode 13h task and text task:  each one's mode on switching, graphics held in the background, drawn again |
| `ipc` | task mailboxes as DESQview 2.80 (IPCPRB measured in two DV windows gives the same):  HANDLE 03h differs per task; AT takes the column on top; SETNAME and WRITE the length on the address; FINDMAIL finds the server's mailbox; READ 03h waits for the client's message and leaves the length on top; ADDR gives the client's task handle (its HANDLE 01h), and WRITE 02h with it answers into the client's own mailbox |
| `wwrite` | window `WRITE` as DESQview 2.80 (WINPRB in a DV window gives the same):  8 bytes popped, 12 with the handle; the cursor after "Hello", "AB", CR LF, BS; the text on the screen |
| `wstream` | a window stream as DESQview 2.80 (STRPRB in a DV window gives the same):  C0h cursor, E2h colour, a literal, a repeat, attributed blanks, then plain text in the stream's colour |
| `wquery` | a query stream as DESQview 2.80 (QRYPRB in a DV window):  cursor, colour, mode byte and flags as there; size 25 x 80 and no frame for the screen-sized window (DV:  its 10 x 78 framed window) |
| `crtc` | a background task's direct CRTC cursor and DAC OUTs (5 s) leave the foreground's cursor and palette on the hardware; it reads its own cursor back (IN 3D5h, INT 10h AH=03h); without the trapping:  the foreground's cursor and DAC changed |
| `pointer` | a pointer object as DESQview 2.80 (PTRPRB in a DV window with CuteMouse gives the same):  NEW 0Fh, OPEN to the own window, buttons only; a left click, then a right one:  READ 07h gives the pointer, its READ 5 bytes "4 11 01", then "5 5 15 02" (window-relative row/column, button); needs CuteMouse |
| `wobj` | a window object as DESQview 2.80 (WOBPRB in a DV window gives the same frame, title and contents):  a WRITE of stream E6h 4,12 to the own window gives the handle, then EFh "probe", C2h 14,30, "hello" in E2h 1Fh, "A" "B" "C" "D" in 00h/1Fh/70h/7Fh, D4h, E4h:  the frame (31h, the title after DA), physical colours as they are, blanks 17h; through window 1's colours (the core's palette, as DV's DOS window) they show as DV's bytes:  frame 07h, 79h, 33h 79h 13h 19h, blanks 71h; C2h 17,50 + E4h moves it (the old place restored), FREE takes it away |
| `menu` | demos/MENU as under DESQview 2.80 (the same program in a DV window gives the same screen bytes and records):  NEW 08h window "colours" 4x12, a keyboard object opened to it in field mode, BDh, E5h 18h and a field table of 4 select fields + Esc, moved to 9,33, shown, on top:  a double frame, "red" pointed at in 70h, the others 07h, the frame 31h (through window 1's colours, the core's palette:  DV's 13h, 31h, 07h); Down points at "green", Enter gives the record 02 0100 'Y' and "item 2 chosen" (at the line's start), "green" stays pointed at; B gives 03, Q 04 and the end |
| `demos` | demos/MOUSE then demos/HELLO in one task (COMMAND /C, CuteMouse; SKIP without it), as under DESQview 2.80:  ERASE of the own window puts MOUSE's text on top, the pointer WRITE gives a move mark at row 5 column 30, the left click a mark where it was, the right click ends; HELLO's line through the API's WRITE |
| `countdn` | demos/COUNTDN as under DESQview 2.80:  the window "countdown" with an empty seconds field, "3" typed fills it from the right, Enter starts the timer:  "Left: 002" after 1.5 s, 000 and "time is up" in the own window after 6.5 s; Esc ends |
| `serve` | demos/SERVE (task 1) and ASK (task 2, foreground) as under DESQview 2.80 in two windows:  ASK finds SERVE's named mailbox, two lines come back in capitals; SERVE (Ctrl+Alt+1) counts 00002 requests and its clock (timer READ) moves on |
| `subtask` | tests/SUBPRB as under DESQview 2.80:  NEW 08h with an entry point gives a handle (4 bytes on the stack); the subtask (DS = ES = SS its stack, DX:CX its task's handle) writes to its task's window and sends "hi", status 7, to its task's mailbox (BL=02h); it runs alongside; FREE of its handle ends it |
| `launch` | demos/LAUNCH as under DESQview 2.80:  H starts HELLO through `APP_START` with a DVP made in memory (a task of its own, started by task 1, in front); it ends (close on exit) and LAUNCH is in front again with the new task's handle in its window; W starts WORMS in front (N makes a worm), Q in WORMS brings LAUNCH back; LAUNCH ends with exit code 0 |
| `ownwin` | tests/OWNPRB as under DESQview 2.80:  its own window sized to 5x20 (`C3h`, `C5h`) and moved to 6,30 (`C2h`) becomes a window there:  its text at row 6, column 30, a double frame with corners at 5,29 / 5,50 / 11,29 / 11,50, titled "1══OWNPRB" (its number, two double lines, the program), blanks in the screen's colour (07h); sized again (8x40, `C2h` 3,10) it is a window of that size there, "second" at its 0,0 over the old contents ("secondndow"), the old frame gone |
| `subown` | tests/SOWPRB as under DESQview 2.80:  a subtask sizes its own window to 4x20 (`C3h`, `C5h`) and moves it to 15,40 (`C2h`):  "sub own" at row 15, column 40, a single frame with corners at 14,39 / 14,60 / 19,39 / 19,60, untitled, the frame shown 07h (raw 31h), the contents shown 17h (raw 71h:  the core's palette swaps task 1's colours); the task's "main made" stays in its window; FREE ends the subtask, SOWPRB exit code 0 |
| `worms` | demos/WORMS as under DESQview 2.80:  three worms (subtasks with a timer each, `WRITE` of a stream to the task's window per step) in green, red and yellow crawl; K kills the newest; S stops them all (the screen stands still); Q ends with exit code 0 |
| `fieldops` | broadcast and scrolling as DESQview 2.80 (BCSPRB in a DV window gives the same):  F7h "HELLOabcd" fills fields 1 and 3 (bit 5), not 2; FAh 1 gives "ELLO ", FBh 3 " abc", F8h on a 2x3 field "456" and blanks; then "z" Enter. (Whether a click into a fill-in field moves the cursor under DV is not measured yet:  the pointer could not be placed reliably.) |
| `mouse` | a left click on a select field as DESQview 2.80 (MSEPRB in a DV window with CuteMouse gives the same):  "NYN", status 1, 1Fh, C3h; needs CuteMouse (`CTMOUSE=` path of `ctmouse.exe`, default the local scratch copy; skipped without it); the pointer is moved by QEMU monitor `mouse_move` steps of at most 8 counts, 0.2 s apart (larger or faster ones are accelerated) |
| `records` | numbered field records as DESQview 2.80 (NUMPRB in a DV window gives the same):  fill-in, select (key B), fill-in; "a" "b" Enter in mode 10b gives records 1 (5 bytes "ab.."), 2 (1 byte "N":  the "b" went into field 1), 3 (3 bytes); "a" "c" Enter in mode 11b only record 1 |
| `selects` | select fields as DESQview 2.80 (SELPRB in a DV window gives the same):  three select fields with keys A/B/C, "x" (ignored) then "b":  READ returns at once with "NYN", status 1, field 2 in the selected colour 1Fh and type C3h, the others 07h/C0h; Enter alone under DV gives "NNN", status 0 |
| `fields` | input fields as DESQview 2.80 (FLDPRB in a DV window gives the same):  two fill-in fields, "ab" Tab "x" Enter:  READ gives 8 packed bytes from the screen ("ab" + what was there, "x" + ..), status 0, header current field 2, both types with the modified bit (81h) |
| `objq` | the task's OBJECTQ as DESQview 2.80 (OBQPRB in a DV window gives the same):  READ 07h gives the expired timer, then the mailbox after a WRITE, the keyboard after a key, the restarted timer; 4 bytes pushed each |
| `kbd` | the task's keyboard object as DESQview 2.80 (KBDPRB in a DV window gives the same):  READ 05h waits for a key and gives its character, F1 as 00h with STATUS 3Bh, STATUS 0 after an ordinary key; TICK counts meanwhile |
| `objs` | stack effect of `NEW`/`HANDLE`/`FREE` as DESQview 2.80 (+4, +4, 0, -4); a task's `GETMEM` blocks and mailbox come back when it ends, a common block and a timer stay (as DESQview when a window is closed); two tasks at once get 8 GETMEM blocks each (the pool is per task); the task handle of a task that ended is no object any more (LEAKPRB V) |
| `many` | 16 task slots (`MVRUN /N16 @list`):  15 TICK tasks count side by side, a 16th finds the table full |
| `progs` | Open386MAX's regression tests (XMS, EMS, VCPI, VDS, DPMI, ...) each in a task, compared with plain DOS |

`tests/qemu/dvcompare.sh` runs the scenarios `two`, `dvapi`, `cwd`, `ems`
and `gfx` in two windows of real DESQview 2.80 on Open 386MAX (a local
image, `DVIMG`, default `~/mars/scratch-386max/dvbbs.img`; DESQview is not
free software and stays out of the repository) and in MaxView tasks, and
prints the measurements side by side.  MaxView must do at least what
DESQview does.  What it showed so far:  DESQview reports version 0250h
(2.80, minor in binary) and keeps 40:F0h per window (MaxView does both
now); PAUSE gave the other task more under DESQview (x4 against x2:
it favours the foreground; the core now gives the task with the keys
three times the slice, MVRUN /Tf,b, and comes to x4.6); its DOS window cannot show its menu over a VGA graphics
program; and an Open 386MAX bug (IRQs on vector 68h swallowed in PL0,
DESQview hung on EMS 47h/48h), fixed there.  Opening DOS windows (128K) until
DESQview refused ("Not enough DESQview common memory", its default
setup) gave 13 windows on Open 386MAX and 14 on QEMM 97:  MaxView has
16 task slots in MAXVIEW.EXE (up to 30, `mvk_datasize`).  LEAKPRB in DESQview windows showed
its object rules:  `NEW` and `HANDLE 01h` push their result (an Open
MaxView that expected a reserved DWORD overwrote the caller's stack), a
program that ends in a window frees nothing (the window lives on), and
closing the window gives back all but the common block and about 40
bytes (the timer, it seems) of what it took.

`MVDEBUG=1` assembles the core with trace characters on port E9h; the
script stores them as `build/test-qemu/<case>.e9`.

## Before a release

Run the complete build and test sequence from a clean tree:

```sh
make clean
make package
make test
make test-dos
make setup-package
```

Also run `git diff --check`, inspect `build/OpenMaxView/`, install that exact
directory into a fresh DOSBox machine and exercise the full-screen tools with
a keyboard. The automated suite is strong on stable behaviour but does not
replace visual inspection of an 80x25 interface.

For a release candidate, `make release-check` performs the clean automated
sequence and writes the DOS ZIP, HTML, PDF, EPUB and `SHA256SUMS.txt` below
`build/releases/<version>/`. Verify the checksums, install from the extracted
DOS ZIP, and retain the exact tested artifacts for the GitHub release.

## Adding compatibility work

Every newly implemented DESQview call needs a small independent DOS probe, a
documented expected result and a negative/unsupported case. Backend additions
need tests for capability negotiation before tests for the capability itself;
an older Open 386MAX must fail closed rather than be misidentified.
