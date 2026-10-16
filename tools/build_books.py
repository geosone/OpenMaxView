#!/usr/bin/env python3
"""Build the Open MaxView developer HTML book and user PDF manual."""

import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"

DEVELOPER_CHAPTERS = (
    "PROGRAMMING.md",
    "API.md",
    "ARCHITECTURE.md",
    "BUILDING.md",
    "TESTING.md",
    "CONFORMANCE.md",
    "DEVELOPMENT.md",
    "SERIAL_BBS.md",
    "COMPATIBILITY.md",
    "ROADMAP.md",
    "REMOTE_VIEW_2X.md",
)

USER_CHAPTERS = (
    "QUICKSTART.md",
    "HELP.md",
    "USER_GUIDE.md",
    "TOOLS.md",
    "CONFIGURATION.md",
    "SERIAL_BBS.md",
    "TROUBLESHOOTING.md",
    "COMPATIBILITY.md",
)

LINK_RE = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
MARKDOWN_LINK_RE = re.compile(r"(\[[^]]*\]\()([^):#]+\.md)(#[^)]*)?(\))")
HEADING_RE = re.compile(r"^#\s+(.+?)\s*$", re.MULTILINE)


def heading_id(title):
    """Return the simple identifier Pandoc uses for these ASCII headings."""
    value = title.lower().strip()
    value = re.sub(r"[^\w\s-]", "", value, flags=re.UNICODE)
    value = re.sub(r"[\s_-]+", "-", value).strip("-")
    return value


def chapter_anchors(chapters):
    anchors = {}
    for name in chapters:
        text = (DOCS / name).read_text(encoding="utf-8")
        match = HEADING_RE.search(text)
        if not match:
            raise ValueError("{} has no level-one heading".format(name))
        anchors[name.lower()] = heading_id(match.group(1))
    return anchors


def combine(chapters, destination, title):
    anchors = chapter_anchors(chapters)
    sections = ["---\ntitle: {}\nauthor: Open MaxView contributors\nlang: en\n---\n".format(title)]

    def replace_link(match):
        basename = Path(match.group(2)).name.lower()
        anchor = anchors.get(basename)
        if anchor is None:
            return match.group(0)
        fragment = match.group(3) or ""
        return "{}#{}{}{}".format(match.group(1), anchor, fragment, match.group(4))

    for name in chapters:
        text = (DOCS / name).read_text(encoding="utf-8")
        sections.append(MARKDOWN_LINK_RE.sub(replace_link, text).rstrip())
    # A book-class PDF starts each level-one heading as a chapter. Avoid raw
    # TeX page-break commands here so the same combined Markdown remains clean
    # when it is used for the HTML product.
    destination.write_text("\n\n".join(sections) + "\n", encoding="utf-8")


def validate(chapter_sets):
    errors = []
    for chapters in chapter_sets:
        for name in chapters:
            path = DOCS / name
            if not path.is_file():
                errors.append("missing chapter: {}".format(path.relative_to(ROOT)))
                continue
            text = path.read_text(encoding="utf-8")
            if not HEADING_RE.search(text):
                errors.append("chapter has no title: {}".format(path.relative_to(ROOT)))
            for target in LINK_RE.findall(text):
                clean = target.split("#", 1)[0].split("?", 1)[0]
                if not clean or "://" in clean or clean.startswith("mailto:"):
                    continue
                candidate = (path.parent / clean).resolve()
                try:
                    candidate.relative_to(ROOT)
                except ValueError:
                    errors.append("link escapes repository in {}: {}".format(name, target))
                    continue
                if not candidate.exists():
                    errors.append("broken local link in {}: {}".format(name, target))
    if errors:
        for error in sorted(set(errors)):
            print("book check: {}".format(error), file=sys.stderr)
        return False
    return True


def run(command, env=None):
    print(" ".join(str(item) for item in command))
    subprocess.run(
        [str(item) for item in command], cwd=str(ROOT), check=True, env=env)


def build_developer_html(output_dir):
    source = output_dir / "OpenMaxView-Developer.md"
    destination = output_dir / "OpenMaxView-Developer.html"
    combine(DEVELOPER_CHAPTERS, source, "Open MaxView Developer Handbook")
    run((
        "pandoc", source, "--from=gfm", "--standalone", "--toc",
        "--toc-depth=3", "--number-sections", "--embed-resources",
        "--resource-path={}:{}".format(ROOT, DOCS),
        "--css={}".format(DOCS / "book.css"), "--output", destination,
    ))
    return destination


def build_user_pdf(output_dir):
    source = output_dir / "OpenMaxView-User.md"
    destination = output_dir / "OpenMaxView-User.pdf"
    combine(USER_CHAPTERS, source, "Open MaxView User Handbook")
    tex_cache = output_dir / ".texlive-cache"
    tex_cache.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    # Sandboxed and CI builds often have a read-only home directory. LuaTeX
    # still needs a writable font cache, so keep it with the generated book.
    environment["TEXMFVAR"] = str(tex_cache)
    environment["TEXMFCACHE"] = str(tex_cache)
    run((
        "pandoc", source, "--from=gfm", "--standalone", "--toc",
        "--toc-depth=2", "--number-sections",
        "--resource-path={}:{}".format(ROOT, DOCS), "--pdf-engine=lualatex",
        "--include-in-header={}".format(DOCS / "book.tex"),
        "--variable=documentclass:book", "--variable=geometry:margin=22mm",
        "--variable=colorlinks:true", "--variable=fontsize:11pt",
        "--variable=papersize:a4", "--output", destination,
    ), env=environment)
    return destination


def build_user_epub(output_dir):
    source = output_dir / "OpenMaxView-User.md"
    destination = output_dir / "OpenMaxView-User.epub"
    combine(USER_CHAPTERS, source, "Open MaxView User Handbook")
    run((
        "pandoc", source, "--from=gfm", "--standalone", "--toc",
        "--toc-depth=2", "--number-sections", "--split-level=1",
        "--resource-path={}:{}".format(ROOT, DOCS),
        "--css={}".format(DOCS / "epub.css"),
        "--metadata=identifier:org.openmaxview.user-handbook",
        "--output", destination,
    ))
    with zipfile.ZipFile(destination) as archive:
        names = set(archive.namelist())
        required = {
            "mimetype", "META-INF/container.xml", "EPUB/content.opf",
            "EPUB/nav.xhtml", "EPUB/styles/stylesheet1.css",
        }
        missing = required.difference(names)
        if missing:
            raise ValueError(
                "EPUB is missing required entries: {}".format(
                    ", ".join(sorted(missing))))
        if archive.getinfo("mimetype").compress_type != zipfile.ZIP_STORED:
            raise ValueError("EPUB mimetype entry must be stored uncompressed")
        if archive.read("mimetype") != b"application/epub+zip":
            raise ValueError("EPUB has an invalid mimetype entry")
        if not any(name.startswith("EPUB/media/") for name in names):
            raise ValueError("EPUB contains no packaged diagrams")
    print("EPUB structure: valid")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--format",
        choices=("all", "developer-html", "user-pdf", "user-epub"),
        default="all", help="output to build (default: all)")
    parser.add_argument(
        "--output", type=Path, default=ROOT / "build" / "books",
        help="output directory (default: build/books)")
    parser.add_argument(
        "--check", action="store_true",
        help="validate book sources and local links without invoking Pandoc")
    args = parser.parse_args()

    selected = []
    if args.format in ("all", "developer-html"):
        selected.append(DEVELOPER_CHAPTERS)
    if args.format in ("all", "user-pdf", "user-epub"):
        selected.append(USER_CHAPTERS)
    if not validate(selected):
        return 1
    if args.check:
        print("book check: {} chapter set(s) valid".format(len(selected)))
        return 0
    if shutil.which("pandoc") is None:
        print("book build: pandoc is required", file=sys.stderr)
        return 2
    if args.format in ("all", "user-pdf") and shutil.which("lualatex") is None:
        print("book build: lualatex is required for the user PDF", file=sys.stderr)
        return 2

    output_dir = args.output.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    products = []
    if args.format in ("all", "developer-html"):
        products.append(build_developer_html(output_dir))
    if args.format in ("all", "user-pdf"):
        products.append(build_user_pdf(output_dir))
    if args.format in ("all", "user-epub"):
        products.append(build_user_epub(output_dir))
    for product in products:
        print("built {}".format(product.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
