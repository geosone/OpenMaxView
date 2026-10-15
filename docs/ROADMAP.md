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

1. Extend the resident API with handles, object lifetime, timers, keyboard
   queues, mailboxes and panel calls.
2. Parse documented `.DVP` fields into a versioned internal process
   descriptor while retaining an editable open format.
3. Add cooperative execution primitives for Open MaxView-aware tasks.
4. Specify, implement and test Open 386MAX VM create/destroy, register state,
   memory maps, virtual interrupts, video and I/O trapping.
5. Add scheduling, per-task DOS state, task switching and true local windows.
6. Test representative DESQview-aware and ordinary DOS applications and
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
