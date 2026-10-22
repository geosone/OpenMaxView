/* SPDX-License-Identifier: GPL-3.0-or-later */
/* MVRUN:  runs DOS programs concurrently on the Open MaxView core
 * (kernel/mvkern.asm) for the given time, then stops them.  A developer
 * and test tool for the multitasking core until the launcher uses it.
 *
 *   MVRUN [/Fn] [/Ks] [/Tf,b] [/Nn] seconds prog [args] [; prog [args]] ...
 *   MVRUN [/Fn] [/Tf,b] [/Nn] seconds @list
 *
 * prog is a full path.  /Fn:  task n is the foreground at the start
 * (default 0, MVRUN itself); Ctrl+Alt+n switches.  /Ks:  the last program
 * starts only after s seconds, when all the others are killed, in a slot
 * freed by them.  @list:  the programs from a file, one "prog [args]" a line
 * (more than a command line holds); one that cannot start is reported and
 * the others run.  /Tf,b:  time slices in ticks of the task with the keys
 * and of the others (default 6,2).  /Nn:  task slots, MVRUN's included (default 16).  Prints the switch count and each task's state and
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
    int ntask = 0, i, t, rc, fg = 0, ksecs = 0, tfg = 0, tbg = 0, nslot = 16;
    unsigned long secs, start, n;

    while (argc > 1 && (argv[1][0] == '/' || argv[1][0] == '-')) {
        if (argv[1][1] == 'F' || argv[1][1] == 'f')
            fg = atoi(argv[1] + 2);
        else if (argv[1][1] == 'K' || argv[1][1] == 'k')
            ksecs = atoi(argv[1] + 2);
        else if (argv[1][1] == 'N' || argv[1][1] == 'n')
            nslot = atoi(argv[1] + 2);
        else if (argv[1][1] == 'T' || argv[1][1] == 't') {
            const char *c = strchr(argv[1], ',');

            tfg = atoi(argv[1] + 2);
            tbg = c != 0 ? atoi(c + 1) : 0;
        }
        else
            break;
        argv++;
        argc--;
    }
    if (argc < 3) {
        puts("MVRUN [/Fn] [/Ks] [/Tf,b] [/Nn] seconds prog [args] [; prog [args]] ...");
        return 2;
    }
    secs = strtoul(argv[1], 0, 10);
    rc = mvhost_init(nslot);
    if (rc != 0) {
        printf("MVRUN: %s\n", errtext(rc));
        return 1;
    }
    if (argv[2][0] == '@') {
        FILE *f = fopen(argv[2] + 1, "r");
        char buf[128], *p;

        if (f == 0) {
            printf("MVRUN: no %s\n", argv[2] + 1);
            mvk_stop();
            return 1;
        }
        while (fgets(buf, sizeof buf, f) != 0) {
            buf[strcspn(buf, "\r\n")] = 0;
            p = buf + strcspn(buf, " ");
            strcpy(tail, p);
            *p = 0;
            if (buf[0] == 0)
                continue;
            t = mvk_create(buf, tail);
            if (t < 0)
                printf("MVRUN: %s: %s\n", buf, errtext(-t));
            else {
                printf("task %d: %s%s\n", t, buf, tail);
                ntask++;
            }
        }
        fclose(f);
        argc = 2;               /* (no more) */
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
    mvk_tune(tfg, tbg);
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
        if (t > ntask && lprog == 0)
            break;              /* all done (and /K's program run) */
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
