/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVHOST_H
#define MVHOST_H

/* The multitasking core in a small model DOS program (MVRUN, MAXVIEW):
 * our memory block ends 64KB behind DGROUP, on a 4KB boundary (the task
 * base), then mvk_init.  0 or MVE_x. */
int mvhost_init(void);
const char *mvhost_error(int e);

#endif
