/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVKERN_H
#define MVKERN_H

/* Open MaxView multitasking core (kernel/mvkern.asm). */

#define MVK_MAXTASK 8

#define MVK_FREE  0
#define MVK_READY 1
#define MVK_DONE  2

#define MVE_NOQPI 1
#define MVE_BASE  2
#define MVE_SDA   3
#define MVE_FULL  4
#define MVE_MEM   5
#define MVE_IRQ   6
#define MVE_STATE 7

/* base:  task base segment, 4KB aligned, a free MCB there.  0 or MVE_x. */
int mvk_init(unsigned base);
/* A task running prog (full path) with tail.  Task # or -MVE_x. */
int mvk_create(const char *prog, const char *tail);
/* Start switching every quantum timer ticks.  0 or MVE_x. */
int mvk_start(unsigned quantum);
/* Stop switching, free the tasks (from task 0, the caller). */
void mvk_stop(void);
unsigned mvk_state(unsigned task);
unsigned mvk_exit(unsigned task);
unsigned long mvk_switches(void);
unsigned mvk_base(void);
/* The task shown on the screen and getting the keys (from task 0); the
 * user switches with Ctrl+Alt+1..9 (Ctrl+Alt+0:  task 0).  0 or MVE_x. */
int mvk_setfg(unsigned task);
unsigned mvk_fg(void);

#endif
