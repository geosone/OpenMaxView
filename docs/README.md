# Open MaxView documentation

This directory separates released behaviour from compatibility goals and
future ideas. Unless a page explicitly says otherwise, command descriptions
apply to milestone 0.8.

## Users

* [Quick start](QUICKSTART.md) - installation through the first program entry
  on one short path.
* [User guide](USER_GUIDE.md) - installation, first start and daily use.
* [Tools reference](TOOLS.md) - every supplied DOS command and option.
* [Configuration reference](CONFIGURATION.md) - catalogue, settings and
  automatic-detection file formats.
* [Compatibility and limitations](COMPATIBILITY.md) - what works today and
  what remains for the 1.x DESQview-compatible line.
* [Troubleshooting](TROUBLESHOOTING.md) - common build, installation and
  runtime problems.
* [Open MaxView help](HELP.md) - task-oriented help and keyboard reference.
* [Serial and BBS guide](SERIAL_BBS.md) - 1.x COM/UART/FOSSIL design and
  acceptance tests.
* [Programming guide](PROGRAMMING.md) - making DOS software cooperative and
  Open MaxView-aware with Open Watcom examples.

## Developers

* `make book-html` builds the self-contained, illustrated developer handbook
  at `build/books/OpenMaxView-Developer.html`.
* `make book-epub` builds the reflowable user handbook at
  `build/books/OpenMaxView-User.epub`.
* [Building](BUILDING.md) - Open Watcom/JWasm/JWlink build and packaging.
* [Testing](TESTING.md) - host and DOSBox test suites.
* [Conformance matrix](CONFORMANCE.md) - clean-room probe method and the
  feature-by-feature 1.x gap inventory.
* [Resident API](API.md) - implemented DESQview-compatible and private calls.
* [Architecture](ARCHITECTURE.md) - components and the Open 386MAX boundary.
* [Development guide](DEVELOPMENT.md) - clean-room rules, source layout and
  contribution workflow.
* [Roadmap](ROADMAP.md) - 1.x completion criteria and deliberately deferred
  2.x work.
* [2.x remote-view design note](REMOTE_VIEW_2X.md) - non-implemented security,
  protocol and DOS-network coexistence direction for a future Qt 6 client.

Open MaxView is independent software. The documentation describes compatible
behaviour but does not contain proprietary DESQview code, media, artwork or
manual text.

## Installed DOS filenames

`SETUP` installs this set as 8.3 text files: `DOCS.TXT`, `USERGUID.TXT`,
`TOOLS.TXT`, `CONFIG.TXT`, `BUILDING.TXT`, `TESTING.TXT`, `API.TXT`,
`COMPAT.TXT`, `CONFORM.TXT`, `DEVELOP.TXT`, `ROADMAP.TXT`, `REMOTE2.TXT`,
`TROUBLE.TXT`, `ARCHITEC.TXT`, `HELP.TXT`, `BBSGUIDE.TXT`, `PROGDEV.TXT` and `QUICK.TXT`.
Start with `QUICK.TXT`; Markdown punctuation remains readable
with `TYPE`, an editor or another DOS text viewer.
