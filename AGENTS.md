# Codex project notes

## Open 386MAX and Windows context invariant

When MaxView uses private address spaces (mode `08h`), the Open 386MAX
standard/root context must be active before starting Windows. The 386MAX
Windows support records the page table covering the first 4 MiB during
Windows startup. Starting Windows while a MaxView-private context is active
would therefore make that private mapping the Windows baseline.

Any future launcher or scheduler path that can start Windows must switch to
the standard context first and verify that the switch succeeded. If the
standard context cannot be established, abort the Windows launch; do not
continue in a private `08h` address space. Add a backend conformance test for
this transition when multi-context services are implemented.
