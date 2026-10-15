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

Press F2 to inspect the selected program's launch fields and retained DVP
process profile. Press `D` for resident API, VCPI and Open 386MAX diagnostics.

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

Run `MAXVSET` to change global preferences. Every displayed setting is used
by the current launcher; settings for future schedulers or V86 contexts are
not shown prematurely. The exact keys and defaults are documented in
[Configuration](CONFIGURATION.md).

## Included services

`MAXVFILE` supplies foreground file browsing and guarded copy, rename,
directory creation and deletion. `MAXVMEM` reports conventional memory, EMS,
XMS, VCPI, the resident API and the Open 386MAX backend. Unknown or unsafe to
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
