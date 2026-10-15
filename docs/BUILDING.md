# Building Open MaxView

## Requirements

* GNU make and a POSIX host shell;
* Open Watcom, defaulting to `/opt/watcom`;
* an Open 386MAX checkout, defaulting to `/home/mario/mars/386MAX`;
* the open-source `linux/bin/jwasm` and `linux/bin/jwlink` embedded in that
  Open 386MAX tree;
* a host C89 compiler and Python 3 for host tests;
* DOSBox for `make test-dos`.

The project intentionally uses the same Open Watcom/JWasm/JWlink toolchain as
Open 386MAX. NASM is not part of the build.

## Commands

```sh
make
make package
make test
make test-dos
make clean
```

Override tool locations without editing the makefile:

```sh
make WATCOM=/path/to/watcom MAXROOT=/path/to/386MAX
```

`make` writes DOS binaries, maps and copied data to `build/`. C sources are
compiled for 16-bit small-model DOS with Open Watcom. Assembly sources use
JWasm's MASM-compatible mode and JWlink creates COM and DOS EXE images.

`make package` rebuilds `build/OpenMaxView/` as installation media. It
contains the installer, runtime programs, default data files, README and GPL
license. Build objects, maps and test-only probes are not copied there.

## Reproducible inputs

Quarterdeck media is not a build input. `/home/mario/Iso/dos/` or any other
local reference-media location must never appear in a make dependency or
package. The only external source dependency used by the DOS runtime design
is the separately maintained Open 386MAX project.

Open 386MAX's `9x` branch is the development target for the backend contract.
Milestone 0.8 only detects and validates ABI 1.0; it does not pretend that the
read-only status interface can create multiple V86 contexts.
