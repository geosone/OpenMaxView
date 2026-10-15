/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <dos.h>
#include <string.h>

#include "mvui.h"

static unsigned short far *screen = (unsigned short far *)0xb8000000UL;

void mvui_put(unsigned row, unsigned col, unsigned char ch,
              unsigned char attr)
{
    screen[row * MVUI_COLS + col] = (unsigned short)(ch | (attr << 8));
}

void mvui_fill(unsigned top, unsigned left, unsigned bottom, unsigned right,
               unsigned char ch, unsigned char attr)
{
    unsigned row, col;
    for (row = top; row <= bottom; ++row)
        for (col = left; col <= right; ++col)
            mvui_put(row, col, ch, attr);
}

void mvui_write(unsigned row, unsigned col, const char *text,
                unsigned char attr)
{
    while (*text != '\0' && col < MVUI_COLS)
        mvui_put(row, col++, (unsigned char)*text++, attr);
}

void mvui_shadow(unsigned top, unsigned left, unsigned bottom, unsigned right)
{
    unsigned position;
    if (right + 1 < MVUI_COLS)
        for (position = top + 1;
             position <= bottom + 1 && position < MVUI_ROWS; ++position)
            mvui_put(position, right + 1,
                     (unsigned char)(screen[position * MVUI_COLS + right + 1]
                                     & 0xff), MVUI_SHADOW);
    if (bottom + 1 < MVUI_ROWS)
        for (position = left + 2;
             position <= right + 1 && position < MVUI_COLS; ++position)
            mvui_put(bottom + 1, position,
                     (unsigned char)(screen[(bottom + 1) * MVUI_COLS + position]
                                     & 0xff), MVUI_SHADOW);
}

void mvui_frame(unsigned top, unsigned left, unsigned bottom, unsigned right,
                const char *title)
{
    unsigned position;
    mvui_fill(top, left, bottom, right, ' ', MVUI_ACTIVE);
    mvui_put(top, left, 201, MVUI_ACTIVE);
    mvui_put(top, right, 187, MVUI_ACTIVE);
    mvui_put(bottom, left, 200, MVUI_ACTIVE);
    mvui_put(bottom, right, 188, MVUI_ACTIVE);
    for (position = left + 1; position < right; ++position) {
        mvui_put(top, position, 205, MVUI_ACTIVE);
        mvui_put(bottom, position, 205, MVUI_ACTIVE);
    }
    for (position = top + 1; position < bottom; ++position) {
        mvui_put(position, left, 186, MVUI_ACTIVE);
        mvui_put(position, right, 186, MVUI_ACTIVE);
    }
    if (title != NULL) {
        mvui_write(top, left + 2, " ", MVUI_ACTIVE);
        mvui_write(top, left + 3, title, MVUI_ACTIVE);
        mvui_write(top, left + 3 + strlen(title), " ", MVUI_ACTIVE);
    }
    mvui_shadow(top, left, bottom, right);
}

void mvui_button(unsigned row, unsigned col, unsigned width, const char *label)
{
    unsigned text_col = col + (width - strlen(label)) / 2;
    mvui_fill(row, col, row, col + width - 1, ' ', MVUI_QUICK);
    mvui_write(row, text_col, label, MVUI_QUICK_HIGH);
    mvui_shadow(row, col, row, col + width - 1);
}

void mvui_init(void)
{
    union REGS inregs, outregs;
    inregs.h.ah = 0x0f;
    int86(0x10, &inregs, &outregs);
    screen = (unsigned short far *)
        ((outregs.h.al == 7) ? 0xb0000000UL : 0xb8000000UL);
    inregs.h.ah = 0x01;
    inregs.x.cx = 0x2000;
    int86(0x10, &inregs, &outregs);
}

void mvui_restore(void)
{
    union REGS inregs, outregs;
    inregs.h.ah = 0x00;
    inregs.h.al = 0x03;
    int86(0x10, &inregs, &outregs);
}
