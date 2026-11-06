#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""serping.py SOCKET [N] [--out FILE]:  waits for SERPRB's "R", then sends
one byte at a time and times its echo (N times, 0.3-0.5 s apart); prints
"ping n N min A med B max C" in milliseconds (tests/qemu; START:  seconds after the "R" before the first, default 20)."""
import os, random, select, socket, sys, time

sock = sys.argv[1]
n = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 60
out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else None
end = time.time() + 900
s = None
while time.time() < end:
    if os.path.exists(sock):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock)
            break
        except OSError:
            s = None
    time.sleep(1)
got = b''
while b'R' not in got and time.time() < end:
    r, _, _ = select.select([s], [], [], 1)
    if r:
        got += s.recv(256)
time.sleep(float(os.environ.get('START', '20')))     # until the busy window runs
while select.select([s], [], [], 0.2)[0]:
    s.recv(256)
ms = []
for i in range(n):
    b = bytes([0x41 + i % 26])
    t = time.time()
    s.send(b)
    ok = False
    while time.time() - t < 3:
        r, _, _ = select.select([s], [], [], 3)
        if not r:
            break
        d = s.recv(256)
        if b in d:
            ok = True
            break
    ms.append((time.time() - t) * 1000 if ok else 3000)
    time.sleep(0.3 + random.random() * 0.2)
ms.sort()
res = "ping n %d min %.0f med %.0f max %.0f lost %d" % (
    n, ms[0], ms[len(ms) // 2], ms[-1], sum(1 for m in ms if m >= 3000))
print(res)
if out:
    open(out, 'w').write(res + '\n' + ' '.join('%.0f' % m for m in ms) + '\n')
