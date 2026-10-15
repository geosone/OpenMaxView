# Open MaxView

Open MaxView is a clean-room, GPL-licensed reimplementation of the DOS
multitasking environment DESQview 2.8.  It targets real DOS (8086 for the
user interface, 80386 or newer for the future virtual-machine backend) and is
designed to cooperate with [Open 386MAX](https://github.com/geosone/386MAX)
instead of reimplementing a memory manager.

The repository does **not** contain files from Quarterdeck's DESQview media.
Those files are useful as behavioural reference material, but are neither a
build dependency nor redistributed.

## Current milestone: 0.1

This first runnable milestone provides:

* `MAXVIEW.EXE`, an 80x25 DOS program launcher with a DESQview-style menu;
* `MAXVTSR.COM`, a resident compatibility service which implements the
  documented DESQview presence query and cooperative `PAUSE` call;
* Open 386MAX/VCPI detection and a diagnostic screen;
* the Open 386MAX QUILIB look: two-pane layout, palette, shadows, hotkeys and
  bottom command buttons;
* a plain-text, versioned program-description format (`MAXVIEW.CFG`);
* a read-only host tool for inventorying Quarterdeck QIP installation media;
* host-side parser tests and a DOS API probe.

The 0.1 launcher runs one ordinary DOS child at a time.  It is not yet a
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
make test
make test-dos
```

The DOS binaries are written to `build/`.  Copy these files into one DOS
directory:

```text
build/MAXVIEW.EXE
build/MAXVTSR.COM
build/DVPROBE.EXE
MAXVIEW.CFG
```

Run `MAXVIEW`.  The launcher installs `MAXVTSR.COM` automatically when it is
available in the current directory or on `PATH`.

For the eventual 386 backend, boot DOS with Open 386MAX first.  Version 0.1
only detects VCPI and reports it; it does not yet request private VM services.

## Program catalogue

Each non-comment line in `MAXVIEW.CFG` has six pipe-separated fields:

```text
hotkey|title|command|working-directory|min-kb|max-kb
```

The working directory may be empty.  Memory values are advisory in 0.1 and
will become enforced limits when the VM backend lands.

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

