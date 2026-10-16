#!/usr/bin/env python3
"""Build deterministic Open MaxView preview release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import time
import zipfile


BOOK_FILES = (
    ("OpenMaxView-Developer.html", "Developer.html"),
    ("OpenMaxView-User.pdf", "User.pdf"),
    ("OpenMaxView-User.epub", "User.epub"),
)

REQUIRED_DOS_FILES = (
    "LICENSE.TXT",
    "MAXVIEW.CFG",
    "MAXVIEW.EXE",
    "MAXVTSR.COM",
    "QUICK.TXT",
    "SETUP.EXE",
)


def release_timestamp() -> tuple[int, int, int, int, int, int]:
    value = int(os.environ.get("SOURCE_DATE_EPOCH", "315532800"))
    value = max(value, 315532800)  # ZIP timestamps start at 1980-01-01.
    stamp = time.gmtime(value)
    return (stamp.tm_year, stamp.tm_mon, stamp.tm_mday,
            stamp.tm_hour, stamp.tm_min, stamp.tm_sec - stamp.tm_sec % 2)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()


def build_dos_zip(package: Path, archive: Path) -> None:
    entries = list(package.iterdir())
    invalid = [path.name for path in entries if not path.is_file() or path.is_symlink()]
    if invalid:
        raise ValueError("DOS package must contain regular files only: "
                         + ", ".join(sorted(invalid)))
    files = sorted(entries)
    if not files:
        raise ValueError(f"empty DOS package directory: {package}")
    names = {path.name for path in files}
    missing = [name for name in REQUIRED_DOS_FILES if name not in names]
    if missing:
        raise ValueError("incomplete DOS package: " + ", ".join(missing))
    timestamp = release_timestamp()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for path in files:
            info = zipfile.ZipInfo(f"OpenMaxView/{path.name}", timestamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            output.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED,
                            compresslevel=9)


def build_release(package: Path, books: Path, output: Path, version: str) -> list[Path]:
    if not version or any(character.isspace() for character in version):
        raise ValueError("version must be a non-empty token")
    if not package.is_dir():
        raise ValueError(f"DOS package directory not found: {package}")
    output.mkdir(parents=True, exist_ok=True)
    prefix = f"OpenMaxView-{version}"
    artifacts = [output / f"{prefix}-DOS.zip"]
    build_dos_zip(package, artifacts[0])
    for source_name, suffix in BOOK_FILES:
        source = books / source_name
        if not source.is_file():
            raise ValueError(f"book artifact not found: {source}")
        destination = output / f"{prefix}-{suffix}"
        shutil.copyfile(source, destination)
        artifacts.append(destination)
    checksum_file = output / "SHA256SUMS.txt"
    checksum_file.write_text(
        "".join(f"{sha256(path)}  {path.name}\n" for path in artifacts),
        encoding="ascii",
        newline="\n",
    )
    artifacts.append(checksum_file)
    return artifacts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--books", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    arguments = parser.parse_args()
    artifacts = build_release(arguments.package, arguments.books,
                              arguments.output, arguments.version)
    for artifact in artifacts:
        print(artifact)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
