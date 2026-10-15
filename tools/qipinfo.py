#!/usr/bin/env python3
"""Read a Quarterdeck QIP directory without extracting proprietary payloads."""

from __future__ import annotations

import argparse
import hashlib
from dataclasses import dataclass
from pathlib import Path
import struct
import sys


@dataclass(frozen=True)
class QipEntry:
    name: str
    offset: int


class QipError(ValueError):
    pass


def read_directory(data: bytes) -> list[QipEntry]:
    if len(data) < 16 or data[:2] != b"QP":
        raise QipError("not a Quarterdeck QIP/QPV archive")
    directory_bytes = struct.unpack_from("<I", data, 4)[0]
    first_payload = 16 + directory_bytes
    if directory_bytes == 0 or directory_bytes % 16:
        raise QipError("invalid directory length")
    if first_payload > len(data):
        raise QipError("directory extends beyond end of file")

    entries: list[QipEntry] = []
    for position in range(16, first_payload, 16):
        offset = struct.unpack_from("<I", data, position)[0]
        raw_name = data[position + 4 : position + 16]
        name_bytes = raw_name.split(b"\0", 1)[0]
        try:
            name = name_bytes.decode("ascii")
        except UnicodeDecodeError as exc:
            raise QipError("non-ASCII directory entry") from exc
        if not name or offset < first_payload or offset >= len(data):
            raise QipError("invalid directory entry")
        entries.append(QipEntry(name, offset))
    return entries


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args(argv)
    data = args.archive.read_bytes()
    try:
        entries = read_directory(data)
    except QipError as exc:
        parser.error(str(exc))

    print(f"archive: {args.archive}")
    print(f"size:    {len(data)} bytes")
    print(f"sha256:  {hashlib.sha256(data).hexdigest()}")
    print(f"files:   {len(entries)}")
    print()
    for index, entry in enumerate(entries):
        end = entries[index + 1].offset if index + 1 < len(entries) else len(data)
        print(f"{entry.offset:08x}  {end - entry.offset:8d}  {entry.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

