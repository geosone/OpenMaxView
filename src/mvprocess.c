/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <string.h>

#include "mvprocess.h"

int mv_process_build(const odq_program *program,
                     mv_process_descriptor *descriptor)
{
    unsigned requested = 0;
    const odq_process_profile *profile;

    if (program == 0 || descriptor == 0 || !odq_program_valid(program))
        return 0;
    profile = &program->profile;
    if (program->min_kb != 0 || program->max_kb != 0)
        requested |= MV_PROCESS_CONVENTIONAL;
    if (profile->system_kb != 0 || profile->extra_system != 0)
        requested |= MV_PROCESS_SYSTEM;
    if (profile->script_bytes != 0)
        requested |= MV_PROCESS_SCRIPT;
    if (profile->idle_polls != 0)
        requested |= MV_PROCESS_IDLE;
    if (profile->max_ems_kb != 0)
        requested |= MV_PROCESS_EMS;
    if (profile->rows != 0 || profile->columns != 0 ||
        profile->text_pages != 0)
        requested |= MV_PROCESS_TEXT_VIDEO;
    if (profile->graphics_pages != 0)
        requested |= MV_PROCESS_GRAPHICS;
    if (profile->serial_ports != 0)
        requested |= MV_PROCESS_SERIAL;
    if (profile->protection != 0)
        requested |= MV_PROCESS_PROTECTION;
    if (profile->flags1 != 0 || profile->flags2 != 0 ||
        profile->flags3 != 0 || profile->flags4 != 0)
        requested |= MV_PROCESS_RAW_FLAGS;

    memset(descriptor, 0, sizeof(*descriptor));
    descriptor->min_kb = program->min_kb;
    descriptor->max_kb = program->max_kb;
    descriptor->requested = requested;
    descriptor->profile = *profile;
    return 1;
}

int mv_process_bind(mv_process_descriptor *descriptor,
                    const mv_scheduler *scheduler, unsigned task_handle)
{
    if (descriptor == 0 || scheduler == 0 ||
        descriptor->task_handle != MV_TASK_NONE ||
        mv_scheduler_state(scheduler, task_handle) == MV_TASK_FREE)
        return 0;
    descriptor->task_handle = task_handle;
    return 1;
}

int mv_process_unbind(mv_process_descriptor *descriptor,
                      unsigned task_handle)
{
    if (descriptor == 0 || task_handle == MV_TASK_NONE ||
        descriptor->task_handle != task_handle)
        return 0;
    descriptor->task_handle = MV_TASK_NONE;
    descriptor->enforced = 0;
    return 1;
}

int mv_process_enable(mv_process_descriptor *descriptor, unsigned features)
{
    if (descriptor == 0 || (features & ~MV_PROCESS_ALL) != 0 ||
        (features & ~descriptor->requested) != 0)
        return 0;
    descriptor->enforced |= features;
    return 1;
}

unsigned mv_process_pending(const mv_process_descriptor *descriptor)
{
    if (descriptor == 0)
        return 0;
    return descriptor->requested & ~descriptor->enforced;
}
