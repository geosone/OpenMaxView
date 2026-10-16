# Roadmap

This page distinguishes commitments from ideas. The active goal is the local
DESQview 2.8 reimplementation. Remote access is recorded for architectural
foresight only.

## 0.x construction milestones

Milestone 0.8 supplies a tested foreground launcher, compatibility TSR,
installer, program editor, automatic setup, settings, memory status, file
services and ANSI console. It also defines and validates the read-only
Open 386MAX ABI boundary.

Further 0.x work should land in independently testable slices:

1. Extend the implemented `HANDLE`, timer and bounded mailbox messages with
   scheduler-backed empty-mailbox/timer waits, keyboard queues and panels.
2. Enable individual classes in the implemented task-bound process resource
   contract only as scheduler, video, serial and protection backends acquire
   and verify the corresponding resources.
3. Add the V86 entry/exit assembly that consumes the implemented saved register
   image and VM-context ownership layer, beginning with cooperative execution
   primitives for Open MaxView-aware tasks.
4. Extend the implemented single-context QPI allocate/clone/guarded-switch/
   bounded-private-page-pool/mapping-table/commit/reactivate/restore/
   ordered-release wrapper and VM-task coordinator into complete task memory
   maps, then wrap virtual interrupts, timer, video and I/O trapping.
5. Add timer-driven preemption, per-task DOS state, QPI context switching and
   true local windows.
6. Add serial ownership, UART I/O trapping, virtual IRQ delivery and a FOSSIL
   path; validate sustained background BBS transfers.
7. Test representative DESQview-aware and ordinary DOS applications and
   publish known deviations.

## 1.0 acceptance criteria

The 1.0 label requires all of the following:

* multiple isolated DOS tasks on the supported 386-class configuration;
* reliable foreground/background scheduling and task switching;
* per-task conventional memory, DOS state, keyboard and text-video state;
* the DESQview API surface needed by the declared compatibility set;
* `.DVP` import or equivalent migration with documented field coverage;
* local setup and maintenance tools with one consistent 386MAX-style UI;
* automated API/backend tests plus documented real-application results;
* reliable background serial operation for the declared BIOS/UART/FOSSIL
  compatibility set, including conflict and shared-IRQ tests;
* installation, recovery, user, administrator and developer documentation.

The memory manager itself remains Open 386MAX; duplicating QEMM is not an
acceptance criterion.

This boundary also applies to later networking: Open MaxView owns every DOS
network provider and remote protocol. Open 386MAX remains a memory manager and
does not acquire NDIS, ODI, TCP/IP or TLS code.

## 1.x maintenance

After 1.0, the 1.x branch is reserved for local compatibility, stability,
additional applications and safe extensions that do not require a new remote
trust model.

## 2.x wishlist

The future 2.x line may add per-task remote viewing/control from a Qt 6 client
on Linux, Windows and macOS. It must be optional, version-negotiated and secure
by default. On DOS it must coexist on one physical adapter with Microsoft
Network Client (NDIS) and Novell NetWare client configurations (ODI/IPX); it
must not take exclusive ownership of the NIC. It reuses the detected Microsoft
or Novell TCP stack; only the Packet Driver/multiplexer case supplies mTCP.
No 2.x feature is implemented or promised by milestone 0.8. The preliminary
design and open feasibility questions are in
[Remote view design note](REMOTE_VIEW_2X.md).
