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
memory values are displayed and advisory; a future multi-context backend will
enforce them.

Example:

```text
E|Text editor|EDIT.COM C:\AUTOEXEC.BAT|C:\|192|640
```

Use `MAXVAPP /CHECK` after hand editing.

An imported DVP appends a versioned process profile:

```text
|profile-version|source-version|system-kb|script-bytes|idle-polls|
max-ems-kb|extra-system|rows|columns|text-pages|graphics-pages|
serial-ports|protection|flags1|flags2|flags3|flags4
```

The display above wraps the definition for readability; one catalogue record
always occupies one physical line.

These fields retain the decoded scheduler, video, EMS, serial and protection
requirements even before every capability can be enforced. Profile version 1
is currently defined. Six-field version-1 records remain valid and are saved
unchanged unless a profile is attached. Unknown profile versions and values
outside their byte-sized DVP ranges are rejected rather than guessed.

## MAXVSET.INI

The version-1 settings file contains `KEY=YES` or `KEY=NO` records:

| Key | Default | Effect |
|---|---:|---|
| `AUTO_TSR` | YES | Load `MAXVTSR.COM` when the API is absent. |
| `AUTO_ANSI` | YES | Load `MAXVANSI.COM` when its service is absent. |
| `CONFIRM_EXIT` | YES | Ask before leaving the launcher. |
| `RELOAD_CATALOG` | YES | Re-read the catalogue after a child exits. |
| `SHOW_MEMORY` | YES | Show catalogue memory limits. |
| `HOTKEY_LAUNCH` | YES | Enable direct red-letter launch keys. |
| `QUICK_HELP` | YES | Display the quick-help pane. |

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
does not yet enforce them; each field becomes active only with its matching
1.x scheduler or VM capability. `MAXVAPP` preserves the profile while editing
the basic launch fields. The serial fields and safe migration rules are
specified in [Serial and BBS design guide](SERIAL_BBS.md).
