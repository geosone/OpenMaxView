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
| `desk` | MAXVIEW.EXE starts programs as tasks; Alt shows the windows and the menu at the top right in Open 386MAX's look (single frame 70h, the bar 0Fh, red triggers, keys at the right, items not available yet 78h, a shadow), its items those of DESQview 2.80's main menu; Open Window lists the programs by key, Switch Windows the windows by number (2 gives KEYPROBE the keys in its window), Quit MaxView asks "Are you sure?" and closes TICK |
| `deskmany` | MAXVIEW.EXE with 12 programs opened through Open Window:  Switch Windows lists all, numbered 1-9 then A-C as DESQview's; C gives KEYPROBE the keys; all TICKs count |
| `win` | MAXVIEW windows: two tasks on one screen; Switch Windows 1 and typing into it; Rearrange (as DESQview's items) Move; Zoom; Close Window Yes; the title's blank a double line ("1══Probe═A", as DV's "1══DOS═(128K)") |
| `rearr` | MAXVIEW's Rearrange menu (behaviour measured under DESQview 2.80 with TICK):  Scroll S, Position 1-9, Freeze F, Hide H, Put Aside P offered; TickA frozen, TickB hidden, TickD put aside, TickC in front, KEYPROBE put at 9 (frame corners 13,41 / 24,79); B and D not on the screen but in Switch Windows; Scroll 3 right shows "probe D ready" without "key"; after ~20 s the frozen and put aside TICKs stopped (under a third of the front one's count, DV 8 / 8 of 45), the hidden one ran on (DV 50) |
| `tune` | MAXVIEW's Tune Performance and Change Colors:  the dialog shows Revive Mouse, Run in background [Y], Share CPU in front [Y], Share EGA Y, Allow swapping out [Y] (window and system), Foreground ticks [ 6], Background ticks [ 2]; S, F, A, W make them [N], [ 7], [N], [N]; M without a driver says so; TickB in front not sharing for ~20 s:  TickA behind waited (its count over 10 below B's although it started first); Change Colors Down, Right:  KEYPROBE's 07h text shown 18h |
| `dvpopt` | A program whose DVP says Runs in background N, Share CPU N, Allow Close Window N (184h 30h, 16Fh E1h, 18Bh CDh, as DESQview 2.80 writes them):  Close Window has no key, Tune shows Run in background [N] and Share CPU [N]; ECHO with Close on exit N:  its window stays, a DOS prompt in it |
| `dvpwin` | A program whose profile gives the starting window (row 4, column 2, 9 x 40) and Maximum Height and Width 9 x 40:  its frame's corners at (3,1), (13,1), (3,42), (13,42); Resize right and down leaves them there |
| `mvlaunch` | `APP_START` in `MAXVIEW`:  demos/LAUNCH starts WORMS, a window of its own in Switch Windows next to the Launcher's |
| `memstat` | Memory Status (MAXVMEM) in a MAXVIEW window:  DESQview's rows (Common, Conventional, Expanded Memory; total, available, largest); what new windows can get is less with a DOS window open |
| `video` | Video Options through Open 386MAX's MAXTEXT (`MAXTEXT.SYS` in CONFIG.SYS, its public handle IOCTL API):  the windows view starts in the higher mode MAXTEXT sets (80 x 50 in QEMU:  BIOS 40:84 = 49), the menu lists MAXTEXT's 80 and 132 column modes with it in use; 1 sets 25 rows, 3 50 again; Position 2 on 50 rows frames rows 26-49; Zoom gives the program its 25 rows, back in the windows view 50 again; leaving the windows view the launcher has 25 rows. Checked through the BIOS data and screen memory:  in QEMU's standard VGA the display stays blank once MAXTEXT.SYS is loaded (a MAXTEXT matter). 132 columns (no VBE text modes in QEMU's VGA BIOSes) were checked by hand in 86Box with the S3 cards' own VGA BIOSes:  Trio64 132 x 43 (Zoom 80x25 and back, Quit to 80x25), Trio64V2/DX 132 x 25 and its refusal of 132 x 43 shown on the status line, at the start 132 x 25 there (132 x 43 refused, the next tried) |
| `mrs` | Rearrange's Move / Resize / Scroll box:  Move shows the box (Move, Resize, Scroll, Done) and its hint, the arrows move the window; R switches to Resize, S to Scroll; Enter ends, back in the window |
| `learn` | Learn:  Shift+Alt shows the Learn menu (not learning); Start Script on F6 named hi, a command typed and learned; while learning the menu shows it, Finish keeps 23 keys; F6 twice runs the command twice (C:\L.TXT 3 lines) without F6 reaching the program; Display Scripts lists hi on F6; Save Scripts writes MAXVIEW.SCR |
| `lpause` | Learn's pauses:  the menu while in a fixed and a variable pause, the Time Delay prompt; played, an F7 script stops at its fixed pause and goes on after two keys of the user's, an F8 script takes the user's keys until Enter (Enter not given to the program) and goes on after a 3 s delay; C:\P.TXT gets ab, q, zy, uv |
| `dial` | Mark's Auto Dialer with MAXVSET.INI's ACCESS1=9,:  Mark shows Mark Phone # P and Talk T, Dial only after a number; P on a blank finds none, on 555-1234 marks it; Dial offers Local and Access Code 1 (2 and 3 have none); COM1 gets `ATDT9,5551234;` CR, `ATDT5551234;` CR, `ATZ` CR |
| `scis` | Window notifications and Scissors:  NTFPRB asks for 40h-51h; the menu has Scissors X, Scissors has Copy C, Cut U and Paste without a key; Copy marks from the top left (B, E) and NTFPRB reads 4Eh with its window's handle, row 2, column 2, 2 rows, 3 columns from its own mailbox, Cut 4Dh with 1 row, 2 columns; 50h and 51h for the DESQ key and its end |
| `paste` | Scissors Paste (NTFPRB C in a second window):  a DOS window's Scissors has no key; after a Mark of HELLO, Paste P, the block moved down and right, Enter sends `4Fh` (14 bytes, row 1, column 1, 1 x 5) and `READ` of its window gives HELLO (5 bytes), as DESQview 2.80; `scis`:  Copy's 2 x 3 window gives its first row (cro, 3 bytes, as DESQview's), Cut's 1 x 2 two bytes |
| `ntf` | Notifications (NTFPRB in window 1, a second DOS window):  Help for Program F1 and Quit without its key in the menu; Move right/down sends 40h/41h (7 bytes, the row one more), Scroll right, right, left, down, up sends 44h 01, 01, FF and 45h 01, FF (9 bytes:  the event, the handle, 00 00 00, the step; the view stays); Resize narrower/lower 42h/43h (a row less); F1 sends 48h (8 bytes), MaxView's help not shown; the second window in front 4Bh, back 4Ah, Hide 47h; Close Yes 46h (8 bytes), the window stays; after NTFPRB ends Quit has Q again |
| `alw` | Allow / disallow (ALWPRB, manager stream `20h`-`28h`, `2Eh`, `31h`-`33h`):  Open, Switch, Close, Zoom, Mark, Quit and Rearrange's Move, Resize, Scroll, Position, Freeze, Hide, Put Aside have no key, O and C do nothing; after the program ends all are back; `30h`:  Alt opens no menu |
| `vntf` | Video notification (NTFPRB, MAXTEXT):  Video Options 80 x 25, then 80 x 50 sends `4Ch 03h` (2 bytes) three times each |
| `swap` | Swapping (4 MB of RAM, `SWAPMEM` another size):  window 1 cd DOS, put aside; six more windows open, window 1 swapped out (`MVSWAP01.TMP`); window 7 put aside, Switch to window 1:  7 out, 1 back, its directory still C:\DOS; Quit ends all, no swap file left.  Needs Open 386MAX 9.00-beta7 (3d8b448) or later (the PDT alias fix:  before it, with 4 MB every window shared the root's pages) |
| `noswap` | the `swap` steps with window 1's program saying Can be swapped out N (catalogue profile:  DVP 2.x, flags1 and flags4 0):  window 1 put aside is not swapped out, the 7th window is refused for want of memory |
| `catalog` | Open Window's Add (F2), Change (F3), Delete (F4):  an empty form refused with its reason; a new program B typed in and kept, listed, started from Open Window (it counts); Change shows its values, the title changed; Delete asks, then A is gone; MAXVIEW.CFG holds only the changed program; Swap out N, Close on exit N, Close Window N, In background Y, Share CPU Y shown again by Change and kept as DESQview 2.80 writes them (16Fh A0h, 184h 30h, 18Bh 0Fh, 17Ch 0) |
| `help` | MaxView's help:  the menu has Help F1; F1 lists the topics by key; R shows the Rearrange page whole in its box with the hint row; Esc goes back to the topics, Esc again to the main menu |
| `mark` | Mark and Transfer between two DOS windows:  the menu has Mark M and Transfer T; Mark shows Begin, More, End only after a begin, the Auto Dialer below; two lines marked (shown reversed), "2 line(s) marked"; Transfer + Enter types both (53 characters, more than the key buffer holds) into the other window, where they run (C:\XF.TXT, C:\X2.TXT); Transfer N types 4711 |
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
| `pntf` | Pointer notification (NTFPRB P under MVRUN, CuteMouse):  each click gives the pointer's message (6 bytes), then `49h` and the pointer's handle (5 bytes) in the mailbox |
| `revive` | Pointers in MAXVIEW's windows and Revive Mouse (CuteMouse, NTFPRB P in DosOne):  a click at screen cell 6, 10 gives row 4, column 8 (the window's contents from 2, 2); Tune's M says Mouse revived, a click afterwards gives the same message |
| `wobj` | a window object as DESQview 2.80 (WOBPRB in a DV window gives the same frame, title and contents):  a WRITE of stream E6h 4,12 to the own window gives the handle, then EFh "probe", C2h 14,30, "hello" in E2h 1Fh, "A" "B" "C" "D" in 00h/1Fh/70h/7Fh, D4h, E4h:  the frame and title after DA in Open 386MAX's 1Fh (DV:  its window's colours), physical colours as they are, blanks 17h; C2h 17,50 + E4h moves it (the old place restored), FREE takes it away |
| `panel` | panel objects as DESQview 2.80 (PANPRB in a DV window gives the same results with the same library):  `NEW 10h`, `OPEN` of `MVTEST.PLB` (tests/panels/mkplb.py), `SIZEOF` 5, `READ` of TEXT (the own window and keyboard 0, its text in the window), WIN and FORM (`E6h`:  0, 0 and the new window's handle; the windows shown), WRAP (the own window made a window object by `C5h`; colours only over a full row keep the next row's first character), NOPE (status 14h), `CLOSE`, `FREE` |
| `menu` | demos/MENU as under DESQview 2.80 (the same program in a DV window gives the same screen bytes and records):  NEW 08h window "colours" 4x12, a keyboard object opened to it in field mode, BDh, E5h 18h and a field table of 4 select fields + Esc, moved to 9,33, shown, on top:  a double frame in Open 386MAX's 1Fh, "red" pointed at in 70h, the others 07h (DV shows them through its window colours); Down points at "green", Enter gives the record 02 0100 'Y' and "item 2 chosen" (at the line's start), "green" stays pointed at; B gives 03, Q 04 and the end |
| `demos` | demos/MOUSE then demos/HELLO in one task (COMMAND /C, CuteMouse; SKIP without it), as under DESQview 2.80:  ERASE of the own window puts MOUSE's text on top, the pointer WRITE gives a move mark at row 5 column 30, the left click a mark where it was, the right click ends; HELLO's line through the API's WRITE |
| `countdn` | demos/COUNTDN as under DESQview 2.80:  the window "countdown" with an empty seconds field, "3" typed fills it from the right, Enter starts the timer:  "Left: 002" after 1.5 s, 000 and "time is up" in the own window after 6.5 s; Esc ends |
| `serve` | demos/SERVE (task 1) and ASK (task 2, foreground) as under DESQview 2.80 in two windows:  ASK finds SERVE's named mailbox, two lines come back in capitals; SERVE (Ctrl+Alt+1) counts 00002 requests and its clock (timer READ) moves on |
| `subtask` | tests/SUBPRB as under DESQview 2.80:  NEW 08h with an entry point gives a handle (4 bytes on the stack); the subtask (DS = ES = SS its stack, DX:CX its task's handle) writes to its task's window and sends "hi", status 7, to its task's mailbox (BL=02h); it runs alongside; FREE of its handle ends it |
| `launch` | demos/LAUNCH as under DESQview 2.80:  H starts HELLO through `APP_START` with a DVP made in memory (a task of its own, started by task 1, in front); it ends (close on exit) and LAUNCH is in front again with the new task's handle in its window; W starts WORMS in front (N makes a worm), Q in WORMS brings LAUNCH back; LAUNCH ends with exit code 0 |
| `ownwin` | tests/OWNPRB as under DESQview 2.80:  its own window sized to 5x20 (`C3h`, `C5h`) and moved to 6,30 (`C2h`) becomes a window there:  its text at row 6, column 30, a double frame with corners at 5,29 / 5,50 / 11,29 / 11,50, titled "1══OWNPRB" (its number, two double lines, the program), blanks in the screen's colour (07h); sized again (8x40, `C2h` 3,10) it is a window of that size there, "second" at its 0,0 over the old contents ("secondndow"), the old frame gone |
| `subown` | tests/SOWPRB as under DESQview 2.80:  a subtask sizes its own window to 4x20 (`C3h`, `C5h`) and moves it to 15,40 (`C2h`):  "sub own" at row 15, column 40, a single frame with corners at 14,39 / 14,60 / 19,39 / 19,60, untitled, the frame in Open 386MAX's 1Fh, the contents 17h (as DV shows them); the task's "main made" stays in its window; FREE ends the subtask, SOWPRB exit code 0 |
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
program (on QEMM 97 it can:  GFXPROBE behind a second window is held there
the whole time and draws again when back, as in MaxView); and an Open 386MAX bug (IRQs on vector 68h swallowed in PL0,
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
