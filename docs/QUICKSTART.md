# Open MaxView quick start

This short guide takes a new user from installation media to the first
working DOS program entry. Open MaxView currently launches one foreground
program at a time; concurrent virtual DOS tasks are a 1.x target.

## 1. Install

Copy the complete `OpenMaxView` package directory to DOS media, change to that
directory and run:

```text
SETUP
```

Accept `C:\MAXVIEW` or enter another destination. For an unattended install:

```text
SETUP /S /D:C:\MAXVIEW
```

Setup checks its source files before copying and preserves an existing
catalogue, settings file and detection database during an upgrade.

## 2. Start

```text
C:
CD \MAXVIEW
MAXVIEW
```

The launcher normally installs `MAXVTSR.COM` and `MAXVANSI.COM` automatically.
Use Up and Down to select a program, Enter to run it and Esc to leave Open
MaxView. A red letter is a direct hotkey when hotkey launching is enabled.

## 3. Add your programs

Run `MAXVAUTO` for the quickest setup. It scans the current directory and
directories on `PATH`, but never starts a discovered executable. Review the
list, select the wanted entries and apply them.

Use `MAXVAPP` when a program is not in the detection database:

1. Press Insert.
2. Enter a unique hotkey, title and DOS command.
3. Add its working directory if the program needs one.
4. Leave the memory values at their suggested defaults unless the program has
   a documented requirement.
5. Press F2 to save.

To migrate an existing DESQview entry, run `MAXVDVP PROGRAM.DVP`, inspect the
decoded values and confirm the import. The source DVP is not modified.

## 4. Check the installation

Run `MAXVMEM` to see conventional memory, EMS, XMS, VCPI, the resident API and
the Open 386MAX backend. `N/A` means that a value cannot safely be measured; it
is not an error by itself. `MAXVMEM` is a display tool, not a memory manager.

Run these read-only checks when diagnosing configuration files:

```text
MAXVAPP /CHECK
MAXVSET /CHECK
MAXVAUTO /CHECK
```

## 5. Know the important files

| File | Purpose |
|---|---|
| `MAXVIEW.CFG` | Program catalogue |
| `MAXVSET.INI` | Launcher preferences |
| `MAXVAUTO.DAT` | Automatic-detection rules |
| `MAXVIEW.LOG` | Launcher diagnostics |
| `*.BAK` | Previous version retained after a successful save |
| `*.NEW` | Temporary replacement left by an interrupted save |

Back up the three configuration files before a major upgrade. If a save is
interrupted, copy the base, `.BAK` and `.NEW` files somewhere safe before
choosing the newest complete version.

## Where to go next

Read `HELP.TXT` for keyboard-oriented help and `USERGUID.TXT` for the complete
user guide. `TOOLS.TXT` documents every command. BBS operators should also
read `BBSGUIDE.TXT`; its serial multitasking features are explicitly marked as
1.x targets where they are not implemented yet.
