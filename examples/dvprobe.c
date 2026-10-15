/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <dos.h>
#include <stdio.h>

#include "odqapi.h"

int main(void)
{
    union REGS inregs, outregs;

    inregs.x.ax = 0x2b01;
    inregs.x.cx = 0x4445;
    inregs.x.dx = 0x5351;
    int86(0x21, &inregs, &outregs);
    if (outregs.h.al == 0xff) {
        puts("No DESQview-compatible API detected.");
        return 1;
    }
    printf("DESQview-compatible API version %u.%02X detected.\n",
           outregs.x.bx >> 8, outregs.x.bx & 0xff);

    inregs.x.ax = ODQ_DVC_PAUSE;
    int86(0x15, &inregs, &outregs);
    puts("PAUSE call returned successfully.");
    return 0;
}

