# Compatibility and limitations

## Milestone 0.8 status

| Area | Status | Notes |
|---|---|---|
| DESQview presence query | Implemented | Reports API 2.80. |
| Cooperative pause | Implemented | Returns safely through the resident service. |
| Critical markers | Implemented | Nested, saturating state reset around each child. |
| Task-state calls | Foreground implementation | `APPNUM`, `APILEVEL`, modes, error policy and critical-state calls. |
| Alternate text-video buffer | Foreground implementation | Aliases B000h/B800h and accepts change notification. |
| Physical screen queries | Foreground implementation | Reports BIOS rows, columns and mode; no direct-window switch or DV/X identity. |
| DESQview keyboard injection | Foreground implementation | `PUSHKEY` and handle-validated `PUTKEY` add scan/character pairs to the BIOS buffer. |
| System/common memory API | Bounded foreground implementation | Eight task slots and four global slots of 256 bytes each. |
| Foreground task object | Foreground implementation | Real task handle supports identity, DOS ownership, enumeration and versioned window information. |
| Window location and buffer | Foreground implementation | `LOCATE` resolves the one full-screen task; `GETBUF` exposes the active text page. |
| Installation path | Implemented | `GETDVPATH` returns the resident loader directory in a terminated 67-byte buffer. |
| DOS program launch | Implemented | One ordinary child at a time through DOS EXEC. |
| Add/change/delete programs | Implemented | Open text catalogue, atomic update and backup. |
| Automatic setup | Implemented | Filename-rule scan; no binary inspection. |
| Settings, file and memory tools | Implemented | Current foreground-safe features only. |
| ANSI console | Foreground implementation | `INT 29h`; direct video writes bypass it. |
| Open 386MAX backend | Discovery/status only | ABI 1.0 has no multi-context capability. |
| `.DVP` compatibility | Versioned import implemented | Launch and advanced task fields persist; advanced enforcement awaits backend support. |
| Objects, panels, mailboxes, timers | Planned for 1.x | Must be independently specified and tested. |
| Concurrent V86 tasks and scheduler | Planned for 1.x | Requires the new Open 386MAX contract. |
| Per-task video, keyboard and I/O | Planned for 1.x | Requires context isolation and traps. |
| Remote viewing | Deferred to 2.x | No remote code is present in 0.8 or the 1.x goal. |

## Meaning of the version lines

The 0.x milestones are usable construction stages and must state their limits.
The 1.x line is the DESQview 2.8 reimplementation line: compatible task
descriptions and APIs, multiple isolated DOS tasks, scheduling, window/task
switching, and the expected local tools. A 1.0 release requires conformance
tests and real-application testing, not merely a similar menu.

The 2.x line may add secure remote viewing and control. It must build on the
completed multi-context design and must not delay or blur the local 1.x
compatibility target.

## Non-goals

Open MaxView does not reimplement QEMM. Open 386MAX is the dependency for
memory management and the planned V86 backend. It also does not redistribute
DESQview binaries, copy its artwork or manual text, accept serial numbers, or
claim undocumented behaviour without a clean-room test.
