/* SPDX-License-Identifier: GPL-3.0-or-later */
/* MVRUN:  runs DOS programs concurrently on the Open MaxView core
 * (kernel/mvkern.asm) for the given time, then stops them.  A developer
 * and test tool for the multitasking core until the launcher uses it.
 *
 *   MVRUN [/Fn] seconds prog [args] [; prog [args]] ...
 *
 * prog is a full path.  /Fn:  task n is the foreground at the start
 * (default 0, MVRUN itself); Ctrl+Alt+n switches.  Prints the switch count and each task's state and
 * ends with "MVRUN: done". */
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mvkern.h"

extern unsigned _psp;

static const char *errtext(int e)
{
    switch (e) {
    case MVE_NOQPI: return "no QPI (Open 386MAX or QEMM needed)";
    case MVE_BASE:  return "no free memory block at the task base";
    case MVE_SDA:   return "no DOS swappable data area";
    case MVE_FULL:  return "too many tasks";
    case MVE_MEM:   return "QPI memory or context call failed";
    case MVE_IRQ:   return "QPI IRQ calldowns failed";
    case MVE_STATE: return "not allowed now";
    }
    return "error";
}

static unsigned long ticks(void)
{
    return *(unsigned long far *)MK_FP(0x40, 0x6c);
}

/* Shrink our block so that the next MCB lies on a 4KB boundary:  the
 * task base.  Small model:  code, then DGROUP of at most 64KB. */
static unsigned set_base(void)
{
    union REGS r;
    struct SREGS s;
    unsigned dg, base;

    segread(&s);
    dg = s.ds;
    base = (unsigned)(((unsigned long)dg + 0x1000u + 0xffu) & 0xff00u);
    if ((unsigned long)dg + 0x1000u + 0xffu > 0xffffu)
        return 0;
    r.h.ah = 0x4a;
    /* our MCB is at P-1, a block of N paragraphs from P puts the next
     * MCB at P+N:  N = base - P */
    r.x.bx = base - _psp;
    s.es = _psp;
    intdosx(&r, &r, &s);
    if (r.x.cflag)
        return 0;
    return base;
}

int main(int argc, char **argv)
{
    static char tail[128];
    int ntask = 0, i, t, rc, fg = 0;
    unsigned base;
    unsigned long secs, start, n;

    if (argc > 1 && (argv[1][0] == '/' || argv[1][0] == '-') &&
        (argv[1][1] == 'F' || argv[1][1] == 'f')) {
        fg = atoi(argv[1] + 2);
        argv++;
        argc--;
    }
    if (argc < 3) {
        puts("MVRUN [/Fn] seconds prog [args] [; prog [args]] ...");
        return 2;
    }
    secs = strtoul(argv[1], 0, 10);
    base = set_base();
    if (base == 0) {
        puts("MVRUN: cannot set the task base");
        return 1;
    }
    rc = mvk_init(base);
    if (rc != 0) {
        printf("MVRUN: %s\n", errtext(rc));
        return 1;
    }
    for (i = 2; i < argc; ) {
        const char *prog = argv[i++];

        tail[0] = 0;
        while (i < argc && strcmp(argv[i], ";") != 0) {
            if (strlen(tail) + strlen(argv[i]) + 2 >= sizeof tail)
                break;
            strcat(tail, " ");
            strcat(tail, argv[i++]);
        }
        if (i < argc)
            i++;                /* ";" */
        t = mvk_create(prog, tail);
        if (t < 0) {
            printf("MVRUN: %s: %s\n", prog, errtext(-t));
            mvk_stop();
            return 1;
        }
        printf("task %d: %s%s\n", t, prog, tail);
        ntask++;
    }
    rc = mvk_start(2);
    if (rc != 0) {
        printf("MVRUN: %s\n", errtext(rc));
        mvk_stop();
        return 1;
    }
    if (fg != 0 && mvk_setfg(fg) != 0)
        printf("MVRUN: no task %d\n", fg);
    start = ticks();
    while (ticks() - start < secs * 182 / 10) {
        for (t = 1; t <= ntask; ++t)
            if (mvk_state(t) == MVK_READY)
                break;
        if (t > ntask)
            break;              /* all done */
    }
    n = mvk_switches();
    for (t = 1; t <= ntask; ++t)
        printf("task %d: %s exit %04X\n", t,
               mvk_state(t) == MVK_DONE ? "done" : "running", mvk_exit(t));
    mvk_stop();
    printf("switches %lu\n", n);
    puts("MVRUN: done");
    return 0;
}
