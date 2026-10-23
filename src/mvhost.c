/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Setting up the multitasking core (kernel/mvkern.asm) in a small model
 * program:  the task base right behind our DGROUP. */
#include <dos.h>

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
