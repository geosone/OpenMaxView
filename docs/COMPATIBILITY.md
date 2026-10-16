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
| Keyboard-mouse control | Foreground state implementation | Query, enable and disable are retained per child; event synthesis is not yet implemented. |
| System/common memory API | Bounded foreground implementation | Eight task slots and four global slots of 256 bytes each. |
| Process memory status | Foreground implementation | Validated current-process MCB size and bounded task-system pool accounting. |
| Conventional/expanded status | Foreground implementation | DOS MCB and standard EMS queries reported in documented KB units. |
| Physical debug status | Implemented | `DBGPOKE` appends characters on the bottom text row without replacing attributes. |
| Foreground task object | Foreground implementation | Real task handle supports identity, DOS ownership, enumeration and versioned window information. |
| `HANDLE` object message | Foreground implementation | Original caller-stack ABI returns the window and validates live task/timer handles; unavailable selectors return null. |
| Timer objects | Bounded nonblocking implementation | Four pointer-compatible timers support lifecycle, relative/absolute countdown, open/close and elapsed/remaining/state queries. |
| Mailbox objects | Bounded nonblocking queue implementation | Two pointer-compatible mailboxes each hold four copied `WRITE`/`ADDTO` or referenced `SUBFROM` messages of up to 128 bytes; both read forms, lifecycle, queries, erase, base flags and 32-byte names/lookup are implemented. Empty reads return Carry instead of waiting. |
| Window location and buffer | Foreground implementation | `LOCATE` resolves the one full-screen task; `GETBUF` exposes the active text page. |
| TopView character output | Foreground text implementation | `PRINTC` writes character/attribute cells with cursor advance, wrap and full-screen scroll; no graphics-window rendering. |
| Installation path | Implemented | `GETDVPATH` returns the resident loader directory in a terminated 67-byte buffer. |
| DOS program launch | Implemented | One ordinary child at a time through DOS EXEC. |
| Add/change/delete programs | Implemented | Open text catalogue, atomic update and backup. |
| Automatic setup | Implemented | Filename-rule scan; no binary inspection. |
| Settings, file and memory tools | Implemented | Current foreground-safe features only. |
| ANSI console | Foreground implementation | `INT 29h`; direct video writes bypass it. |
| Open 386MAX backend | Discovery/status plus guarded QPI lifecycle | Private ABI 1.0 identifies the provider; one clone, a four-page private pool and four-entry mapping table have ordered allocation, activation, full-table commit across a root/clone switch, restoration and release. |
| `.DVP` compatibility | Versioned import implemented | Launch and advanced task fields persist; advanced enforcement awaits backend support. |
| Panels, blocking mailbox reads and blocking timer operations | Planned for 1.x | Wait/wakeup behavior and further dynamic object classes require scheduler-backed conformance tests. |
| Concurrent V86 tasks and scheduler | Planned for 1.x | QPI context/IRQ primitives exist; MaxView register, DOS-state and scheduling code is still required. |
| Per-task video, keyboard and I/O | Planned for 1.x | A guarded owned-private-page QPI mapping exists; complete task memory maps and trap integration are still required. |
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
