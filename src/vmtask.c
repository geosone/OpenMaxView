/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "vmtask.h"

static int backend_valid(const mv_vm_backend_ops *backend)
{
    return backend != 0 && backend->clone_context != 0 &&
           backend->release_context != 0 && backend->activate_context != 0 &&
           backend->restore_root != 0;
}

void mv_vm_task_init(mv_vm_task *task)
{
    task->task_handle = MV_TASK_NONE;
    task->state = MV_VM_EMPTY;
    task->context.page_table = 0;
}

int mv_vm_task_create(mv_vm_task *task, mv_scheduler *scheduler,
                      unsigned task_handle, const mv_vm_backend_ops *backend)
{
    odq_max_qpi_context context;

    if (task == 0 || scheduler == 0 || !backend_valid(backend) ||
        task->state != MV_VM_EMPTY ||
        mv_scheduler_state(scheduler, task_handle) == MV_TASK_FREE ||
        mv_scheduler_context(scheduler, task_handle) != 0)
        return 0;
    context.page_table = 0;
    if (!backend->clone_context(&context))
        return 0;
    if (context.page_table == 0) {
        backend->release_context(&context);
        return 0;
    }
    if (!mv_scheduler_attach_context(scheduler, task_handle,
                                     context.page_table)) {
        backend->release_context(&context);
        return 0;
    }
    task->task_handle = task_handle;
    task->state = MV_VM_CLONED;
    task->context = context;
    return 1;
}

int mv_vm_task_activate(mv_vm_task *task, mv_scheduler *scheduler,
                        const mv_vm_backend_ops *backend)
{
    if (task == 0 || scheduler == 0 || !backend_valid(backend) ||
        task->state != MV_VM_CLONED ||
        mv_scheduler_current(scheduler) != task->task_handle ||
        mv_scheduler_active_context(scheduler) != MV_TASK_NONE ||
        mv_scheduler_context(scheduler, task->task_handle) !=
            task->context.page_table)
        return 0;
    if (!mv_scheduler_mark_context_active(scheduler, task->task_handle,
                                          task->context.page_table))
        return 0;
    if (!backend->activate_context(&task->context)) {
        mv_scheduler_mark_context_inactive(scheduler, task->task_handle,
                                           task->context.page_table);
        return 0;
    }
    task->state = MV_VM_ACTIVE;
    return 1;
}

int mv_vm_task_restore_root(mv_vm_task *task, mv_scheduler *scheduler,
                            const mv_vm_backend_ops *backend)
{
    if (task == 0 || scheduler == 0 || !backend_valid(backend) ||
        task->state != MV_VM_ACTIVE ||
        mv_scheduler_active_context(scheduler) != task->task_handle)
        return 0;
    if (!backend->restore_root())
        return 0;
    if (!mv_scheduler_mark_context_inactive(scheduler, task->task_handle,
                                            task->context.page_table))
        return 0;
    task->state = MV_VM_CLONED;
    return 1;
}

int mv_vm_task_prepare_windows(mv_vm_task *task, mv_scheduler *scheduler,
                               const mv_vm_backend_ops *backend)
{
    if (task == 0 || scheduler == 0 || !backend_valid(backend) ||
        (task->state != MV_VM_CLONED && task->state != MV_VM_ACTIVE))
        return 0;

    /* Always perform the verified root transition. An inactive clone alone
     * is not evidence that another layer did not change QPI context 08h. */
    if (task->state == MV_VM_ACTIVE)
        return mv_vm_task_restore_root(task, scheduler, backend);
    if (mv_scheduler_active_context(scheduler) != MV_TASK_NONE)
        return 0;
    if (!backend->restore_root())
        return 0;
    return 1;
}

int mv_vm_task_destroy(mv_vm_task *task, mv_scheduler *scheduler,
                       const mv_vm_backend_ops *backend)
{
    if (task == 0 || scheduler == 0 || !backend_valid(backend) ||
        (task->state != MV_VM_CLONED && task->state != MV_VM_ACTIVE) ||
        mv_scheduler_context(scheduler, task->task_handle) !=
            task->context.page_table)
        return 0;
    if (task->state == MV_VM_ACTIVE &&
        !mv_vm_task_restore_root(task, scheduler, backend))
        return 0;
    if (mv_scheduler_current(scheduler) == task->task_handle)
        return 0;
    if (!backend->release_context(&task->context))
        return 0;
    if (!mv_scheduler_detach_context(scheduler, task->task_handle,
                                     mv_scheduler_context(scheduler,
                                                          task->task_handle)))
        return 0;
    mv_vm_task_init(task);
    return 1;
}
