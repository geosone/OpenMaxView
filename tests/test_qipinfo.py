from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from qipinfo import QipError, read_directory


class QipDirectoryTests(unittest.TestCase):
    def test_two_entries(self):
        header = b"QPV\0" + struct.pack("<I", 32) + b"\x02\0\0\0" + b"\0" * 4
        directory = (
            struct.pack("<I", 48) + b"ONE.COM\0\0\0\0\0"
            + struct.pack("<I", 52) + b"TWO.EXE\0\0\0\0\0"
        )
        entries = read_directory(header + directory + b"QD00QD11")
        self.assertEqual([(e.name, e.offset) for e in entries],
                         [("ONE.COM", 48), ("TWO.EXE", 52)])

    def test_rejects_bad_magic(self):
        with self.assertRaises(QipError):
            read_directory(b"not a qip")

    def test_rejects_bad_offset(self):
        data = b"QP\0\0" + struct.pack("<I", 16) + b"\0" * 8
        data += struct.pack("<I", 999) + b"BAD.COM\0\0\0\0\0"
        with self.assertRaises(QipError):
            read_directory(data)


if __name__ == "__main__":
    unittest.main()

