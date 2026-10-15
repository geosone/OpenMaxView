# Configuration reference

Text files accept blank lines and comment lines beginning with `#`. Keep DOS
paths within the limits of the target DOS environment. Interactive writers
use `.NEW` and `.BAK` files so an update does not overwrite the only copy.

## MAXVIEW.CFG

The version-1 program catalogue contains at most 24 records. Each record has
six pipe-separated fields:

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
