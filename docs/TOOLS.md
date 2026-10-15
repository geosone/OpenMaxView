# DOS tools reference

## SETUP.EXE

Interactive installer. The default target is `C:\MAXVIEW`.

```text
SETUP [/S] [/D:directory]
```

`/S` selects unattended operation. `/D:` chooses the target. `/D=` and
hyphenated `-S` are also accepted. Existing user configuration files are
preserved during upgrades.

## MAXVIEW.EXE

Full-screen program catalogue and launcher. It reads `MAXVIEW.CFG` and
`MAXVSET.INI` in the current directory, optionally loads the two resident
services, changes to the selected working directory, and starts the command
through DOS. Milestone 0.8 waits for that command to finish.

## MAXVTSR.COM

Install-once resident compatibility service. It exposes API version 2.80 and
the implemented pause, foreground task-state, nested critical-section,
foreground keyboard `PUSHKEY` and alternate-video-buffer calls. Running it
again is harmless and reports that it is installed. `API.TXT` documents the
register interface.

## MAXVANSI.COM

Install-once foreground ANSI console. It handles cursor movement (`A`, `B`,
`C`, `D`, `H`, `f`), erase (`J`, `K`), save/restore (`s`, `u`) and basic SGR
colour, bold, blink and reverse-video attributes (`m`) on the `INT 29h` output
path. Direct video-memory output bypasses it.

## MAXVAPP.EXE

Interactive Add/Change/Delete Program editor.

```text
MAXVAPP [/LIST|/CHECK] [/F:file]
```

`/LIST` emits canonical catalogue records. `/CHECK` validates the file and
returns a diagnostic. `/F:` chooses a catalogue other than `MAXVIEW.CFG`.

## MAXVSET.EXE

Interactive global settings editor.

```text
MAXVSET [/LIST|/CHECK] [/F:file]
```

`/LIST` emits effective key/value settings, `/CHECK` validates them, and `/F:`
selects another settings file.

## MAXVAUTO.EXE

Automatic program setup.

```text
MAXVAUTO [/SCAN|/APPLY|/CHECK] [/F:catalog] [/D:database]
         [/R:directory ...]
```

With no mode it starts the interactive selector. `/SCAN` prints discoveries
without modifying the catalogue. `/APPLY` adds all discoveries. `/CHECK`
validates the rule database. `/F:` and `/D:` select alternate files. Each
repeatable `/R:` adds a recursively searched tree. The current directory and
`PATH` are always considered for scanning.

## MAXVFILE.EXE

Interactive DOS file services and guarded command-line operations.

```text
MAXVFILE [/P:directory]
MAXVFILE /LIST [/P:directory]
MAXVFILE /COPY source destination [/Y]
MAXVFILE /DELETE file /Y
```

In the browser, Enter opens a directory, Backspace goes to its parent, F5
copies, F6 renames, F7 creates a directory and F8 requests deletion. `/LIST`
emits a canonical directory listing. Copy refuses replacement unless `/Y` is
present and refuses self-copy. Command-line deletion requires `/Y` even when
the target exists.

## MAXVMEM.EXE

Read-only memory and backend display.

```text
MAXVMEM [/T]
```

`/T` emits stable key/value output for automated diagnostics. The tool does
not allocate memory or change the Open 386MAX configuration. When resident
API 0.7 or later is loaded, it also reports the total, available and largest
Open MaxView common-memory block in bytes.

## MAXVDVP.EXE

Validated DESQview Program Information File inspector and importer.

```text
MAXVDVP
MAXVDVP file.dvp [/F:catalog] [/K:key]
MAXVDVP /CHECK|/LIST file.dvp
MAXVDVP /IMPORT file.dvp [/F:catalog] [/K:key]
```

With no filename the 386MAX-style browser lists `.DVP` files in the current
directory. Selecting a file opens the confirmation screen. `/CHECK` verifies
the documented base size, checksum and required fields. `/LIST` prints decoded
base and DESQview 2.x fields. `/IMPORT` adds the basic launch record without
interaction. `/F:` selects another catalogue and `/K:` requests a hotkey.
Colliding hotkeys are replaced automatically; duplicate commands and full
catalogues are rejected. Catalogue updates retain the prior file as `.BAK`.

The current catalogue can represent title, command/parameters, directory,
hotkey and conventional-memory limits. Other decoded DVP fields remain visible
for later 1.x scheduler and VM work but are not silently claimed as enforced.

## DVPROBE.EXE

Developer diagnostic for the resident DESQview-compatible calls and the
Open 386MAX backend query. It exercises pause, critical nesting and alternate
video-buffer behaviour, exhausts and releases the bounded task-memory pool,
checks common-memory accounting, validates the foreground task object and
its `DOSUSER`, `OBJNEXT` and `WININFO` metadata, exercises global and targeted
keyboard injection, and prints a pass/fail report.

## qipinfo.py

Host-side metadata inventory tool:

```sh
python3 tools/qipinfo.py /path/to/DESQVIEW.QIP
```

It reads the QIP directory only. It deliberately does not extract, copy or
redistribute proprietary payloads.
