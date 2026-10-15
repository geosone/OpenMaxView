/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVUI_H
#define MVUI_H

#define MVUI_COLS 80
#define MVUI_ROWS 25

#define MVUI_BACKGROUND   0x08
#define MVUI_DATA         0x1f
#define MVUI_DATA_HIGH    0x1e
#define MVUI_QUICK        0x70
#define MVUI_QUICK_HIGH   0x71
#define MVUI_MENU         0x70
#define MVUI_MENU_TRIGGER 0x74
#define MVUI_ACTIVE       0x3f
#define MVUI_TRIGGER      0x34
#define MVUI_SHADOW       0x08

void mvui_init(void);
void mvui_restore(void);
void mvui_put(unsigned row, unsigned col, unsigned char ch,
              unsigned char attr);
void mvui_fill(unsigned top, unsigned left, unsigned bottom, unsigned right,
               unsigned char ch, unsigned char attr);
void mvui_write(unsigned row, unsigned col, const char *text,
                unsigned char attr);
void mvui_shadow(unsigned top, unsigned left, unsigned bottom, unsigned right);
void mvui_frame(unsigned top, unsigned left, unsigned bottom, unsigned right,
                const char *title);
void mvui_button(unsigned row, unsigned col, unsigned width, const char *label);

#endif
