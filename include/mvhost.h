/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MVHOST_H
#define MVHOST_H

/* The multitasking core in a small model DOS program (MVRUN, MAXVIEW):
 * the kernel data in a DOS block, the task base (4KB aligned) at the
 * largest free block above it, then mvk_init; ntask slots (task 0
 * included; 0:  8).  0 or MVE_x. */
int mvhost_init(unsigned ntask);
const char *mvhost_error(int e);

#define MVE_DIR 9               /* mvhost_launch:  no such directory */

/* A task running command (COMSPEC /C; keep:  /K, the shell stays) in
 * directory (empty:  ours), from task 0.  Task # or -MVE_x. */
int mvhost_launch(const char *directory, const char *command, int keep);
/* Call while waiting:  a task's APP_START (INT 15h AX=102Ch, MAXVTSR asks
 * with its DVP):  its program started by mvhost_launch, the asking task in
 * *from, the DVP's title (39 bytes) in title if not NULL, *shown 0 if its
 * window is hidden (DVP byte 184h bit 7 clear:  not put in front).  The
 * shell stays when the program ends unless the DVP says close on exit
 * (17Ch), as in DESQview.  The new
 * task, 0 if it could not start, -1:  nothing asked. */
int mvhost_appstart(unsigned *from, char *title, int *shown);

#endif
