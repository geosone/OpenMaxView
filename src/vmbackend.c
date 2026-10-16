/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "vmtask.h"

void mv_vm_backend_open386max(mv_vm_backend_ops *backend)
{
    backend->clone_context = odq_max_context_clone;
    backend->release_context = odq_max_context_release;
    backend->activate_context = odq_max_context_activate;
    backend->restore_root = odq_max_context_restore;
}
