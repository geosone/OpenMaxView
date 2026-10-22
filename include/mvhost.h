/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVHOST_H
#define MVHOST_H

/* The multitasking core in a small model DOS program (MVRUN, MAXVIEW):
 * the kernel data in a DOS block, the task base (4KB aligned) at the
 * largest free block above it, then mvk_init; ntask slots (task 0
 * included; 0:  8).  0 or MVE_x. */
int mvhost_init(unsigned ntask);
const char *mvhost_error(int e);

#endif
