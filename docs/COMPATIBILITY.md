# Compatibility and limitations

## DESQview 2.80 functions

The goal is a complete replacement of DESQview 2.80, not only what a BBS
needs. This list follows DESQview 2.80's own menus (measured on Open 386MAX
with the local scripts `build/dvdbg/dmenu.sh`) and states what Open MaxView
does today. "As DV" means compared with DESQview 2.80 in a test.

### Main menu (DESQview key, Alt)

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| The menu itself (Open Window O, Switch Windows S, Close Window C, Rearrange R, Zoom Z, Mark M, Transfer, Scissors, Help F1, Quit DESQview Q) | Alt shows MaxView's menu over the windows with the same items and keys, in the Open 386MAX look; items not yet available are dark grey | Covered; its items as below |
| Open Window:  the program menu by two-letter keys, then Add / Delete / Change a Program | Open Window lists the catalogue's programs by their (one-letter) keys; Add a Program (F2), Change a Program (F3), Delete a Program (F4) in the menu | Covered (one-letter keys) |
| Switch Windows:  the windows by number | Switch Windows lists the windows by number (1-9, A, ...); also Ctrl+Alt+1..9 | As DV |
| Close Window:  "Are you sure?" Yes / No | Close Window:  "Are you sure?" Yes / No | As DV |
| Zoom | Zoom:  full screen, Alt returns | As DV |
| Help (F1):  a help index (commands, programs, companions) | Help (F1, from every menu):  MaxView's own pages by topic (Keys and Menus, Windows, Rearrange, Mark and Transfer, Video, About MaxView) in a box, Esc back to the topics | Covered (own text; DESQview's is not copied) |
| Quit DESQview:  "Are you sure?" Yes / No | Quit MaxView:  "Are you sure?" Yes / No, closes all programs | As DV |

### Rearrange

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Move, Resize (with the arrows; Move / Resize / Scroll switch between each other) | Rearrange:  Move, Resize, Scroll with the arrows, a box with Move M, Resize R, Scroll S (the bar on the one going on) and Done Enter; M, R, S switch between them | Covered |
| Scroll (the window over the program's screen) | Rearrange:  Scroll (S) with the arrows; the view stays there (otherwise it follows the cursor) | Covered |
| Position 1-9 (fixed places) | Rearrange:  1-9, the same places (halves, middle, quarters) | Covered |
| Freeze, Hide, Put Aside | Rearrange:  Freeze (F, again:  Unfreeze) runs the window only while it has the keys; Hide (H) takes it off the screen, running; Put Aside (P) off the screen and held; Switch Windows brings either back | Covered (a put aside window is swapped out when memory runs out) |
| Change Colors (text and background colour of the window) | Rearrange:  Change Colors (C), Left/Right the text, Up/Down the background colour:  the program's black and grey shown in them (otherwise its own colours), live; Esc back | Covered |
| Video Options (VGA 25 / 30 / 50 / 60 rows) | Rearrange:  Video Options (V), 80 x 25 / 43 / 50 / 60 and 132 x 25 / 43 / 50 / 60 as Open 386MAX's MAXTEXT offers them (132 columns through the card's VBE text modes); the windows view in that geometry, a program's own screen 80x25, the launcher 80x25 | Covered with MAXTEXT loaded (without it:  80x25 only), starting in the higher mode MAXTEXT can set; more than DV (132 columns) |
| Tune Performance (this window:  share CPU and EGA in front, run in background, allow swapping; system:  foreground / background ticks, swapping; Revive Mouse) | MAXVIEW's Tune Performance:  Revive Mouse (INT 33h 21h, else 00h); Run in background, Share CPU in front, Share EGA (from the DVP:  `18Bh` bit 0, measured), Allow swapping out per window; Foreground / Background ticks (6:2 at start), Allow swapping out for the system; MVRUN /T the slices | Partial (Share EGA shown only:  MaxView does not share the EGA registers; MaxView swaps put aside windows by itself, see below) |

### Mark, Transfer, Scissors, Auto Dialer

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Mark (Mark Begin, Mark More, Mark End) and Transfer:  copy screen text from one window into another's keyboard | Mark (M):  Begin B, More M, End E, the arrows move the mark, the text row by row from the begin to the mark (as DV 2.80, measured); Transfer (T):  the first line T, the first number N, or every line followed by any other key | As DV; Transfer waits for room in the key buffer (DV 2.80 loses keys beyond its 15 places, measured); "keys to begin each line" not offered |
| Scissors (Copy C, Cut U, Paste:  only for programs written for DESQview that support them through its API; inactive otherwise, measured) | Scissors X when the front window's program asked for Cut, Copy or Paste (manager stream 4Dh-4Fh); Copy C / Cut U:  Mark Begin B from the top left, Mark End E; the program gets DESQview's message (4Eh / 4Dh, its window's handle, row, column, 0, a DWORD, rows, columns; measured) in its own mailbox | Partial:  Paste as DESQview 2.80 (measured):  after a Mark, for a program asking for `4Fh`, the marked text as a block the arrows place, Enter sends `4Fh` with a window holding it; Copy and Cut give a window holding the area (`READ` of these gives the row of its cursor, as DESQview's); how DESQview takes a program's Copy into Paste is not known (writing into Copy's window does not) |
| Window notifications (a DESQview program asks for them, manager stream 40h-51h; measured):  move, resize, scroll each step, Help for Program (F1), Close (the program closes itself; Quit without its key meanwhile), Hide, front and back, the DESQ key and its end | the same messages into the program's own mailbox; its notifications go when it ends | Supported |
| Allow / disallow menu functions (manager stream `00h`-`13h`, `20h`-`33h`; measured) | MAXVIEW's menus leave the disallowed functions without a key, the DESQ key opens no menu with `30h` | Supported |
| Auto Dialer (Mark Phone #, Dial with Local and Access Code 1-3, Talk):  measured, Dial sends `ATDT`, the number and `;` + CR to COM1, Talk `ATZ` + CR | Mark Phone # P takes the number under the mark's cursor from the window; Dial D (Local L, Access Code 1-3) and Talk T send the commands of MAXVSET.INI (MODEM_PORT, DIAL, HANGUP, ACCESS1-3; by default COM1, ATDT, ATZ) by INT 14h | Covered |

### Programs and companions

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Add a Program, Delete a Program, Change a Program (all DVP options) | From Open Window:  a form with key, title, program, directory, memory and Can be swapped out (Swap:  Y, N or blank), kept in MAXVIEW.CFG (a changed program keeps its other settings); all options:  `MAXVAPP` (separate full-screen editor), `MAXVDVP` imports DVP files, `MAXVAUTO` finds programs | Partial:  the menu's form has the main settings, not every DVP option takes effect |
| DOS Services | `MAXVFILE` | Partial |
| Memory Status | `MAXVMEM` (M in the catalogue), in a window:  DESQview 2.80's rows (measured):  Common Memory (MAXVTSR's, bytes), Conventional Memory (the window's own DOS memory), Expanded Memory, each total, available, largest available; also XMS and what new windows can still get (Open 386MAX's pool, which EMS shares) | Covered |
| Learn (keyboard macros and scripts):  Shift+Alt, Start Script =, Finish -, Cancel C, pauses, Display D, Save S, Load L (measured) | Learn on Shift+Alt:  Start Script (the key, a name, then the keys typed into the window), Finish, Cancel, Fixed-Size Pause (played:  waits for as many keys of the user's as were typed while learning), Variable Pause (played:  the user's keys until Enter, which is taken), Time Delay (seconds), Display Scripts, Save / Load Scripts (MAXVIEW.SCR, loaded at start); the script's key in a window types its keys | Partial:  scripts are MaxView's, not per program |
| Setup (DVSETUP) | `MAXVSET` | Partial |

### Multitasking and programs

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Concurrent DOS programs, each with its own memory, DOS state, screen, keys, video mode, text pages, EMS mapping, current directory | The multitasking core on Open 386MAX (QPI), up to 15 programs in MAXVIEW | As DV |
| Windows on one screen, numbered, titled | The windows view, in Open 386MAX's colours | Covered (titles, own-window geometry) |
| Background serial programs (BBS nodes):  each IRQ to the window that hooked it last | The core | As DV (`nodes`, `samecom`) |
| Graphics programs in the background | A program in VGA or VESA graphics held in the background, its picture not kept (it draws again when back); text and CGA programs run on | As DV (DESQview 2.80 on QEMM 97, measured with GFXPROBE behind a second window:  held for the whole time, a blank screen when back, one redraw; on Open 386MAX DESQview could not open a second window over it) |
| Swapping windows out to disk or EMS; Can be swapped out (Y, N, blank) per program | MAXVIEW:  when a window cannot open for want of memory, a put aside window (no subtask, no hardware interrupt of its own) goes page by page to `MVSWAPnn.TMP` in the current directory and its memory is freed; switched to again it comes back (another put aside window out if need be); Quit ends the swapped out ones too and removes the files; a program whose DVP says Can be swapped out N (DESQview 2.80 measured:  18Bh bit 6 clear and 16Fh bit 0 clear) is never swapped out | Partial (disk only, no EMS:  under Open 386MAX EMS comes from the same memory as the windows' pages, so it would gain nothing; only put aside windows; Tune Performance's Allow swapping out (window, system) keeps them in memory; with little memory (4 MB) Open 386MAX 9.00-beta7 or later) |
| Program protection levels, writes-directly-to-screen virtualization | Text pages private per task; CRTC/DAC writes of background tasks trapped | Partial |

### The DESQview API

The API calls DESQview-aware programs use (scheduling, critical sections,
tasks, subtasks, mailboxes, timers, windows, window streams, query streams,
keyboard objects, field mode, pointers, object queues, panels,
`APP_START`) are implemented and compared with DESQview 2.80 call by call;
the Quarterdeck API examples run as under DESQview. [The API
reference](API.md) lists every call and its state. Some rarely used
objects are still missing.

## Meaning of the version lines

The 0.x milestones are usable construction stages and must state their limits.
The 1.x line is the DESQview 2.8 reimplementation line: compatible task
descriptions and APIs, multiple isolated DOS tasks, scheduling, window/task
switching, and the expected local tools. A 1.0 release requires conformance
tests and real-application testing, not merely a similar menu.

The 2.x line may add secure remote viewing and control. It must build on the
completed multi-context design and must not delay or blur the local 1.x
compatibility target.

## Non-goals

Open MaxView does not reimplement QEMM. Open 386MAX is the dependency for
memory management and the planned V86 backend. It also does not redistribute
DESQview binaries, copy its artwork or manual text, accept serial numbers, or
claim undocumented behaviour without a clean-room test.
