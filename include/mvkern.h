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

/* Paragraphs of kernel data:  a block of the caller's below the task base
 * (shared by all tasks). */
unsigned mvk_datasize(void);
/* base:  task base segment, 4KB aligned, a free MCB there; kseg:  the
 * kernel data block.  0 or MVE_x. */
int mvk_init(unsigned base, unsigned kseg);
/* Task # or -MVE_x. */
int mvk_create(const char *prog, const char *tail);
/* A task running prog (full path) with tail, also while running (from
 * task 0); a done task's slot is used again. */
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
/* End the task's programs (DOS terminates them, files closed); it is DONE
 * soon after, exit FFh.  0 or MVE_x. */
int mvk_kill(unsigned task);
/* The other tasks now (call while waiting). */
void mvk_yield(void);
/* on:  Alt pressed and released alone switches to task 0 (DESQview). */
void mvk_dvkey(unsigned on);
/* The keys to task (0 or ready), the display unchanged (windows drawn by
 * task 0).  0 or MVE_x. */
int mvk_focus(unsigned task);
unsigned mvk_focused(void);
/* The task's 80x25 text screen into buf (2000 cells, DGROUP); its cursor
 * (row << 8 | column) or 0xffff.  From task 0. */
unsigned mvk_peek(unsigned task, unsigned short *buf);

#endif
