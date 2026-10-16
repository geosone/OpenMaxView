/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>

#include "vmtask.h"

static unsigned clone_calls;
static unsigned release_calls;
static unsigned activate_calls;
static unsigned restore_calls;
static int allow_clone = 1;
static int allow_release = 1;
static int allow_activate = 1;
static int allow_restore = 1;

static void fail(const char *message)
{
    fprintf(stderr, "VM task test failed: %s\n", message);
    exit(1);
}

static void require(int condition, const char *message)
{
    if (!condition)
        fail(message);
}

static int fake_clone(odq_max_qpi_context *context)
{
    ++clone_calls;
    if (!allow_clone)
        return 0;
    context->page_table = 0x12345678UL;
    return 1;
}

static int fake_release(odq_max_qpi_context *context)
{
    ++release_calls;
    if (!allow_release)
        return 0;
    context->page_table = 0;
    return 1;
}

static int fake_activate(const odq_max_qpi_context *context)
{
    ++activate_calls;
    return allow_activate && context->page_table == 0x12345678UL;
}

static int fake_restore(void)
{
    ++restore_calls;
    return allow_restore;
}

int main(void)
{
    const mv_vm_backend_ops backend = {
        fake_clone, fake_release, fake_activate, fake_restore
    };
    mv_scheduler scheduler;
    mv_vm_task vm;
    unsigned desktop;
    unsigned child;
    unsigned selected;

    mv_scheduler_init(&scheduler);
    mv_vm_task_init(&vm);
    require(mv_scheduler_create(&scheduler, &desktop) &&
            mv_scheduler_create(&scheduler, &child), "task creation failed");
    require(mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == desktop, "desktop dispatch failed");

    require(mv_vm_task_create(&vm, &scheduler, child, &backend),
            "VM context creation failed");
    require(clone_calls == 1 && vm.state == MV_VM_CLONED &&
            mv_scheduler_context(&scheduler, child) == 0x12345678UL,
            "VM context ownership was not recorded");
    require(!mv_vm_task_activate(&vm, &scheduler, &backend),
            "non-current VM task activated");
    require(activate_calls == 0, "invalid activation reached backend");

    require(mv_scheduler_dispatch(&scheduler, &selected) && selected == child,
            "child dispatch failed");
    allow_activate = 0;
    require(!mv_vm_task_activate(&vm, &scheduler, &backend) &&
            mv_scheduler_active_context(&scheduler) == MV_TASK_NONE,
            "failed activation retained the scheduler lock");
    allow_activate = 1;
    require(mv_vm_task_activate(&vm, &scheduler, &backend) &&
            vm.state == MV_VM_ACTIVE && activate_calls == 2,
            "current VM activation failed");
    require(mv_scheduler_active_context(&scheduler) == child,
            "active context was not recorded");
    require(mv_scheduler_dispatch(&scheduler, &selected) && selected == child,
            "active context did not pin its task");
    require(!mv_scheduler_wait(&scheduler, child),
            "active-context task entered wait state");

    allow_restore = 0;
    require(!mv_vm_task_prepare_windows(&vm, &scheduler, &backend),
            "Windows preparation ignored root failure");
    require(vm.state == MV_VM_ACTIVE &&
            mv_scheduler_active_context(&scheduler) == child,
            "failed root verification cleared active state");
    allow_restore = 1;
    require(mv_vm_task_prepare_windows(&vm, &scheduler, &backend) &&
            vm.state == MV_VM_CLONED &&
            mv_scheduler_active_context(&scheduler) == MV_TASK_NONE,
            "Windows preparation did not verify root");
    require(mv_vm_task_prepare_windows(&vm, &scheduler, &backend),
            "inactive clone did not reverify root for Windows");

    require(!mv_vm_task_destroy(&vm, &scheduler, &backend),
            "current VM task was destroyed");
    require(release_calls == 0, "current task release reached backend");
    require(mv_scheduler_wait(&scheduler, child), "child wait failed");
    require(mv_scheduler_dispatch(&scheduler, &selected) &&
            selected == desktop, "desktop redispatch failed");

    allow_release = 0;
    require(!mv_vm_task_destroy(&vm, &scheduler, &backend),
            "release failure was ignored");
    require(vm.state == MV_VM_CLONED &&
            mv_scheduler_context(&scheduler, child) == 0x12345678UL,
            "release failure lost ownership");
    allow_release = 1;
    require(mv_vm_task_destroy(&vm, &scheduler, &backend),
            "VM task destroy failed");
    require(vm.state == MV_VM_EMPTY && release_calls == 2 &&
            mv_scheduler_context(&scheduler, child) == 0,
            "VM task destroy did not clear ownership");
    require(mv_scheduler_terminate(&scheduler, child),
            "clean child termination failed");

    mv_vm_task_init(&vm);
    allow_clone = 0;
    require(!mv_vm_task_create(&vm, &scheduler, desktop, &backend),
            "clone failure was ignored");
    require(vm.state == MV_VM_EMPTY &&
            mv_scheduler_context(&scheduler, desktop) == 0,
            "clone failure left partial ownership");

    puts("VM task lifecycle tests passed");
    return 0;
}
