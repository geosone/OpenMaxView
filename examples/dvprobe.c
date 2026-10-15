/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <dos.h>
#include <stdio.h>

#include "maxbackend.h"
#include "odqapi.h"

static int query_state(unsigned expected_depth, unsigned *video_segment)
{
    union REGS inregs, outregs;

    inregs.x.ax = ODQ_MUX_INFO;
    int86(0x2f, &inregs, &outregs);
    if (outregs.x.bx != ODQ_CAPABILITIES ||
        outregs.x.cx != expected_depth)
        return 0;
    *video_segment = outregs.x.dx;
    return 1;
}

static int query_task(unsigned expected_level, unsigned expected_flags)
{
    union REGS inregs, outregs;

    inregs.x.ax = ODQ_MUX_TASK_INFO;
    int86(0x2f, &inregs, &outregs);
    return outregs.x.bx == expected_level && outregs.x.cx == 1 &&
           outregs.x.dx == expected_flags;
}

int main(void)
{
    union REGS inregs, outregs;
    struct SREGS segreg;
    unsigned video_segment = 0;
    odq_max_backend_info backend;

    inregs.x.ax = ODQ_MUX_RESET;
    int86(0x2f, &inregs, &outregs);

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

    inregs.x.ax = ODQ_DVC_APP_NUMBER;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != 1 ||
        !query_task(0x0100, ODQ_TASK_JUSTIFY)) {
        puts("Foreground task defaults failed.");
        return 2;
    }
    puts("Foreground APPNUM and task defaults passed.");

    inregs.x.ax = ODQ_DVC_API_LEVEL;
    inregs.x.bx = 0x0230;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != ODQ_DV_VERSION ||
        !query_task(0x0230, ODQ_TASK_JUSTIFY)) {
        puts("APILEVEL negotiation failed.");
        return 3;
    }

    inregs.x.ax = ODQ_DVC_JUSTIFY;
    inregs.h.bl = 0;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_C_STYLE;
    inregs.x.bx = 1;
    int86(0x15, &inregs, &outregs);
    if (!query_task(0x0230, ODQ_TASK_C_STYLE)) {
        puts("JUSTIFY/CSTYLE task state failed.");
        return 4;
    }
    puts("APILEVEL, JUSTIFY and CSTYLE APIs passed.");

    if (!query_state(0, &video_segment)) {
        puts("Private capability query failed.");
        return 5;
    }
    inregs.x.ax = ODQ_DVC_BEGIN_CRITICAL;
    int86(0x15, &inregs, &outregs);
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_GET_CRITICAL;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != 2) {
        puts("GETCRIT API failed.");
        return 6;
    }
    inregs.x.ax = ODQ_DVC_PAUSE;
    int86(0x15, &inregs, &outregs);
    if (!query_state(2, &video_segment)) {
        puts("Nested critical-section state failed.");
        return 7;
    }
    inregs.x.ax = ODQ_DVC_END_CRITICAL;
    int86(0x15, &inregs, &outregs);
    int86(0x15, &inregs, &outregs);
    int86(0x15, &inregs, &outregs);
    if (!query_state(0, &video_segment)) {
        puts("Critical-section underflow protection failed.");
        return 8;
    }
    puts("Nested critical-section state passed.");

    segread(&segreg);
    segreg.es = video_segment;
    inregs.h.ah = 0xfe;
    inregs.x.di = 0xffff;
    int86x(0x10, &inregs, &outregs, &segreg);
    if (segreg.es != video_segment || outregs.x.di != 0) {
        puts("Alternate video-buffer query failed.");
        return 9;
    }
    inregs.h.ah = 0xff;
    int86(0x10, &inregs, &outregs);
    puts("Alternate video-buffer API passed.");

    inregs.x.ax = ODQ_DVC_PUSH_KEY;
    inregs.h.bh = 0x2d;
    inregs.h.bl = 'x';
    int86(0x15, &inregs, &outregs);
    inregs.h.ah = 0x00;
    int86(0x16, &inregs, &outregs);
    if (outregs.h.ah != 0x2d || outregs.h.al != 'x') {
        puts("Foreground PUSHKEY API failed.");
        return 10;
    }
    puts("Foreground PUSHKEY API passed.");

    inregs.x.ax = ODQ_MUX_RESET;
    int86(0x2f, &inregs, &outregs);

    if (odq_max_backend_query(&backend))
        printf("Open 386MAX backend ABI %u.%u, %u/%u contexts.\n",
               backend.abi_version >> 8, backend.abi_version & 0xff,
               backend.active_contexts, backend.context_limit);
    else
        puts("Open 386MAX backend not detected (foreground mode).");
    return 0;
}

