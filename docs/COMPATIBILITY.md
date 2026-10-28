# Compatibility and limitations

## DESQview 2.80 functions

The goal is a complete replacement of DESQview 2.80, not only what a BBS
needs. This list follows DESQview 2.80's own menus (measured on Open 386MAX
with the local scripts `build/dvdbg/dmenu.sh`) and states what Open MaxView
does today. "As DV" means compared with DESQview 2.80 in a test.

### Main menu (DESQview key, Alt)

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| The menu itself (Open Window O, Switch Windows S, Close Window C, Rearrange R, Zoom Z, Mark M, Transfer, Scissors, Help F1, Quit DESQview Q) | Alt opens MAXVIEW's own windows view (Tab, Enter, Z, M, S, C, O, Q) | Missing:  the DESQview menu |
| Open Window:  the program menu by two-letter keys, then Add / Delete / Change a Program | The launcher's catalogue with hotkeys; programs run as tasks | Partial |
| Switch Windows:  the windows by number | Tab in the windows view, Ctrl+Alt+1..9, the task list (T) | Partial |
| Close Window:  "Are you sure?" Yes / No | C in the windows view and the task list | Partial |
| Zoom | Z in the windows view | Partial |
| Help (F1):  a help index (commands, programs, companions) | none | Missing (own help text needed:  DESQview's is not copied) |
| Quit DESQview:  "Are you sure?" Yes / No | Q in the launcher (confirmation per `MAXVSET`) | Partial |

### Rearrange

| DESQview 2.80 | Open MaxView today | Status |
|---|---|---|
| Move, Resize (with the arrows; Move / Resize / Scroll switch between each other) | M, S in the windows view | Partial |
| Scroll (the window over the program's screen) | The window follows the cursor | Missing |
| Position 1-9 (fixed places) | none | Missing |
| Freeze, Hide, Put Aside | none | Missing |
| Change Colors (text and background colour of the window) | DESQview's colours by window number, fixed | Missing:  the choice |
| Video Options (VGA 25 / 30 / 50 / 60 rows) | none | Missing |
| Tune Performance (this window:  share CPU and EGA in front, run in background, allow swapping; system:  foreground / background ticks, swapping; Revive Mouse) | MVRUN /T foreground and background slices (3:1 as DESQview's 6:2); every task runs in the background | Partial |

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
| Windows on one screen, numbered, titled, DESQview's colours | The windows view | As DV (titles, colours, own-window geometry) |
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
