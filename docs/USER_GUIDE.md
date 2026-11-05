# Open MaxView user guide

## What Open MaxView is

Open MaxView is a clean-room DOS reimplementation of the DESQview 2.8 user
environment. It uses Open 386MAX as its future protected-mode and virtual
machine dependency instead of duplicating a memory manager.

Milestone 0.8 is useful as a consistent program launcher and DOS utility
suite. It runs one child program at a time. Concurrent virtual DOS machines,
true overlapping task windows and complete DESQview APIs are 1.x work still in
progress; see [Compatibility](COMPATIBILITY.md).

## Install

Build or obtain the complete `OpenMaxView` package directory, copy all of its
files to DOS media, change to that directory and run:

```text
SETUP
```

The default destination is `C:\MAXVIEW`. Setup checks that the required files
exist before changing the destination. On an upgrade it keeps the existing
`MAXVIEW.CFG`, `MAXVSET.INI` and `MAXVAUTO.DAT`.

An unattended installation is available for images and test systems:

```text
SETUP /S /D:C:\MAXVIEW
```

After installation, add `C:\MAXVIEW` to `PATH` if desired, change to the
directory and run `MAXVIEW`.

The complete documentation is installed as DOS-readable text files. Start at
`QUICK.TXT`, then use the index in `DOCS.TXT`; short 8.3 names such as
`USERGUID.TXT`, `TOOLS.TXT`, `CONFIG.TXT` and `TROUBLE.TXT` identify the
individual manuals.

## First start

By default the launcher starts `MAXVTSR.COM` and `MAXVANSI.COM` automatically.
The former supplies the current DESQview-compatible resident calls. The
latter interprets common ANSI sequences written through DOS `INT 29h`.

Use the cursor keys to select a catalogue entry and Enter to launch it. If
`HOTKEY_LAUNCH` is enabled, the red letter beside an entry launches it
directly. The launcher returns after the DOS child exits. Esc requests exit;
`CONFIRM_EXIT` controls whether confirmation is required.

### Several programs at once

On Open 386MAX (or QEMM) the launcher runs each program as a task of its
own, with its own conventional memory, screen and keyboard, while the
others go on in the background. A started program gets the full screen.

* **Alt** pressed and released alone brings up MaxView's menu over the
  windows (below), as DESQview's key does; **Ctrl+Alt+0** does the same. Once all
  programs have ended, the launcher comes back.
* **Ctrl+Alt+1** to **Ctrl+Alt+7** switch directly to task 1 to 7.
* **T** in the launcher lists the running programs: Enter switches to one,
  **C** closes it (DOS ends it as if it had exited).
* A program that ends gives the screen back to the launcher, which shows
  its exit code.
* A DOS critical error ("Abort, Retry, ...") of a background program comes
  to the front by itself and must be answered first.
* Leaving the launcher closes all running programs after a confirmation.

Alt brings you to the **windows view**: every running program in a window
of its own, all of them live on one screen, and MaxView's menu at the top
right in the Open 386MAX look; its items cover DESQview 2.80's menus.
Choose an item by its key (the red letter, also shown at the right)
or with the arrows and Enter; Esc goes back one menu, from the main menu
into the front window (Alt returns).

| Key | Menu | Action |
|---|---|---|
| O | Open Window | the catalogue's programs by their keys; Add a Program (F2) opens an empty form, Change a Program (F3) the form of the program picked by its key, Delete a Program (F4) removes the one picked after Yes. The form:  Key, Title, Program (the command line), Directory, Memory (KB, empty:  as much as there is), then the window:  Start window (Height, Width, Row, Column of its contents; empty:  MAXVIEW places it) and Maximum (Height, Width:  Resize stops there; empty:  none), then DESQview's Y/N options, one per row:  Swap out (Can be swapped out:  whether its window may be swapped out when put aside and memory runs out), Close on exit (N:  a DOS prompt stays in the window after the program), Close Window (Allow Close Window), In background (Runs in background:  N holds it while it is behind), Share CPU (Share CPU when foreground:  N gives it the CPU alone in front); Space:  blank, as Y; type into the field, Up/Down or Tab change the field, Backspace deletes, Enter keeps it in MAXVIEW.CFG (a missing key, title or program, or a key in use, is shown in the form), Esc cancels. Its other settings (DVP options):  `MAXVAPP` |
| S | Switch Windows | the windows by number (1-9, A, B, ...):  that one to the front, typing into it |
| C | Close Window | "Are you sure?" Yes (Y) ends the front window's program |
| R | Rearrange | Move (M), Resize (R), Scroll (S):  the front window, or its view over the program's screen, with the arrows; a box shows which, M, R and S switch to the other, Enter ends; Position 1-9:  a fixed place (1, 2 the top and bottom half, 3 the middle, 4, 5 the left and right half, 6-9 the quarters); Freeze (F):  the program runs only while its window has the keys (F again:  Unfreeze); Hide (H):  off the screen, still running; Put Aside (P):  off the screen and stopped; when memory runs out for a new window, a put aside one is swapped out to `MVSWAPnn.TMP` (in the current directory) and comes back when switched to; not one whose program says Can be swapped out N (its DVP, imported with `MAXVDVP`). Switch Windows brings a hidden or put aside window back. Change Colors (C):  Left/Right the text, Up/Down the background colour the window shows its program's black and grey in, Enter keeps, Esc goes back; Tune Performance (T):  Revive Mouse (M:  resets the mouse driver a program left in an odd state); this window's Run in background (B), Share CPU in front (S:  N, the others wait while it has the keys), Share EGA in front (its program's DVP setting, shown only:  MaxView does not share the EGA registers) and Allow swapping out (A:  N keeps it in memory); the system's Foreground and Background ticks (F, K:  1-15) and Allow swapping out (W:  N, no window is swapped out); each key or Enter changes the value. Video Options (V):  with `MAXTEXT.SYS` loaded the windows view starts in the higher mode it can set (132 x 43, 132 x 50, 132 x 25, 80 x 50, 80 x 43, 80 x 60, 132 x 60, the first that works), without it in 80 x 25; Video Options sets the windows view in 80 columns of 25, 43, 50 or 60 rows (1-4) or 132 columns of 25, 43, 50 or 60 rows (5-8), as far as Open 386MAX's `MAXTEXT.SYS` is loaded and offers them (132 columns:  the card's VBE text modes; a mode MAXTEXT cannot set safely is reported on the bottom row); a program's own screen stays 80x25, the launcher 80x25 |
| Z | Zoom | the front window full screen (Alt returns) |
| M | Mark | marks text on the front window's screen:  the arrows move the mark (the window's view follows it), B begins (what was marked before is dropped), M begins more (added to it), E ends; the text from the begin to the mark, row by row, is shown reversed. Enter is done (ending a begun mark), Esc goes back without it. Up to 2048 characters, blanks at line ends dropped |
| T | Transfer | types the marked text into the program of the front window:  T its first line only, N its first number only (a minus before it and decimal points or commas in it kept), any other key (Enter, Tab, an arrow ...) every line, each followed by that key; Esc goes back. The keys wait while the program's key buffer is full, so a long text arrives complete |
| Shift+Alt | Learn | scripts (keyboard macros):  Start Script (=) asks for the key the script is to have (F6, Alt+X, ...) and a name, then the keys typed into the window are learned until Shift+Alt, Finish Script (-) keeps them (Cancel Script C drops them). While learning, Fixed-Size Pause (F, on and off) lets the keys typed meanwhile through and only counts them:  played, the script waits for that many keys of the user's; Variable Pause (V, on and off):  played, the user types until Enter, which ends the pause; Time Delay (T) asks for seconds the script waits; that key then types them again in any window (the key itself is not given to the program). Display Scripts (D) lists them, Save Scripts (S) keeps them in MAXVIEW.SCR, Load Scripts (L) reads it (MAXVIEW also does at start). Up to 16 scripts of 256 keys |
| F1 | Help | MaxView's help from every menu:  the topics (Keys and Menus K, Windows W, Rearrange R, Mark and Transfer M, Video V, About MaxView A), a page in a box (Up/Down, PgUp/PgDn when it is longer than the screen), Enter or Esc back to the topics |
| Q | Quit MaxView | "Are you sure?" Yes (Y) closes all programs and leaves MaxView |

Mark's Auto Dialer:  in Mark, the arrows put the cursor on a phone number in
the window and Mark Phone # (P) takes it (digits, - ( ) + / . , * # and
single blanks between them); Dial (D) then offers Local (L) and the access
codes 1-3 of MAXVSET.INI and sends the modem the dial command, the code, the
number and `;` (the modem goes back to its commands, the call stays on the
line); when it rings, Talk (T) sends the hang-up command and the phone has
the call. The modem's port and commands are in MAXVSET.INI (see
CONFIGURATION.md). Scissors (X) is there for a program written for
DESQview that asks for its Copy and Cut (otherwise it is shown in dark
grey, as in DESQview):  Copy (C) or Cut (U) put the mark's cursor at the
window's top left, B begins the area, the arrows extend it and E ends it;
the program is told the area and does the copying or cutting itself. Paste
(P), for a program that asks for it, takes what Mark marked last:  it shows
as a block at the window's top left, the arrows place it, Enter hands it to
the program (Esc:  back). A message (a program that ended, for example) shows on the
bottom row until the next key.

A window shows the part of its program's 80x25 screen that holds the
cursor; a DESQview program that sizes and places its own window gets a
window of that size and place, showing it. The frame carries the
window's number and title, its blanks drawn as the frame
("1══Tick═counter"), in Open 386MAX's colours (the front window white on
cyan with a double frame, the others white on blue); inside, a window
shows its program's own colours, in a window as full screen. The switch keys come through the BIOS keyboard intercept
(INT 15h function 4Fh), so they do not reach a program that reads the
keyboard hardware itself; Alt and Ctrl+Alt+n work again once it ends or
another task has the keys.

Without QPI the launcher runs one program at a time as before. Up to 15
programs can run at once (DESQview opens 13 or 14 windows with its default
common memory); the task list shows them as DESQview numbers its windows,
1-9 and then A, B, ..., and Ctrl+Alt+n reaches the first nine. The
program in front gets three times the processor time of each one behind
it, as DESQview favours the foreground. Each has its own current drive and directories,
its own EMS page frame mapping, all eight colour text pages and its own
video mode: switching sets the mode of the program brought to the front
(text modes with 25, 43 or 50 rows, CGA, VGA and VESA graphics). A text
program in the background keeps writing to its own screen even while the
display shows graphics or another number of rows. A program in VGA or
VESA graphics is held while it is in the background and, like under
DESQview, finds a blank screen when it is back: most programs redraw it
(a graphics picture is not saved). A monochrome adapter's text memory
(B0000h) is shared.

Press F2 to inspect the selected program's launch fields and retained DVP
process profile. The resource-contract line distinguishes requested feature
classes from those currently enforced; a pending bit is never silently
treated as active. Press `D` for resident API, VCPI and Open 386MAX
diagnostics.

## Add programs

Run `MAXVAPP` to add, change or delete catalogue records manually. A record
contains a unique hotkey, display title, command, optional working directory,
and advisory minimum/maximum memory values. Save with F2 or the highlighted
Save command.

Run `MAXVAUTO` to scan the current directory and every directory on `PATH`.
It compares filenames with `MAXVAUTO.DAT`, excludes commands already present
in the catalogue, and lets the user choose what to add. It never executes a
detected file. Additional directory trees may be supplied with `/R:directory`.

Existing DESQview entries can be migrated with `MAXVDVP old-PIF.DVP`. Review
the decoded title, command, directory and memory limits, then press Enter to
add the entry. The import never modifies the DVP. Use `MAXVDVP /CHECK file.DVP`
before batch migration and keep the generated `MAXVIEW.BAK` until the imported
program has been tested.

## Configure Open MaxView

Run `MAXVSET` to change global preferences. Its pages are Global (the
launcher's own options) and, as in DESQview's Advanced Setup, Auto Dialer
(port, baud rate, dial and hang-up commands, access codes), Keyboard (Learn
on or off), Mouse (on or off, left-handed), Performance (foreground and
background ticks), Swapping (on or off, the swap directory), Video (blank
the screen after minutes without a key or the mouse; synchronized access
for a CGA's snow) and Window Positions (row, column, height and width of
windows 1-9:  where a window opens whose program has no starting window).
G, A, K, M, P, S, V and W or PgUp/PgDn choose a page, Enter changes a field, F2
saves.  MAXVIEW reads them when it starts.  Every displayed setting is used. The exact keys and defaults are documented in
[Configuration](CONFIGURATION.md).

## Networks

Load the network drivers (for example Novell's LSL, the card's ODI driver,
IPXODI and NETBIOS) before MaxView and MAXVTSR.  MAXVTSR then gives every
program IPX and NETBIOS through itself:  a program in a window that is not in
front keeps receiving, and its event service or POST routine runs in its own
window, as with DESQview's "Multitask IPX" and "Multitask NETBIOS".  Up to 8
IPX and 8 NETBIOS commands can be outstanding at a time (buffers up to 576
bytes).  SPX is not yet multitasked; run such programs in front.

Novell Client32 for DOS (NIOS and its NLMs, with its own NETBIOS) works
the same way; it needs Open 386MAX from commit fd4fdac on (newer than
9.00-beta7; no release has it yet).  NIOS is a VCPI program and keeps a
copy of the page table it got when it loaded; older 386MAX versions left
that copy pointing at the memory of the window that was current then, and
the first window started after it crashed.

## Included services

`MAXVFILE` (DOS Services) lists a directory's files with size, date and
time.  Space marks a file, N and U mark and unmark by name (`*.TXT`), O
shows only the marked ones, S changes the sort (name, extension, size,
date).  Append (A), Copy (C, F5), Erase (E, F8), Move (M), Print (P) work on
the marked files, else on the one selected; Rename (R, F6) and Type (T, a
viewer) on the one selected.  `*` shows More:  Change (C), Make (M, F7) and
Remove Directory (R), and Copy Diskette (K), Format Diskette (F), Backup
(B), Restore (S), which run DOS's own DISKCOPY, FORMAT, BACKUP and RESTORE
with the parameters typed.  Enter opens a directory, Backspace the parent,
F9 reads it again, Esc leaves. `MAXVMEM` (Memory Status, M in the catalogue)
shows DESQview's rows, Common, Conventional and Expanded Memory with total,
available and largest available, then XMS and what new windows can still get
(their pages come from Open 386MAX's pool, which EMS shares), VCPI, the
resident API and the Open 386MAX backend. Unknown or unsafe to
measure values are reported as `N/A` rather than guessed.

All full-screen programs share a visual language derived from the GPL-licensed
Open 386MAX QUILIB tools: blue work panes, gray quick help, red hotkeys, cyan
selection, double borders, shadows and bottom command buttons.

## Backups and recovery

Catalogue and settings writers create a `.NEW` file and retain the preceding
file as `.BAK`. If a write is interrupted, inspect the base, `.NEW` and `.BAK`
files before making further edits. Keep a separate copy of the three user
files before a major upgrade:

```text
MAXVIEW.CFG
MAXVSET.INI
MAXVAUTO.DAT
```

Do not replace Open 386MAX with `MAXVMEM`: the similarly named utility is only
a status display and intentionally avoids the historical `MAXMEM` name.

For task-oriented help, read `HELP.TXT`. BBS operators should use
`BBSGUIDE.TXT`. Developers making a DOS program cooperative or task-aware
should start with `PROGDEV.TXT` and keep `API.TXT` beside it.
