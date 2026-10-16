/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVIEW_VMTASK_H
#define MAXVIEW_VMTASK_H

#include "maxbackend.h"
#include "scheduler.h"

#define MV_VM_EMPTY   0
#define MV_VM_CLONED  1
#define MV_VM_ACTIVE  2

typedef struct mv_vm_backend_ops {
    int (*clone_context)(odq_max_qpi_context *context);
    int (*release_context)(odq_max_qpi_context *context);
    int (*activate_context)(const odq_max_qpi_context *context);
    int (*restore_root)(void);
} mv_vm_backend_ops;

typedef struct mv_vm_task {
    unsigned task_handle;
    unsigned state;
    odq_max_qpi_context context;
} mv_vm_task;

void mv_vm_backend_open386max(mv_vm_backend_ops *backend);
void mv_vm_task_init(mv_vm_task *task);
int mv_vm_task_create(mv_vm_task *task, mv_scheduler *scheduler,
                      unsigned task_handle, const mv_vm_backend_ops *backend);
int mv_vm_task_activate(mv_vm_task *task, mv_scheduler *scheduler,
                        const mv_vm_backend_ops *backend);
int mv_vm_task_restore_root(mv_vm_task *task, mv_scheduler *scheduler,
                            const mv_vm_backend_ops *backend);
int mv_vm_task_prepare_windows(mv_vm_task *task, mv_scheduler *scheduler,
                               const mv_vm_backend_ops *backend);
int mv_vm_task_destroy(mv_vm_task *task, mv_scheduler *scheduler,
                       const mv_vm_backend_ops *backend);

#endif
