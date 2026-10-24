/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Setting up the multitasking core (kernel/mvkern.asm) in a small model
 * program:  the task base right behind our DGROUP. */
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dvp.h"
#include "mvhost.h"
#include "mvkern.h"

extern unsigned _psp;

const char *mvhost_error(int e)
{
    switch (e) {
    case MVE_NOQPI: return "no QPI (Open 386MAX or QEMM needed)";
    case MVE_BASE:  return "no free memory block at the task base";
    case MVE_SDA:   return "no DOS swappable data area";
    case MVE_FULL:  return "too many tasks";
    case MVE_MEM:   return "QPI memory or context call failed";
    case MVE_IRQ:   return "QPI IRQ calldowns failed";
    case MVE_STATE: return "not allowed now";
    case MVE_DVST:  return "MAXVTSR's per-task state too big for this MVRUN";
    case MVE_DIR:   return "no such directory";
    }
    return "error";
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
    if ((unsigned long)dg + 0x1000u + 0xffu > 0xffffu)
        return 0;
    base = (unsigned)(((unsigned long)dg + 0x1000u + 0xffu) & 0xff00u);
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

/* Our block cannot end there (a TSR loaded after us):  the largest free
 * block above us in conventional memory; a block of ours in front of it
 * up to the next 4KB boundary (DOS frees it when we end). */
static unsigned free_base(void)
{
    union REGS r;
    struct SREGS s;
    unsigned seg, best = 0, bestsize = 0, base, size, end;
    char type;

    r.h.ah = 0x52;
    intdosx(&r, &r, &s);
    seg = *(unsigned far *)MK_FP(s.es, r.x.bx - 2);
    for (;;) {
        type = *(char far *)MK_FP(seg, 0);
        if (type != 'M' && type != 'Z')
            return 0;
        size = *(unsigned far *)MK_FP(seg, 3);
        if (seg >= 0xa000u)
            break;
        if (seg > _psp && *(unsigned far *)MK_FP(seg, 1) == 0 &&
            size > bestsize) {
            best = seg;
            bestsize = size;
        }
        if (type == 'Z')
            break;
        seg += size + 1;
    }
    if (best == 0)
        return 0;
    base = (best + 0xffu) & 0xff00u;
    end = best + bestsize + 1;
    if (base == best)
        return base;
    if (base + 0x1000u >= end)
        return 0;
    /* split:  ours up to base, the free rest from base */
    type = *(char far *)MK_FP(best, 0);
    *(char far *)MK_FP(base, 0) = type;
    *(unsigned far *)MK_FP(base, 1) = 0;
    *(unsigned far *)MK_FP(base, 3) = end - base - 1;
    *(char far *)MK_FP(best, 0) = 'M';
    *(unsigned far *)MK_FP(best, 1) = _psp;
    *(unsigned far *)MK_FP(best, 3) = base - best - 1;
    return base;
}

int mvhost_init(unsigned ntask)
{
    union REGS r;
    unsigned base, kseg;

    /* our block:  DGROUP + 64KB if it can, then the kernel data (first
     * fit:  low), then the task base above them */
    set_base();
    r.h.ah = 0x48;
    r.x.bx = mvk_datasize(ntask);
    intdos(&r, &r);
    if (r.x.cflag)
        return MVE_BASE;
    kseg = r.x.ax;
    base = free_base();
    if (base == 0 || base <= kseg)
        return MVE_BASE;
    return mvk_init(base, kseg);
}

int mvhost_launch(const char *directory, const char *command, int keep)
{
    static char tail[ODQ_COMMAND_LEN + 8];
    const char *shell = getenv("COMSPEC");
    char old_directory[ODQ_DIR_LEN + 1];
    unsigned old_drive, drives;
    int t;

    if (shell == NULL)
        shell = "C:\\COMMAND.COM";
    /* the task starts with the current drive and directories of now
     * (per task from then on):  the program's, ours back afterwards */
    _dos_getdrive(&old_drive);
    if (getcwd(old_directory, sizeof(old_directory)) == NULL)
        old_directory[0] = '\0';
    if (directory[0] != '\0') {
        if (directory[1] == ':')
            _dos_setdrive(toupper(directory[0]) - 'A' + 1, &drives);
        if (chdir(directory) != 0) {
            _dos_setdrive(old_drive, &drives);
            return -MVE_DIR;
        }
    }
    sprintf(tail, keep ? " /K %.120s" : " /C %.120s", command);
    t = mvk_create(shell, tail);
    if (directory[0] != '\0') {
        if (old_directory[0] != '\0')
            chdir(old_directory);
        _dos_setdrive(old_drive, &drives);
    }
    return t;
}

/* MAXVTSR's request block (INT 2Fh D70Bh) */
struct appreq {
    unsigned char state;        /* 1 asked, 2 answered */
    unsigned char from;         /* the task asking */
    unsigned task;              /* the answer:  the new task, 0 none */
    unsigned size;
    unsigned char dvp[0x1a0];
};

int mvhost_appstart(unsigned *from, char *title, int *shown)
{
    static unsigned char data[0x1a0];
    static dvp_info info;
    static odq_program program;
    struct appreq far *q;
    union REGS r;
    struct SREGS s;
    unsigned n;
    int t = 0;

    r.x.ax = 0xd70b;
    r.x.bx = 0;
    s.es = 0;
    int86x(0x2f, &r, &r, &s);
    if (r.x.ax != 0 || s.es == 0)
        return -1;
    q = (struct appreq far *)MK_FP(s.es, r.x.bx);
    if (q->state != 1)
        return -1;
    n = q->size < sizeof data ? q->size : sizeof data;
    _fmemcpy(data, q->dvp, n);
    *from = q->from;
    *shown = 1;
    if (dvp_parse(data, n, &info) == DVP_OK &&
        dvp_make_program(&info, info.menu_keys[0] != '\0' ?
                         info.menu_keys[0] : ' ', &program) == DVP_OK) {
        t = mvhost_launch(program.directory, program.command,
                          info.has_v20 && !info.close_on_exit);
        if (t < 0)
            t = 0;
        else
            mvhost_title(t, program.title);
        if (title != NULL)
            strcpy(title, program.title);
        /* DESQview:  hidden without it (version 1 layouts) */
        if (info.has_v20 && !(info.flags3 & 0x80))
            *shown = 0;
    }
    q->task = t;
    q->state = 2;
    return t;
}

void mvhost_title(unsigned task, const char *title)
{
    static char buf[17];
    union REGS r;
    struct SREGS s;

    strncpy(buf, title, 16);
    buf[16] = '\0';
    segread(&s);
    s.es = s.ds;
    r.x.ax = 0xd70c;
    r.x.bx = task;
    r.x.di = (unsigned)buf;
    int86x(0x2f, &r, &r, &s);
}

int mvhost_owngeom(unsigned task, unsigned *pos, unsigned *size)
{
    union REGS r;

    r.x.ax = 0xd70d;
    r.x.bx = task;
    r.x.cx = 0;
    int86(0x2f, &r, &r);
    if (r.x.ax != 0)
        return 0;
    *pos = r.x.dx;
    *size = r.x.cx;
    return 1;
}
