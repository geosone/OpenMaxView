/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVKERN_H
#define MVKERN_H

/* Open MaxView multitasking core (kernel/mvkern.asm). */

#define MVK_MAXTASK 30

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
#define MVE_DVST  8

/* Paragraphs of kernel data for ntask task slots (task 0, the caller,
 * included; 2..MVK_MAXTASK, 0:  8):  a block of the caller's below the task
 * base (shared by all tasks), 1.7KB a slot; mvk_init then has that many.
 * Each task also keeps 4.3KB (its CDS and SDA) in its own memory. */
unsigned mvk_datasize(unsigned ntask);
/* base:  task base segment, 4KB aligned, a free MCB there; kseg:  the
 * kernel data block.  0 or MVE_x. */
int mvk_init(unsigned base, unsigned kseg);
/* Task # or -MVE_x. */
int mvk_create(const char *prog, const char *tail);
/* A task running prog (full path) with tail, also while running (from
 * task 0); a done task's slot is used again. */
/* Start switching every quantum timer ticks.  0 or MVE_x. */
int mvk_start(unsigned quantum);
/* Time slices in ticks:  fg for the task with the keys, bg for the others
 * (0:  unchanged); mvk_start sets 3 * quantum and quantum (DESQview's
 * defaults are 9 and 3). */
void mvk_tune(unsigned fg, unsigned bg);
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
/* on:  the task in front shows DESQview's colours for its window number
 * (1 blue on cyan, 2 on brown, 3 on red, 4 on green, then again:  its
 * black and grey are the window's), through the VGA palette; task 0 the
 * standard ones.  Default off:  programs show their own colours. */
void mvk_dvcolors(unsigned on);
/* Window n's colours (0-3:  windows 1-4, then again) for mvk_dvcolors,
 * attr background << 4 | foreground (DESQview's 31h 61h 47h 21h by
 * default); for the task brought in front next. */
void mvk_wincolor(unsigned n, unsigned attr);
/* on:  a task printing (INT 17h) to LPT1-3 waits while another task
 * printed to it in the last 3 seconds (DESQview's Manage printer
 * contention; default off). */
void mvk_prncont(unsigned on);
/* Learn's quoting character c (0:  none):  the task with the keys does
 * not get it, its next key is not a script key (twice:  the character). */
void mvk_quote(unsigned c);
/* The keys to task (0 or ready), the display unchanged (windows drawn by
 * task 0).  0 or MVE_x. */
int mvk_focus(unsigned task);
unsigned mvk_focused(void);
/* on:  task (1..) and its subtasks run only while it has the keys
 * (DESQview's Freeze, Put Aside).  0 or MVE_x. */
int mvk_freeze(unsigned task, unsigned on);
/* off:  while task (1..) has the keys the others wait (DESQview's "Share
 * CPU" in the foreground; default on).  0 or MVE_x. */
int mvk_share(unsigned task, unsigned on);
/* The task's 80x25 text screen into buf (2000 cells, DGROUP); its cursor
 * (row << 8 | column) or 0xffff.  From task 0. */
unsigned mvk_peek(unsigned task, unsigned short *buf);
/* key (scan code << 8 | char) at the end of the task's key buffer, as if
 * typed; 0, 1:  the buffer is full (again later) or MVE_x.  From task 0. */
int mvk_putkey(unsigned task, unsigned key);
/* Learn:  the script keys (up to 16) taken from the keys of the task with
 * them, and its keys recorded (rec); mvk_keyget:  the next event (0 none, 1
 * a key recorded, 2 a script key pressed, 3 the Learn key Shift+Alt), its
 * key (scan code << 8 | char) in *key */
void mvk_keytap(const unsigned *keys, unsigned n, unsigned rec);
/* Swapping out (by the host, from task 0):  mvk_swapcheck gives the number
 * of task's private pages (4KB) when it may be swapped out now (held,
 * neither the foreground nor the keys', no IRQ or subtask of its own),
 * else 0; mvk_pageio copies page (| 0x8000:  back into it) to the 4KB at
 * seg:off (memory below the task base); mvk_release frees its pages (it
 * never runs then), mvk_reclaim gets pages again (MVE_MEM:  none free) */
unsigned mvk_swapcheck(unsigned task);
int mvk_pageio(unsigned task, unsigned page, unsigned seg, unsigned off);
int mvk_release(unsigned task);
int mvk_reclaim(unsigned task);
unsigned mvk_keyget(unsigned *key);

#endif
