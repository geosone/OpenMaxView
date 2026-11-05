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
/* The program mvhost_appstart last started (its DVP's settings), NULL:
 * none */
const struct odq_program *mvhost_approgram(void);
/* The title of task's window (MAXVTSR, INT 2Fh D70Ch:  up to 16
 * characters), as DESQview's window title. */
void mvhost_title(unsigned task, const char *title);
/* Task's own window sized (MAXVTSR, INT 2Fh D70Dh):  1, *pos its contents'
 * place (row << 8 | column) on the task's screen, *size rows << 8 |
 * columns; else 0. */
int mvhost_owngeom(unsigned task, unsigned *pos, unsigned *size);
/* The notifications task's window asked for (MAXVTSR, INT 2Fh D70Eh:  its
 * manager stream's 40h-51h):  bit N event 40h + N (MVN_*); 0 without
 * MAXVTSR. */
#define MVN_CLOSE (1ul << 0x06)
#define MVN_HELP  (1ul << 0x08)
#define MVN_VIDEO (1ul << 0x0c)
#define MVN_CUT   (1ul << 0x0d)
#define MVN_COPY  (1ul << 0x0e)
#define MVN_PASTE (1ul << 0x0f)
#define MVN_DVKEY (1ul << 0x10)
#define MVN_DVDONE (1ul << 0x11)
unsigned long mvhost_notify(unsigned task);
/* The menu functions task's window disallowed (manager stream 20h-33h,
 * DESQview's win_disallow):  bit N ALW_* N (MVD_*); 0 without MAXVTSR */
#define MVD_HMOVE  (1ul << 0x00)
#define MVD_VMOVE  (1ul << 0x01)
#define MVD_HSIZE  (1ul << 0x02)
#define MVD_VSIZE  (1ul << 0x03)
#define MVD_HSCROLL (1ul << 0x04)
#define MVD_VSCROLL (1ul << 0x05)
#define MVD_CLOSE  (1ul << 0x06)
#define MVD_HIDE   (1ul << 0x07)
#define MVD_FREEZE (1ul << 0x08)
#define MVD_COPY   (1ul << 0x0e)
#define MVD_DVMENU (1ul << 0x10)
#define MVD_SWITCH (1ul << 0x11)
#define MVD_OPEN   (1ul << 0x12)
#define MVD_QUIT   (1ul << 0x13)
unsigned long mvhost_deny(unsigned task);
/* The pointer objects of task (0xffff:  the full screen's) take the mouse,
 * its window's contents at pos (row << 8 | column), size rows << 8 |
 * columns, showing its screen from view (row << 8 | column) (MAXVTSR,
 * INT 2Fh D712h) */
void mvhost_mouse(unsigned task, unsigned pos, unsigned size, unsigned view);
/* A notification message (len bytes, up to 128) into task's own mailbox
 * (MAXVTSR, INT 2Fh D70Fh), as DESQview sends them (handle:  its window's
 * handle put in bytes 1-4):  1, else 0. */
int mvhost_note(unsigned task, const void *msg, unsigned len, int handle);
/* Paste's window for task:  rows x cols characters at text, a window object
 * of its own, not shown, READ gives them (MAXVTSR, INT 2Fh D713h); its
 * handle's segment, 0:  none */
unsigned mvhost_clip(unsigned task, unsigned rows, unsigned cols,
                     const char __far *text);
/* Setup's mouse for DESQview's pointers and select fields (MAXVTSR, INT
 * 2Fh D714h):  bit 0 none, bit 1 left-handed (the buttons swapped) */
void mvhost_mouseopt(unsigned options);

#endif
