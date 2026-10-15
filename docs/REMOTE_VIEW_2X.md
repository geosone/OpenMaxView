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

The implementation therefore needs a TCP-provider boundary. It should reuse
the TCP stack belonging to an installed Microsoft or Novell DOS client. mTCP
is needed only when the machine exposes a Packet Driver (possibly through a
multiplexer) and has no usable client TCP service:

```text
MAXVNET session, TLS and framing
             |
       TCP stream provider
        /          |          \
 Microsoft DOS  Novell DOS    mTCP
  client TCP     client TCP     |
      NDIS          ODI       Packet Driver/multiplexer
        \            |          /
             physical adapter
```

The Microsoft and Novell providers adapt their installed TCP service to the
small stream interface required by TLS: connect, send, receive, poll and close.
Their exact public application APIs and supported client versions must be
verified in the feasibility spike. Detecting an NDIS or ODI link driver alone
does not prove that its TCP component or an application-facing stream API is
available.

Where Microsoft and Novell clients coexist, MaxView selects one of their
already active TCP services and does not start another TCP stack. File-service
and IPX traffic continues through the configuration already installed by the
user. The preferred topology has one hardware-facing driver and sharing above
it, not an NDIS MAC and ODI MLID both programming the same card. Historical
ODI/NDIS support layers are configuration possibilities, but MaxView does not
silently invent or rewrite that load order.

The installer checks resident interfaces as well as `PROTOCOL.INI`, `NET.CFG`,
`CONFIG.SYS` and `AUTOEXEC.BAT`. A configuration file is only a hint; a runtime
probe decides whether a provider is usable. If exactly one usable TCP provider
is found, it is proposed. If Microsoft and Novell TCP services are both usable,
the user chooses one and the selection is saved. If neither is present but a
Packet Driver is active, mTCP is proposed. Otherwise Setup names the missing
TCP component and where it belongs in the selected DOS network-client setup.
It does not redistribute proprietary client files.

Setup must not overwrite network configuration. It may generate a proposed
configuration and backup, explain driver order, interrupt and memory
requirements, and leave activation to an explicit user action. No provider may
hook the NIC interrupt or hardware directly behind an already loaded NDIS/ODI
driver.

The coexistence test matrix is a 2.x release gate:

| DOS setup | Must remain working while Remote View transfers data |
|---|---|
| Packet Driver plus mTCP | Existing packet clients and Remote View. |
| Microsoft DOS client TCP | Login, SMB drive access and reconnect while its TCP provider carries Remote View. |
| Novell DOS client TCP | IPX/login and mapped-drive access while its TCP provider carries Remote View. |
| Microsoft and Novell clients sharing one adapter | Both file clients plus Remote View through the explicitly selected existing TCP provider. |

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

The first research spike should put a small TLS 1.2 client port based on
BearSSL above one uniform stream API, then implement three providers: Microsoft
DOS-client TCP, Novell DOS-client TCP and mTCP. This is provisional, not a
dependency decision. mTCP is restricted to the Packet Driver fallback and
does not replace a working Microsoft or Novell TCP stack.

Before adoption the combination must demonstrate:

* a reproducible 16-bit Open Watcom build with no NASM dependency;
* detection and explicit selection of Microsoft TCP, Novell TCP and mTCP;
* Microsoft NDIS 2 and Novell ODI file-client coexistence while the selected
  existing TCP provider carries Remote View;
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
