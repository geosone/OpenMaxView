/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVIEW_SCHEDULER_H
#define MAXVIEW_SCHEDULER_H

#define MV_SCHEDULER_TASKS 16
#define MV_TASK_NONE       0

#define MV_TASK_FREE       0
#define MV_TASK_READY      1
#define MV_TASK_RUNNING    2
#define MV_TASK_WAITING    3

typedef struct mv_task_slot {
    unsigned handle;
    unsigned generation;
    unsigned state;
} mv_task_slot;

typedef struct mv_scheduler {
    mv_task_slot tasks[MV_SCHEDULER_TASKS];
    unsigned current;
    unsigned cursor;
    unsigned critical_depth;
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

#endif
