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
| Open Window:  the program menu by two-letter keys, then Add / Delete / Change a Program | Open Window lists the catalogue's programs by their (one-letter) keys; Add / Delete / Change a Program shown, not yet available | Partial |
| Switch Windows:  the windows by number | Switch Windows lists the windows by number (1-9, A, ...); also Ctrl+Alt+1..9 | As DV |
| Close Window:  "Are you sure?" Yes / No | Close Window:  "Are you sure?" Yes / No | As DV |
| Zoom | Zoom:  full screen, Alt returns | As DV |
| Help (F1):  a help index (commands, programs, companions) | none | Missing (own help text needed:  DESQview's is not copied) |
| Quit DESQview:  "Are you sure?" Yes / No | Quit MaxView:  "Are you sure?" Yes / No, closes all programs | As DV |

### Rearrange

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Move, Resize (with the arrows; Move / Resize / Scroll switch between each other) | Rearrange:  Move, Resize with the arrows | Partial (DV's Move / Resize / Scroll box not shown) |
| Scroll (the window over the program's screen) | Rearrange:  Scroll (S) with the arrows; the view stays there (otherwise it follows the cursor) | Covered |
| Position 1-9 (fixed places) | Rearrange:  1-9, the same places (halves, middle, quarters) | Covered |
| Freeze, Hide, Put Aside | Rearrange:  Freeze (F, again:  Unfreeze) runs the window only while it has the keys; Hide (H) takes it off the screen, running; Put Aside (P) off the screen and held; Switch Windows brings either back | Covered (Put Aside holds the program in memory; DV swaps it out) |
| Change Colors (text and background colour of the window) | Rearrange:  Change Colors (C), Left/Right the text, Up/Down the background colour:  the program's black and grey shown in them (otherwise its own colours), live; Esc back | Covered |
| Video Options (VGA 25 / 30 / 50 / 60 rows) | none | Missing |
| Tune Performance (this window:  share CPU and EGA in front, run in background, allow swapping; system:  foreground / background ticks, swapping; Revive Mouse) | MAXVIEW's Tune Performance:  Run in background, Share CPU in front per window, Foreground / Background ticks (6:2 at start); MVRUN /T the slices | Partial (Share EGA, swapping and Revive Mouse:  not offered; MaxView does not swap) |

### Mark, Transfer, Scissors, Auto Dialer

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Mark (Mark Begin, Mark More, Mark End) and Transfer:  copy screen text from one window into another's keyboard | none | Missing |
| Scissors | none (not yet measured:  inactive in a plain DV setup) | Missing |
| Auto Dialer (Mark Phone #, Dial, Talk) | none | Missing |

### Programs and companions

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Add a Program, Delete a Program, Change a Program (all DVP options) | `MAXVAPP` (separate full-screen editor), `MAXVDVP` imports DVP files, `MAXVAUTO` finds programs | Partial:  not from the menu, not every option takes effect |
| DOS Services | `MAXVFILE` | Partial |
| Memory Status | `MAXVMEM` | Partial |
| Learn (keyboard macros and scripts) | none | Missing |
| Setup (DVSETUP) | `MAXVSET` | Partial |

### Multitasking and programs

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Concurrent DOS programs, each with its own memory, DOS state, screen, keys, video mode, text pages, EMS mapping, current directory | The multitasking core on Open 386MAX (QPI), up to 15 programs in MAXVIEW | As DV |
| Windows on one screen, numbered, titled | The windows view, in Open 386MAX's colours | Covered (titles, own-window geometry) |
| Background serial programs (BBS nodes):  each IRQ to the window that hooked it last | The core | As DV (`nodes`, `samecom`) |
| Graphics programs in the background | Held in the background | Partial |
| Swapping windows out to disk or EMS | none | Missing |
| Program protection levels, writes-directly-to-screen virtualization | Text pages private per task; CRTC/DAC writes of background tasks trapped | Partial |

### The DESQview API

The API calls DESQview-aware programs use (scheduling, critical sections,
tasks, subtasks, mailboxes, timers, windows, window streams, query streams,
keyboard objects, field mode, pointers, object queues, `APP_START`) are
implemented and compared with DESQview 2.80 call by call; the Quarterdeck
API examples run as under DESQview. [The API reference](API.md) lists
every call and its state. Panels and some rarely used objects are still
missing.

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
