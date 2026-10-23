# Demos

Small programs that use the DESQview API. They run under Open MaxView
and under DESQview 2.x. They are clean-room work for Open MaxView: they
are written from the API documentation (Ralf Brown's Interrupt List) and
from how DESQview 2.80 behaves, not from Quarterdeck's API examples, and
they are GPL-3.0-or-later like the rest of the project.

`make` builds them into `build/`.

| Program | Shows |
|---|---|
| `MENU.COM [file]` | A pop-up menu in a window of its own: a window object (`NEW 08h`), a keyboard object opened to it in field mode, select fields chosen by key (R, G, B, Q) or with the cursor keys and Enter (alternate field mode, `BDh`). Each choice is printed in the own window; Q or Esc ends. With a file name it also logs each field record. |
| `HELLO.COM` | The smallest API program: asks for DESQview (`INT 21h AX=2B01h`), sets API level 2.01 and writes a line to its own window with the API's `WRITE`. |
| `MOUSE.COM` | A pointer object: `ERASE` of the own window, the pointer put on row 5, column 30 (`WRITE` of the pointer), then a mark for each pointer message where it happened (`.` move, `L` left button); the right button ends. Needs a mouse driver. |
| `COUNTDN.COM` | A countdown: a window object with an input field for the seconds (filled from the right), a keyboard object in field mode with the hardware cursor (`ADDTO 3`, then `F4h 1` puts the cursor in the field: DESQview leaves input fields alone without them), a timer object and the OBJECTQ telling which of them has input. Enter starts, each second the timer is started again, at 0 "time is up" goes to the own window; Esc ends. |
