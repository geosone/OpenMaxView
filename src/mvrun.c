/* SPDX-License-Identifier: GPL-3.0-or-later */
/* MVRUN:  runs DOS programs concurrently on the Open MaxView core
 * (kernel/mvkern.asm) for the given time, then stops them.  A developer
 * and test tool for the multitasking core until the launcher uses it.
 *
 *   MVRUN [/Fn] [/Ks] seconds prog [args] [; prog [args]] ...
 *
 * prog is a full path.  /Fn:  task n is the foreground at the start
 * (default 0, MVRUN itself); Ctrl+Alt+n switches.  /Ks:  the last program
 * starts only after s seconds, when all the others are killed, in a slot
 * freed by them.  Prints the switch count and each task's state and
 * ends with "MVRUN: done". */
#include <direct.h>
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mvhost.h"
#include "mvkern.h"

#define errtext mvhost_error

static unsigned long ticks(void)
{
    return *(unsigned long far *)MK_FP(0x40, 0x6c);
}

int main(int argc, char **argv)
{
    static char tail[128];
    static char ltail[128];
    const char *lprog = 0;
    int ntask = 0, i, t, rc, fg = 0, ksecs = 0;
    unsigned long secs, start, n;

    while (argc > 1 && (argv[1][0] == '/' || argv[1][0] == '-')) {
        if (argv[1][1] == 'F' || argv[1][1] == 'f')
            fg = atoi(argv[1] + 2);
        else if (argv[1][1] == 'K' || argv[1][1] == 'k')
            ksecs = atoi(argv[1] + 2);
        else
            break;
        argv++;
        argc--;
    }
    if (argc < 3) {
        puts("MVRUN [/Fn] seconds prog [args] [; prog [args]] ...");
        return 2;
    }
    secs = strtoul(argv[1], 0, 10);
    rc = mvhost_init();
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
        if (ksecs != 0 && i >= argc) {
            lprog = prog;       /* /K:  later */
            strcpy(ltail, tail);
            break;
        }
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
        if (lprog != 0 && ticks() - start >= ksecs * 182UL / 10) {
            unsigned long k = ticks();

            for (t = 1; t <= ntask; ++t)
                mvk_kill(t);
            while (ticks() - k < 5 * 18) {
                for (t = 1; t <= ntask; ++t)
                    if (mvk_state(t) == MVK_READY)
                        break;
                if (t > ntask)
                    break;
            }
            /* to the screen of MVRUN (the killed foreground's goes) */
            printf("killed in %lu ticks:", ticks() - k);
            for (t = 1; t <= ntask; ++t)
                printf(" %d %s %04X", t,
                       mvk_state(t) == MVK_DONE ? "done" : "running",
                       mvk_exit(t));
            putchar('\n');
            t = mvk_create(lprog, ltail);
            if (t < 0)
                printf("MVRUN: %s: %s\n", lprog, errtext(-t));
            else
                printf("task %d: %s%s\n", t, lprog, ltail);
            lprog = 0;
        }
        for (t = 1; t <= ntask; ++t)
            if (mvk_state(t) == MVK_READY)
                break;
        if (t > ntask)
            break;              /* all done */
        mvk_yield();            /* we only wait */
    }
    n = mvk_switches();
    for (t = 1; t <= ntask; ++t)
        printf("task %d: %s exit %04X\n", t,
               mvk_state(t) == MVK_DONE ? "done" : "running", mvk_exit(t));
    mvk_stop();
    printf("switches %lu\n", n);
    {
        char cwd[80];

        if (getcwd(cwd, sizeof cwd) != NULL)
            printf("cwd %s\n", cwd);
    }
    puts("MVRUN: done");
    return 0;
}
