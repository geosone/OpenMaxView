# Troubleshooting

## Build cannot find Open Watcom

Pass the installation root explicitly:

```sh
make WATCOM=/path/to/watcom
```

The expected compiler is `binl64/wcc` and the DOS libraries are below
`lib286/`. A modern host compiler cannot replace the 16-bit DOS compiler.

## Build cannot find JWasm or JWlink

Point `MAXROOT` at an Open 386MAX checkout containing `linux/bin/jwasm` and
`linux/bin/jwlink`:

```sh
make MAXROOT=/path/to/386MAX
```

NASM is neither required nor supported by this build.

## MAXVIEW says a resident service is unavailable

Keep `MAXVTSR.COM` and `MAXVANSI.COM` beside `MAXVIEW.EXE` or on `PATH`. Check
that `AUTO_TSR=YES` and `AUTO_ANSI=YES` in `MAXVSET.INI`, or run each COM file
once before starting the launcher.

## A program is absent or the catalogue is rejected

Run `MAXVAPP /CHECK`. Verify that every non-comment record has six fields,
unique one-character hotkeys, a nonempty title and command, and valid memory
limits. Use `MAXVAPP` for repair. If the latest save was interrupted, compare
`MAXVIEW.CFG`, `MAXVIEW.BAK` and `MAXVIEW.NEW` before choosing a copy.

## Automatic setup finds nothing

Run `MAXVAUTO /CHECK`, then `MAXVAUTO /SCAN /R:C:\SOMEDIR`. Detection is based
on exact 8.3 basenames in `MAXVAUTO.DAT`; it does not infer programs from file
contents. Existing catalogue commands are intentionally filtered out.

## Open 386MAX backend is not detected

Milestone 0.8 works as a foreground launcher without it. Backend discovery
requires a compatible Open 386MAX development build exposing the versioned
ABI. EMS, XMS or VCPI presence alone does not imply this ABI. Use
`MAXVMEM /T` and `DVPROBE` for stable diagnostics.

## Programs do not run concurrently

This is the expected 0.8 limitation, not a configuration error. The launcher
uses DOS EXEC and waits for the child. Concurrent V86 tasks require the
planned Open 386MAX multi-context backend and are part of the 1.x target.

## ANSI sequences are printed or ignored

Run `MAXVANSI.COM` and retry. The service sees the `INT 29h` foreground path;
software writing directly to B800h/B000h bypasses it. Per-task ANSI state is
not possible before video contexts exist.

## DOSBox tests fail without a display

Use the repository's `make test-dos` target. It selects dummy SDL video and
audio drivers. Confirm that a `dosbox` executable is installed and available
on the host `PATH`.
