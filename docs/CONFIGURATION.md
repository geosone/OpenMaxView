# Configuration reference

Text files accept blank lines and comment lines beginning with `#`. Keep DOS
paths within the limits of the target DOS environment. Interactive writers
use `.NEW` and `.BAK` files so an update does not overwrite the only copy.

## MAXVIEW.CFG

The version-2 program catalogue contains at most 24 records. Every record
starts with the six fields used by version 1:

```text
hotkey|title|command|working-directory|min-kb|max-kb
```

The hotkey is one unique printable letter. Title and command are required.
The working directory may be empty. Minimum and maximum memory are decimal
kilobytes, with the minimum not exceeding the maximum. In milestone 0.8 the
memory values are displayed and advisory; the future MaxView scheduler will
enforce them through the available QPI context backend.

Example:

```text
E|Text editor|EDIT.COM C:\AUTOEXEC.BAT|C:\|192|640
```

Use `MAXVAPP /CHECK` after hand editing.

An imported DVP appends a versioned process profile:

```text
|profile-version|source-version|system-kb|script-bytes|idle-polls|
max-ems-kb|extra-system|rows|columns|text-pages|graphics-pages|
serial-ports|protection|flags1|flags2|flags3|flags4[|start-row|start-col|
start-rows|start-cols|close-on-exit]
```

The last four (DVP `0EBh`, `0ECh`, `180h`, `181h`, measured with DESQview
2.80's Change a Program) are the window's contents at the start:  row,
column, height and width.  They are written only when one is not 0; with a
height or width of 0 MAXVIEW places the window itself.  MAXVIEW opens the
window there (kept inside the screen, its frame around it) and Resize stops
at `rows` and `columns` (Maximum Height and Width).  `close-on-exit` is
DVP byte `17Ch`:  1 set, 2 clear, 0 not known (older records); with
`flags4` bit 7 clear (not blank) and 2, Close on exit N, the program runs
under `COMSPEC /K`:  its window stays with a DOS prompt, as DESQview's.

The display above wraps the definition for readability; one catalogue record
always occupies one physical line.

These fields retain the decoded scheduler, video, EMS, serial and protection
requirements even before every capability can be enforced. On launch they are
classified into a task-bound resource contract. F2 shows its requested and
pending hexadecimal masks. The bits are:

| Bit | Resource class |
|---:|---|
| `001h` | Conventional-memory limits |
| `002h` | System-memory reservation |
| `004h` | Script buffer |
| `008h` | Idle detection |
| `010h` | EMS limit |
| `020h` | Text-video geometry/pages |
| `040h` | Graphics pages |
| `080h` | Serial ports |
| `100h` | Protection mode |
| `200h` | Raw profile flags awaiting field-level interpretation |

Milestone 0.8 reports all requested classes as pending; it does not claim
enforcement from successful parsing alone. Profile version 1 is currently
defined. Six-field version-1 records remain valid and are saved unchanged
unless a profile is attached. Unknown profile versions and values outside
their byte-sized DVP ranges are rejected rather than guessed.

## MAXVSET.INI

The version-1 settings file contains `KEY=YES` or `KEY=NO` records, the
text records of Mark's Auto Dialer, and the options of DESQview's Advanced
Setup that MaxView has (`MAXVSET`'s pages Auto Dialer, Colors, Keyboard, Mouse,
Performance, Swapping, Video and Window Positions):

| Key | Default | Effect |
|---|---:|---|
| `AUTO_TSR` | YES | Load `MAXVTSR.COM` when the API is absent. |
| `AUTO_ANSI` | YES | Load `MAXVANSI.COM` when its service is absent. |
| `CONFIRM_EXIT` | YES | Ask before leaving the launcher. |
| `RELOAD_CATALOG` | YES | Re-read the catalogue after a child exits. |
| `SHOW_MEMORY` | YES | Show catalogue memory limits. |
| `HOTKEY_LAUNCH` | YES | Enable direct red-letter launch keys. |
| `QUICK_HELP` | YES | Display the quick-help pane. |
| `MODEM_PORT` | 1 | The modem's COM port (1-4) for the Auto Dialer. |
| `DIAL` | ATDT | The command before a number (up to 15 characters; `ATDP` for pulse dialling). |
| `HANGUP` | ATZ | The command Talk sends:  the modem off the line. |
| `ACCESS1`..`ACCESS3` | (none) | Access codes put before a number (Dial's Access Code 1-3), up to 23 characters, for example `9,`. |
| `DIAL_BAUD` | 0 | The modem port's speed before dialling:  0 left as is, 1-6 300, 600, 1200, 2400, 4800, 9600 baud (8 data bits, no parity, 1 stop bit; INT 14h 00h). |
| `FOREGROUND` | 6 | Clock ticks of the window in front (1-15) when MAXVIEW starts. |
| `BACKGROUND` | 2 | Clock ticks of each other window (1-15). |
| `SWAPPING` | YES | NO:  windows are never swapped out (Tune Performance's system Allow swapping out N at start). |
| `SWAP_DIR` | (none) | The directory of the `MVSWAPnn.TMP` files; blank:  the current one. |
| `LEARN` | YES | NO:  Shift+Alt does not open Learn (scripts already learned still play). |
| `MOUSE` | YES | NO:  DESQview programs' pointer objects and select fields get no mouse (MAXVTSR). |
| `LEFT_HANDED` | NO | YES:  for them the buttons are swapped (the right one is the left). Programs using INT 33h themselves are not changed. |
| `BLANK` | 0 | Minutes (0-99) without a key or a mouse move until MAXVIEW turns the display off (its contents kept); a key or the mouse turns it on, the key goes on to the program (as DESQview's, measured). 0:  never. |
| `SYNC_VIDEO` | NO | YES:  MAXVIEW writes only the changed cells of its windows, each in a horizontal retrace (CGA:  no snow). |
| `COLORS` | NO | YES:  the program in front (a text mode, colour) shows its black and grey as its window's colours, through the VGA palette (as DESQview shows a window's colours); windows 5-9 take those of 1-4 again. Programs and MAXVIEW's own windows otherwise show their own colours. |
| `COLOR1`..`COLOR4` | 1,3 1,6 7,4 1,2 | Window 1-4's text (0-15, 8-15 bright) and background (0-7) colours for `COLORS`; the defaults are DESQview 2.80's (blue on cyan, blue on brown, grey on red, blue on green). |
| `WINDOW1`..`WINDOW9` | DESQview's | Where window 1-9 opens when its program has no starting window:  row, column, height, width of its contents (frame around them), for example `WINDOW1=1,1,10,78`.  The defaults are DESQview 2.80's (measured). |

Unknown, duplicate or malformed records are validation errors rather than
silently accepted future settings. Use `MAXVSET /CHECK` after hand editing.

## MAXVAUTO.DAT

The version-1 detection database contains at most 48 rules:

```text
filename|title|command|min-kb|max-kb
```

`filename` is an 8.3 DOS basename, not a path or wildcard. Detection means
only that a file with that name exists. The detector neither examines file
contents nor executes it. Commands already represented in the catalogue are
not added again, and a free hotkey is selected without colliding with existing
records.

Example:

```text
EDIT.COM|DOS text editor|EDIT.COM|192|640
```

Use `MAXVAUTO /CHECK` after hand editing. Because Setup preserves this file,
local free-software and site-specific rules survive an upgrade.

## DESQview .DVP import

`.DVP` is a binary compatibility input, not an Open MaxView configuration file
to edit. `MAXVDVP` validates the checksum over the common PIF/DVP base and
bounded title, pathname, directory and parameter fields before conversion. It
maps these values plus the menu key and conventional-memory limits into a new
catalogue record. The source file is opened read-only.

DESQview-specific script-buffer, idle-poll, text/graphics-page, EMS,
serial-port and protection fields are decoded for `/LIST` and retained in the
catalogue's version-1 process profile during import. The foreground launcher
builds and binds their resource contract but does not yet enforce its pending
classes; each class becomes active only with its matching 1.x scheduler or VM
capability. `MAXVAPP` preserves the profile while editing the basic launch
fields. The serial fields and safe migration rules are specified in
[Serial and BBS design guide](SERIAL_BBS.md).
