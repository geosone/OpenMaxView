/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>

#include "scheduler.h"

static void fail(const char *message)
{
    fprintf(stderr, "scheduler test failed: %s\n", message);
    exit(1);
}

static void require(int condition, const char *message)
{
    if (!condition)
        fail(message);
}

int main(void)
{
    mv_scheduler scheduler;
    unsigned handles[MV_SCHEDULER_TASKS];
    unsigned stale;
    unsigned selected;
    unsigned index;
    mv_v86_registers saved;
    mv_v86_registers loaded;

    mv_scheduler_init(&scheduler);
    require(mv_scheduler_current(&scheduler) == MV_TASK_NONE,
            "initial task is not empty");
    require(!mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == MV_TASK_NONE, "empty scheduler dispatched a task");

    for (index = 0; index < MV_SCHEDULER_TASKS; ++index)
        require(mv_scheduler_create(&scheduler, &handles[index]),
                "task table filled early");
    require(!mv_scheduler_create(&scheduler, &selected),
            "task table accepted an extra task");
    require(mv_scheduler_runnable(&scheduler) == MV_SCHEDULER_TASKS,
            "runnable count is wrong");

    for (index = 0; index < MV_SCHEDULER_TASKS; ++index) {
        require(mv_scheduler_dispatch(&scheduler, &selected),
                "round-robin dispatch failed");
        require(selected == handles[index], "round-robin order is wrong");
        require(mv_scheduler_state(&scheduler, selected) == MV_TASK_RUNNING,
                "selected task is not running");
    }
    require(mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == handles[0], "round-robin did not wrap");

    require(mv_scheduler_enter_critical(&scheduler, handles[0]),
            "critical entry failed");
    require(mv_scheduler_enter_critical(&scheduler, handles[0]),
            "nested critical entry failed");
    require(mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == handles[0], "critical task was preempted");
    require(!mv_scheduler_wait(&scheduler, handles[0]),
            "critical task entered wait state");
    require(!mv_scheduler_terminate(&scheduler, handles[0]),
            "critical task was terminated");
    require(mv_scheduler_leave_critical(&scheduler, handles[0]),
            "nested critical exit failed");
    require(mv_scheduler_leave_critical(&scheduler, handles[0]),
            "critical exit failed");
    require(!mv_scheduler_leave_critical(&scheduler, handles[0]),
            "critical depth underflow accepted");

    require(mv_scheduler_wait(&scheduler, handles[0]),
            "running task did not wait");
    require(mv_scheduler_state(&scheduler, handles[0]) == MV_TASK_WAITING,
            "waiting state missing");
    require(mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == handles[1], "wait did not select next task");
    require(mv_scheduler_wake(&scheduler, handles[0]), "wake failed");
    require(!mv_scheduler_wake(&scheduler, handles[0]),
            "ready task accepted duplicate wake");

    stale = handles[5];
    require(mv_scheduler_terminate(&scheduler, stale), "terminate failed");
    require(mv_scheduler_state(&scheduler, stale) == MV_TASK_FREE,
            "terminated handle remains valid");
    require(mv_scheduler_create(&scheduler, &handles[5]),
            "freed slot was not reusable");
    require(handles[5] != stale, "reused slot retained stale handle");
    require(!mv_scheduler_wait(&scheduler, stale) &&
            !mv_scheduler_terminate(&scheduler, stale),
            "stale handle was accepted");

    require(!mv_scheduler_enter_critical(&scheduler, handles[2]),
            "non-current task entered critical section");
    require(!mv_scheduler_leave_critical(&scheduler, handles[2]),
            "non-current task left critical section");

    saved.eax = 0x12345678UL;
    saved.ebx = 0x87654321UL;
    saved.ecx = 3;
    saved.edx = 4;
    saved.esi = 5;
    saved.edi = 6;
    saved.ebp = 7;
    saved.esp = 8;
    saved.eip = 9;
    saved.eflags = 0x00020202UL;
    saved.cs = 10;
    saved.ds = 11;
    saved.es = 12;
    saved.fs = 13;
    saved.gs = 14;
    saved.ss = 15;
    saved.virtual_pic_mask = 0xfffe;
    saved.pending_interrupts = 1;
    require(mv_scheduler_save_registers(&scheduler, handles[2], &saved),
            "register save failed");
    require(mv_scheduler_load_registers(&scheduler, handles[2], &loaded),
            "register load failed");
    require(loaded.eax == saved.eax && loaded.ebx == saved.ebx &&
            loaded.eip == saved.eip && loaded.eflags == saved.eflags &&
            loaded.cs == saved.cs && loaded.ss == saved.ss &&
            loaded.virtual_pic_mask == saved.virtual_pic_mask &&
            loaded.pending_interrupts == saved.pending_interrupts,
            "register image changed");

    require(mv_scheduler_attach_context(&scheduler, handles[2],
                                        0x12345678UL),
            "context attach failed");
    require(!mv_scheduler_attach_context(&scheduler, handles[2],
                                         0x87654321UL),
            "duplicate context attach accepted");
    require(mv_scheduler_context(&scheduler, handles[2]) == 0x12345678UL,
            "attached context is wrong");
    require(!mv_scheduler_terminate(&scheduler, handles[2]),
            "task with a context was terminated");
    require(mv_scheduler_detach_context(&scheduler, handles[2],
                                        0x12345678UL),
            "context detach failed");
    require(mv_scheduler_context(&scheduler, handles[2]) == 0,
            "detached context remains visible");

    puts("scheduler tests passed");
    return 0;
}
