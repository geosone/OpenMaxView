# Open MaxView

Open MaxView is a clean-room, GPL-licensed reimplementation of the DOS
multitasking environment DESQview 2.8.  It targets real DOS (8086 for the
user interface, 80386 or newer for the future virtual-machine backend) and is
designed to cooperate with [Open 386MAX](https://github.com/geosone/386MAX)
instead of reimplementing a memory manager.

The repository does **not** contain files from Quarterdeck's DESQview media.
Those files are useful as behavioural reference material, but are neither a
build dependency nor redistributed.

## Current milestone: 0.8

This first runnable milestone provides:

* `MAXVIEW.EXE`, an 80x25 DOS program launcher with a DESQview-style menu;
* `MAXVTSR.COM`, a resident compatibility service which implements the
  documented DESQview presence query, cooperative `PAUSE`, nested critical
  sections, foreground task-state calls, the `HANDLE` object-message stack
  ABI, `LOCATE`, `GETBUF`, `PUSHKEY` and alternate text-video-buffer calls;
* Open 386MAX backend ABI discovery/status validation and a diagnostic screen;
* the Open 386MAX QUILIB look: two-pane layout, palette, shadows, hotkeys and
  bottom command buttons;
* `MAXVAPP.EXE`, a full-screen Add/Change/Delete Program catalogue editor with
  atomic `.NEW`/`.BAK` updates;
* `MAXVMEM.EXE`, a read-only DOS/EMS/XMS/VCPI/MAXVTSR/Open-386MAX status tool;
* `MAXVSET.EXE`, a persistent global settings editor whose options are applied
  by the launcher rather than merely stored;
* `MAXVAUTO.EXE`, an automatic program detector with preview, selective apply,
  recursive scanning and an extensible free-software rule database;
* `MAXVFILE.EXE`, a DOS file-services manager for directory navigation, file
  copying, renaming, directory creation and confirmed deletion;
* `MAXVANSI.COM`, a compact resident ANSI console for foreground DOS output;
* `MAXVDVP.EXE`, a validated DESQview `.DVP` inspector and catalogue importer;
* `SETUP.EXE`, a QUILIB-style interactive and unattended DOS installer;
* a plain-text, versioned program-description format (`MAXVIEW.CFG`) which
  retains advanced DVP process profiles without claiming they are enforced;
* a read-only host tool for inventorying Quarterdeck QIP installation media;
* host-side parser tests and a DOS API probe.

The 0.8 launcher runs one ordinary DOS child at a time.  It is not yet a
drop-in replacement for DESQview's concurrent virtual DOS machines.  That
requires VM creation, per-VM conventional-memory mappings, DOS-state
virtualisation, timer scheduling, and video/I/O trapping in Open 386MAX.  The
boundary and staged implementation plan are documented in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

The UI deliberately follows the GPL-licensed Open 386MAX DOS tools so the two
projects look and behave like one suite.  Open MaxView keeps its small renderer
independent, avoiding a link-time dependency on the much larger QUILIB.

## Documentation

The [documentation index](docs/README.md) links the complete user, tool,
configuration, build, test, compatibility, troubleshooting and development
guides. Released 0.8 behaviour, the 1.x DESQview-compatible target, and 2.x
ideas are documented separately so future plans are never mistaken for
implemented features.

For generated manuals, `make book-html` creates the self-contained developer
handbook, while `make book-pdf` and `make book-epub` create fixed-page and
reflowable user handbooks. The short [`quick-start guide`](docs/QUICKSTART.md)
is also installed as `QUICK.TXT`.

The proposed secure remote-view architecture is recorded as a **2.x-only**
design note in [`docs/REMOTE_VIEW_2X.md`](docs/REMOTE_VIEW_2X.md), including
the requirement to coexist with Microsoft NDIS and Novell ODI clients on the
same network adapter. It does not change the current priority: finish the
local DESQview 2.8 reimplementation.

## Build

Requirements are GNU make, Open Watcom installed in `/opt/watcom`, and the
open-source JWasm/JWlink binaries embedded in Open 386MAX. Override their
locations with `WATCOM=/path/to/watcom MAXROOT=/path/to/386MAX`.

```sh
make
make package
make test
make test-dos
```

The DOS binaries are written to `build/`. `make package` creates the clean
installation-media directory `build/OpenMaxView/` containing:

```text
SETUP.EXE       MAXVIEW.EXE     MAXVTSR.COM
MAXVAPP.EXE     MAXVMEM.EXE     MAXVSET.EXE
MAXVAUTO.EXE    MAXVAUTO.DAT    DVPROBE.EXE
MAXVFILE.EXE    MAXVIEW.CFG     MAXVSET.INI
MAXVANSI.COM    MAXVDVP.EXE
README.TXT      LICENSE.TXT     DOCS.TXT
USERGUID.TXT    TOOLS.TXT       CONFIG.TXT
BUILDING.TXT    TESTING.TXT     COMPAT.TXT
API.TXT         DEVELOP.TXT     ROADMAP.TXT
REMOTE2.TXT
TROUBLE.TXT     ARCHITEC.TXT    HELP.TXT
BBSGUIDE.TXT    PROGDEV.TXT
QUICK.TXT
```

Run `MAXVIEW`.  The launcher installs `MAXVTSR.COM` automatically when it is
available in the current directory or on `PATH`.

## DOS installation

Copy the complete contents of `build/OpenMaxView/` to installation media and
run:

```text
SETUP
```

The default destination is `C:\MAXVIEW`.  Setup checks all required source
files before changing the destination and preserves existing `MAXVIEW.CFG`,
`MAXVSET.INI` and `MAXVAUTO.DAT` files during upgrades.  Automated
installations use:

```text
SETUP /S /D:C:\MAXVIEW
```

The workflow and visual design are adapted from the GPL-licensed Open 386MAX
DOS installer, without its registration, compressed-media, CONFIG.SYS or
memory-manager-specific code.

For the eventual 386 backend, boot DOS with the `9x` branch of Open 386MAX.
Version 0.8 validates its private ABI and reports the root-context status.  It
does not claim or request multiple VM services until Open 386MAX advertises
the corresponding capability.

## Program catalogue

Each non-comment line in `MAXVIEW.CFG` starts with six pipe-separated fields:

```text
hotkey|title|command|working-directory|min-kb|max-kb
```

The working directory may be empty.  Memory values are advisory in 0.8 and
will become enforced limits when the VM backend lands.

DVP imports append the versioned scheduler, video, EMS, serial and protection
profile documented in `CONFIG.TXT`. Six-field records remain valid.

`MAXVAPP` edits this catalogue with the same QUILIB-style interface as the
launcher.  For scripts and diagnostics, `MAXVAPP /CHECK` validates it and
`MAXVAPP /LIST` writes its canonical records to standard output.  Use
`/F:file` to operate on another catalogue.

## MaxView tools

`MAXVAPP.EXE` replaces the essential Add/Change/Delete Program workflow.  It
supports Insert, Enter, Delete, F2 and red-letter keyboard commands and saves
through a temporary file while retaining the previous catalogue as `.BAK`.

`MAXVMEM.EXE` is the first read-only system tool.  Its normal interface uses
the same 386MAX-inspired colours, panes, double borders, shadows and command
buttons as the rest of Open MaxView.  `MAXVMEM /T` emits testable key/value
status for DOS conventional memory, EMS, XMS, the resident API, VCPI and the
Open 386MAX backend.  Values which cannot be measured safely are shown as
`N/A`. With a current Open 386MAX it also reports the QPI version and active
page-table frame; those facts do not by themselves mean that a scheduler is
running. The developer probe additionally allocates one page-table frame,
clones the active 0-4 MB mapping into it, briefly performs a verified switch,
allocates and exhausts a four-page owned private-data pool, installs and
commits a four-entry mapping table in an exclusively reserved DOS test area,
verifies that all mappings persist across a root/clone switch, restores the
original mappings, and releases every data page before the clone. Root
restoration before full-table commit and out-of-order release fail closed.

`MAXVSET.EXE` edits launcher-local preferences in `MAXVSET.INI`.  The distinct
basename prevents its `.NEW` and `.BAK` files from colliding with catalogue
updates.  The current options control resident-API and ANSI-console autoload,
exit confirmation, catalogue reload after children, memory-limit display,
program hotkeys and the Quick Help text.  Scheduler, swapping and per-VM
settings are deliberately not offered until the Open 386MAX backend advertises
those capabilities.  For automation use `MAXVSET /CHECK`, `MAXVSET /LIST`, and
optional `/F:file`.

`MAXVAUTO.EXE` detects known DOS programs in the current directory and every
directory on `PATH`.  The interactive screen lets the user select discoveries
before adding them to `MAXVIEW.CFG`; already configured executables are not
offered again and hotkeys are allocated without collisions.  Additional trees
can be searched with `/R:directory`.  Automation uses `MAXVAUTO /SCAN` for a
read-only report, `MAXVAUTO /APPLY` to add every discovery, and
`MAXVAUTO /CHECK` to validate `MAXVAUTO.DAT`.  `/F:catalog` and `/D:database`
select alternate files.  Catalogue updates use the same atomic `.NEW`/`.BAK`
scheme as `MAXVAPP`.

The detection database is plain text and may be extended locally.  Each
non-comment line has this format:

```text
filename|title|command|min-kb|max-kb
```

Filenames follow DOS 8.3 rules.  Detection only checks for a named file; it
does not execute, inspect or copy third-party programs.

`MAXVFILE.EXE` is the foreground-mode DOS Services replacement.  Its
386MAX-style browser opens directories with Enter or Backspace and provides
F5 copy, F6 rename, F7 create-directory and F8 confirmed deletion.  It refuses
to copy a file onto itself and never deletes without an explicit confirmation.
For scripts and diagnostics, `/LIST /P:directory` emits a canonical directory
listing, `/COPY source destination [/Y]` copies without overwriting unless
requested, and `/DELETE file /Y` requires the explicit `/Y` guard.

`MAXVANSI.COM` installs once as an `INT 29h` foreground console service.  It
supports cursor movement and positioning (`A`, `B`, `C`, `D`, `H`, `f`),
screen and line erase (`J`, `K`), cursor save/restore (`s`, `u`), and the basic
ANSI colour, bold, blink and reverse-video attributes (`m`).  Installation is
discoverable through a private, versioned multiplex query, and a second run is
harmless.  Programs that write directly to video memory bypass the service;
per-window ANSI state will require the future multi-context video backend.

`MAXVDVP.EXE` reads the documented TopView/DESQview program-information
layout, verifies the base checksum and imports the title, command, parameters,
working directory, menu key and memory limits into `MAXVIEW.CFG`. Running
`MAXVDVP` opens a 386MAX-style `.DVP` browser and confirmation screen.
Automation uses `/CHECK`, `/LIST` or `/IMPORT`, with `/F:catalog` and optional
`/K:key`.
Advanced DVP scheduling, virtualization, serial-port and protection fields are
reported by `/LIST` but are not enforced until the corresponding 1.x backend
capabilities exist.

## Reference-media inventory

The inspection tool reads only the QIP directory and never extracts or copies
payloads:

```sh
python3 tools/qipinfo.py /path/to/DESQVIEW.QIP
```

## Legal

Open MaxView is independent software and is not affiliated with or endorsed by
Quarterdeck or its successors.  DESQview and QEMM are names of their
respective owners.  New source code in this repository is licensed under
GPL-3.0-or-later; see [`LICENSE`](LICENSE).

