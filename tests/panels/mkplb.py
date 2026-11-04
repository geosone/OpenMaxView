#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build MVTEST.PLB, a panel library for the panel tests (PANPRB, mvtest).

A panel library (as DESQview reads it):  C0h C3h, the number of panels
(a byte), per panel 8 bytes of name (blank filled), its offset (DWORD) and
length (WORD) in the file; a panel is a sequence of streams (1Bh, type,
length WORD, the bytes), written to the window it is applied to.  The
first is a window stream beginning with E5h (DESQview 2.80 refuses others:
status 16h)."""
import struct, sys

def stream(kind, body):
    return bytes([0x1B, kind]) + struct.pack('<H', len(body)) + body

def text(s):                    # 60h+n:  n characters (0:  32)
    out = b''
    s = s.encode('ascii')
    while s:
        part, s = s[:31], s[31:]
        out += bytes([0x60 + len(part)]) + part
    return out

def at(row, col):
    return bytes([0xC0, row, col])

def title(s):
    return bytes([0xEF, len(s)]) + s.encode('ascii')

def panel(style, body):
    return stream(0, bytes([0xE5, style]) + body)

FORM = (bytes([0xE6, 7, 30]) + title('Panel form') + bytes([0xC2, 12, 40])
        + at(1, 1) + text('Two fields:')
        + bytes([0xFF, 2, 0x01, 1, 1, 0x70, 0x70,
                 3, 10, 3, 14, 0x80, 0, 0x70,
                 5, 10, 5, 12, 0x80, 0, 0x70, 0xF4, 1])
        + bytes([0xD4, 0xE4]))

PANELS = [
    ('TEXT', panel(0, at(0, 0) + bytes([0xE2, 0x1E]) + text('Panel text in the own window')
                    + at(1, 0) + text('second row') + bytes([0xE4]))),
    ('WIN', panel(0, bytes([0xE6, 5, 30]) + title('Panel window') + bytes([0xC2, 4, 20])
                   + at(1, 2) + text('in a new window') + bytes([0xD4, 0xE4]))),
    ('FORM', panel(0, FORM)),
    ('FORM8', panel(0x80, FORM)),
    # the own window (C5h); a row filled, the next begun; then colours only
    # (90h, 20 cells) from the top left:  the characters stay
    ('WRAP', panel(0, bytes([0xC5, 4, 10]) + at(0, 0) + text('0123456789ABCDE')
                   + at(0, 0) + bytes([0x90, 20, 0x1E, 0xD4, 0xE4]))),
]

def build():
    head = bytes([0xC0, 0xC3, len(PANELS)])
    off = len(head) + 14 * len(PANELS)
    dirs, data = b'', b''
    for name, body in PANELS:
        dirs += name.ljust(8).encode('ascii') + struct.pack('<IH', off + len(data), len(body))
        data += body
    return head + dirs + data

if __name__ == '__main__':
    open(sys.argv[1], 'wb').write(build())
