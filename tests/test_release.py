import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from tools.build_release import BOOK_FILES, REQUIRED_DOS_FILES, build_release


class ReleaseBuilderTests(unittest.TestCase):
    def test_release_is_complete_and_deterministic(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "package"
            books = root / "books"
            first = root / "first"
            second = root / "second"
            package.mkdir()
            books.mkdir()
            for name in REQUIRED_DOS_FILES:
                (package / name).write_bytes(name.encode("ascii"))
            for source_name, _ in BOOK_FILES:
                (books / source_name).write_bytes(source_name.encode("ascii"))

            first_files = build_release(package, books, first, "0.8-test")
            second_files = build_release(package, books, second, "0.8-test")
            self.assertEqual([path.name for path in first_files],
                             [path.name for path in second_files])
            for left, right in zip(first_files, second_files):
                self.assertEqual(left.read_bytes(), right.read_bytes())

            archive = first / "OpenMaxView-0.8-test-DOS.zip"
            with zipfile.ZipFile(archive) as source:
                self.assertEqual(source.namelist(), [
                    f"OpenMaxView/{name}" for name in sorted(REQUIRED_DOS_FILES)
                ])
            sums = (first / "SHA256SUMS.txt").read_text(encoding="ascii")
            expected = hashlib.sha256(archive.read_bytes()).hexdigest()
            self.assertIn(f"{expected}  {archive.name}\n", sums)

    def test_incomplete_package_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "package"
            books = root / "books"
            package.mkdir()
            books.mkdir()
            (package / "SETUP.EXE").write_bytes(b"setup")
            for source_name, _ in BOOK_FILES:
                (books / source_name).write_bytes(b"book")
            with self.assertRaises(ValueError):
                build_release(package, books, root / "output", "0.8-test")


if __name__ == "__main__":
    unittest.main()
