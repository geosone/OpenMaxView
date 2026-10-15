# Secure remote view design note for 2.x

**Status:** wishlist and feasibility plan, not an implemented 1.x feature.

## Objective

A future client should enumerate Open MaxView tasks, open one or more views,
receive text-screen changes and optionally send keyboard/mouse input. The
viewer should be a Qt 6 application for Linux, Windows and macOS. Remote
access depends on the 1.x multi-context backend because a foreground-only
launcher has no independent views to expose.

## Required DOS network coexistence

Remote View must not take exclusive ownership of the network adapter. It must
be usable while the Microsoft Network Client for MS-DOS is active through an
NDIS 2 stack and while a Novell NetWare DOS client is active through ODI/IPX.
The difficult target is both client families and Remote View operating on the
same physical adapter without breaking file-server sessions.

The implementation therefore needs a transport-provider boundary rather than
hard-wiring mTCP directly to a card driver:

```text
MAXVNET session, TLS and framing
             |
       transport provider
        /        |       \
 packet-driver  NDIS 2    ODI
        \        |       /
        shared physical adapter
```

Candidate providers are a normal Packet Driver API, a packet-driver shim that
binds as an additional NDIS 2 protocol, and an ODI/LSL-compatible binding or
shim. Native NDIS/ODI providers remain an option if a shim is unstable or has
unacceptable memory use. Selection is deferred until public interface
documentation and redistributable implementations have been tested.

Where Microsoft and Novell clients must coexist, the preferred topology has
one hardware-facing driver and sharing above it, not an NDIS MAC and ODI MLID
both programming the same card. Two historically plausible directions are an
ODI lower stack with an ODI-to-NDIS support layer, or an NDIS lower stack with
additional protocol/packet-driver bindings. The feasibility spike must select
one documented load order per supported adapter and keep the alternative as a
separate configuration; arbitrary mixing is not a safe default.

The installer must detect rather than overwrite `PROTOCOL.INI`, `NET.CFG`,
`CONFIG.SYS` or `AUTOEXEC.BAT`. It should generate a proposed configuration
and backup, explain driver order, interrupt and memory requirements, and leave
activation to an explicit user action. No provider may hook the NIC interrupt
or hardware directly behind an already loaded NDIS/ODI driver.

The coexistence test matrix is a 2.x release gate:

| DOS setup | Must remain working while Remote View transfers data |
|---|---|
| Packet Driver TCP/IP | Existing packet clients and Remote View. |
| Microsoft NDIS 2 client | Login, SMB drive access and reconnect. |
| Novell ODI client | IPX login, mapped drive access and reconnect. |
| NDIS and ODI sharing one adapter | Both file clients plus Remote View, where the adapter/driver stack supports such binding. |

Tests include sustained traffic, viewer reconnect, server reconnect, unload in
every supported order, packet loss, receive bursts, timer rollover, low-memory
failure and operation inside separate Open MaxView tasks. Unsupported adapter
drivers must be reported explicitly; universal simultaneous binding cannot be
assumed for arbitrary vintage drivers.

A source audit of Open 386MAX found historical NDIS and Novell/ODI compatibility
knowledge, but no transport API suitable for Remote View. This separation is
intentional: all Packet Driver, NDIS, ODI, IP, TCP, TLS and Remote View code
belongs to Open MaxView. Open 386MAX remains a memory manager and provides only
the generic VM/memory mechanisms already required by local multitasking; it
must not gain a network stack, network provider or Remote View API.

## Security decision

A raw netcat-like TCP stream protected only by a password is rejected. It
would disclose the password, screen contents and keystrokes to a passive
observer and would not stop modification or replay. Open MaxView must not
invent a cipher or describe an isolated-LAN assumption as encryption.

The preferred feasibility target is:

```text
DOS MAXVNET -> coexistence provider -> TCP -> TLS 1.2 -> relay
Qt 6 viewer -> QSslSocket/TLS 1.3 or 1.2 --------------^
```

The DOS service initiates an outbound connection. This avoids an Internet-
facing DOS listener, simplifies firewall/NAT deployment and lets the relay
authenticate modern viewers. The DOS side pins the relay public key or
certificate and sends a randomly provisioned device/session token only after
TLS is established. A human password, if offered, is checked by the relay and
stored with a modern password-hashing scheme; it is never a plaintext DOS wire
credential.

## Candidate DOS TCP/TLS stack

The first research spike should combine an mTCP-based TCP provider with a
small TLS 1.2 client port based on BearSSL. This is provisional, not a
dependency decision. mTCP alone solves neither NDIS/ODI coexistence nor TLS;
it is only one candidate above the selected packet interface.

Before adoption the combination must demonstrate:

* a reproducible 16-bit Open Watcom build with no NASM dependency;
* Microsoft NDIS 2 and Novell ODI coexistence through supported providers;
* acceptable conventional-memory use with both file clients resident;
* certificate/public-key pin validation and strong random nonces;
* bounded records, timeouts and clean failure on malformed traffic;
* interoperability tests with the Qt relay and current TLS tooling;
* license and source-package integration compatible with GPL distribution.

BearSSL is interesting because it is portable C, statically linkable, has no
dynamic allocation requirement and offers TLS 1.2 configurations suitable for
small systems. That does not prove a 16-bit Open Watcom port: pointer models,
32/64-bit arithmetic, entropy and code size must be measured. wolfSSL can be
evaluated as another embedded option, but its DOS port, footprint and license
fit must be established before selection.

If direct TLS cannot meet the DOS memory budget, the only approved fallback is
a sidecar gateway on the same machine boundary or a physically isolated direct
link/VLAN. The unencrypted leg must never be presented as safe on shared
Ethernet or Wi-Fi, and the gateway must add authenticated TLS before any wider
network. Exposing the plaintext service to the Internet is not supported.

## Application protocol

TLS carries a small, versioned binary framing protocol. Each frame has a fixed
header containing magic, protocol version, type, payload length, session/view
identifier and monotonically increasing sequence number. Every length is
capped before allocation or parsing.

The first text-mode protocol needs only:

| Message | Direction | Purpose |
|---|---|---|
| `HELLO`, `CAPS` | both | Negotiate version, limits and read/control rights. |
| `VIEW_LIST` | DOS to relay | Enumerate available task views. |
| `VIEW_OPEN`, `VIEW_CLOSE` | viewer to DOS | Subscribe or unsubscribe. |
| `TEXT_FULL` | DOS to viewer | Initial rows, columns, cells and attributes. |
| `TEXT_RECT` | DOS to viewer | Bounded changed rectangle. |
| `CURSOR`, `PALETTE` | DOS to viewer | Cursor state and colour interpretation. |
| `INPUT_KEY`, `INPUT_MOUSE` | viewer to DOS | Authorized input events. |
| `PING`, `PONG`, `ERROR` | both | Liveness and explicit failure. |

Graphics may later use independently decodable tiles with strict dimensions
and compression limits. Version 2.0 should exclude shell execution, file
transfer and clipboard synchronization to keep the attack surface small.

## Qt 6 viewer and relay

The desktop side uses Qt Network and `QSslSocket`, with a session/task list and
one display widget per subscribed view. Read-only and control permissions are
separate. The relay applies connection limits, failed-login throttling,
explicit pairing/revocation and security-event logging without recording
screen contents or keystrokes by default.

The Qt side may accept current platform TLS facilities; the constrained DOS
leg may remain TLS 1.2. Protocol capability negotiation is independent from
the TLS version so either side can evolve without silently weakening security.

## Threat model and rejected designs

The design must protect against packet capture, active modification, replay,
unauthorized viewers, oversized frames and brute-force authentication on a
shared network. A compromised DOS machine or authorized viewer is outside
transport protection and must be handled through revocation and deployment
controls.

Rejected designs are plaintext password authentication, hard-coded default
passwords, home-grown encryption, SSLv2/SSLv3, anonymous listeners, unlimited
frame sizes and automatic Internet exposure. Security failures must close the
session; certificate errors must not have a convenient permanent bypass.

## Gate before implementation

Do not begin product implementation until 1.x exposes stable task/view and
input APIs. Then perform a throwaway memory/coexistence/interoperability spike,
document measurements, select the provider and TLS stack, freeze a protocol
threat model and add fuzzed frame-parser tests. Until those gates pass, this
page remains a direction, not a compatibility promise.

## Research references

* [Novell ODI 16-bit DOS protocol-stack specification](https://www.novell.com/developer/documentation/lancomp/dos_psta/dos_pstack.pdf)
  documents LSL binding and multiple protocol IDs per logical board.
* [Novell ODI architecture overview](https://support.novell.com/techcenter/articles/ana19921103.html)
  describes one LAN board serving multiple protocol stacks.
* [Microsoft/3Com LAN Manager NDIS specification](https://bitsavers.org/communications/3Com/6406-00_Lan_Manager_NDIS_1.0.2_Preliminary_Jan89.pdf)
  defines DOS MAC/protocol binding and concurrent protocol drivers through
  Protocol Manager and `PROTOCOL.INI`.
* [Novell's Microsoft/NetWare integration note](https://support.novell.com/techcenter/articles/ana19950401.html)
  is evidence for a shared ODI/NDIS architecture, but not proof that every DOS
  adapter and client combination will work.
* [mTCP](https://github.com/mbbrutman/mTCP/blob/main/README.md) supplies a
  16-bit Open Watcom DOS TCP/IP codebase and packet-driver interface.
* [BearSSL](https://bearssl.org/api1.html) documents its small-context,
  no-dynamic-allocation TLS design; a 16-bit port is still unproven.
* [Qt 6 SSL support](https://doc.qt.io/qt-6/ssl.html) and
  [`QSslSocket`](https://doc.qt.io/qt-6/qsslsocket.html) cover the planned
  desktop TLS side.
