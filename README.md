# Open MaxView

Open MaxView is a clean-room, GPL-licensed reimplementation of the DOS
multitasking environment DESQview 2.8.  It targets real DOS (8086 for the
user interface, 80386 or newer for the future virtual-machine backend) and is
designed to cooperate with [Open 386MAX](https://github.com/geosone/386MAX)
instead of reimplementing a memory manager.

The repository does **not** contain files from Quarterdeck's DESQview media.
Those files are useful as behavioural reference material, but are neither a
build dependency nor redistributed.

## Current milestone: 0.3

This first runnable milestone provides:

* `MAXVIEW.EXE`, an 80x25 DOS program launcher with a DESQview-style menu;
* `MAXVTSR.COM`, a resident compatibility service which implements the
  documented DESQview presence query, cooperative `PAUSE`, nested critical
  sections and the alternate text-video-buffer calls;
* Open 386MAX backend ABI discovery/status validation and a diagnostic screen;
* the Open 386MAX QUILIB look: two-pane layout, palette, shadows, hotkeys and
  bottom command buttons;
* `MAXVAPP.EXE`, a full-screen Add/Change/Delete Program catalogue editor with
  atomic `.NEW`/`.BAK` updates;
* `MAXVMEM.EXE`, a read-only DOS/EMS/XMS/VCPI/MAXVTSR/Open-386MAX status tool;
* `SETUP.EXE`, a QUILIB-style interactive and unattended DOS installer;
* a plain-text, versioned program-description format (`MAXVIEW.CFG`);
* a read-only host tool for inventorying Quarterdeck QIP installation media;
* host-side parser tests and a DOS API probe.

The 0.3 launcher runs one ordinary DOS child at a time.  It is not yet a
drop-in replacement for DESQview's concurrent virtual DOS machines.  That
requires VM creation, per-VM conventional-memory mappings, DOS-state
virtualisation, timer scheduling, and video/I/O trapping in Open 386MAX.  The
boundary and staged implementation plan are documented in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

The UI deliberately follows the GPL-licensed Open 386MAX DOS tools so the two
projects look and behave like one suite.  Open MaxView keeps its small renderer
independent, avoiding a link-time dependency on the much larger QUILIB.

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
MAXVAPP.EXE     MAXVMEM.EXE     DVPROBE.EXE
MAXVIEW.CFG     README.TXT      LICENSE.TXT
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
files before changing the destination and preserves an existing
`MAXVIEW.CFG` during upgrades.  Automated installations use:

```text
SETUP /S /D:C:\MAXVIEW
```

The workflow and visual design are adapted from the GPL-licensed Open 386MAX
DOS installer, without its registration, compressed-media, CONFIG.SYS or
memory-manager-specific code.

For the eventual 386 backend, boot DOS with the `9x` branch of Open 386MAX.
Version 0.3 validates its private ABI and reports the root-context status.  It
does not claim or request multiple VM services until Open 386MAX advertises
the corresponding capability.

## Program catalogue

Each non-comment line in `MAXVIEW.CFG` has six pipe-separated fields:

```text
hotkey|title|command|working-directory|min-kb|max-kb
```

The working directory may be empty.  Memory values are advisory in 0.3 and
will become enforced limits when the VM backend lands.

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
`N/A`; the tool does not pretend that ABI 1.0 supplies multiple V86 contexts.

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

