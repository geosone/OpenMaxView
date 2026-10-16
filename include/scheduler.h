/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVIEW_SCHEDULER_H
#define MAXVIEW_SCHEDULER_H

#define MV_SCHEDULER_TASKS 16
#define MV_TASK_NONE       0

#define MV_TASK_FREE       0
#define MV_TASK_READY      1
#define MV_TASK_RUNNING    2
#define MV_TASK_WAITING    3

typedef struct mv_v86_registers {
    unsigned long eax;
    unsigned long ebx;
    unsigned long ecx;
    unsigned long edx;
    unsigned long esi;
    unsigned long edi;
    unsigned long ebp;
    unsigned long esp;
    unsigned long eip;
    unsigned long eflags;
    unsigned cs;
    unsigned ds;
    unsigned es;
    unsigned fs;
    unsigned gs;
    unsigned ss;
    unsigned virtual_pic_mask;
    unsigned pending_interrupts;
} mv_v86_registers;

typedef struct mv_task_slot {
    unsigned handle;
    unsigned generation;
    unsigned state;
    unsigned long page_table;
    mv_v86_registers registers;
} mv_task_slot;

typedef struct mv_scheduler {
    mv_task_slot tasks[MV_SCHEDULER_TASKS];
    unsigned current;
    unsigned cursor;
    unsigned critical_depth;
    unsigned active_context;
} mv_scheduler;

void mv_scheduler_init(mv_scheduler *scheduler);
int mv_scheduler_create(mv_scheduler *scheduler, unsigned *handle);
int mv_scheduler_terminate(mv_scheduler *scheduler, unsigned handle);
int mv_scheduler_wait(mv_scheduler *scheduler, unsigned handle);
int mv_scheduler_wake(mv_scheduler *scheduler, unsigned handle);
int mv_scheduler_dispatch(mv_scheduler *scheduler, unsigned *handle);
int mv_scheduler_enter_critical(mv_scheduler *scheduler, unsigned handle);
int mv_scheduler_leave_critical(mv_scheduler *scheduler, unsigned handle);
unsigned mv_scheduler_current(const mv_scheduler *scheduler);
unsigned mv_scheduler_state(const mv_scheduler *scheduler, unsigned handle);
unsigned mv_scheduler_runnable(const mv_scheduler *scheduler);
int mv_scheduler_save_registers(mv_scheduler *scheduler, unsigned handle,
                                const mv_v86_registers *registers);
int mv_scheduler_load_registers(const mv_scheduler *scheduler,
                                unsigned handle,
                                mv_v86_registers *registers);
int mv_scheduler_attach_context(mv_scheduler *scheduler, unsigned handle,
                                unsigned long page_table);
int mv_scheduler_detach_context(mv_scheduler *scheduler, unsigned handle,
                                unsigned long page_table);
unsigned long mv_scheduler_context(const mv_scheduler *scheduler,
                                   unsigned handle);
int mv_scheduler_mark_context_active(mv_scheduler *scheduler,
                                     unsigned handle,
                                     unsigned long page_table);
int mv_scheduler_mark_context_inactive(mv_scheduler *scheduler,
                                       unsigned handle,
                                       unsigned long page_table);
unsigned mv_scheduler_active_context(const mv_scheduler *scheduler);

#endif
