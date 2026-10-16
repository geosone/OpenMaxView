/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "scheduler.h"

static int slot_for_handle(const mv_scheduler *scheduler, unsigned handle,
                           unsigned *slot)
{
    unsigned encoded;

    if (handle == MV_TASK_NONE)
        return 0;
    encoded = handle & 0xffu;
    if (encoded == 0 || encoded > MV_SCHEDULER_TASKS)
        return 0;
    encoded--;
    if (scheduler->tasks[encoded].state == MV_TASK_FREE ||
        scheduler->tasks[encoded].handle != handle)
        return 0;
    if (slot != 0)
        *slot = encoded;
    return 1;
}

static unsigned next_generation(unsigned generation)
{
    generation = (generation + 1u) & 0xffu;
    return generation == 0 ? 1u : generation;
}

void mv_scheduler_init(mv_scheduler *scheduler)
{
    unsigned slot;

    for (slot = 0; slot < MV_SCHEDULER_TASKS; ++slot) {
        scheduler->tasks[slot].handle = MV_TASK_NONE;
        scheduler->tasks[slot].generation = 0;
        scheduler->tasks[slot].state = MV_TASK_FREE;
    }
    scheduler->current = MV_TASK_NONE;
    scheduler->cursor = MV_SCHEDULER_TASKS - 1;
    scheduler->critical_depth = 0;
}

int mv_scheduler_create(mv_scheduler *scheduler, unsigned *handle)
{
    unsigned slot;
    unsigned generation;

    if (handle == 0)
        return 0;
    for (slot = 0; slot < MV_SCHEDULER_TASKS; ++slot) {
        if (scheduler->tasks[slot].state != MV_TASK_FREE)
            continue;
        generation = next_generation(scheduler->tasks[slot].generation);
        scheduler->tasks[slot].generation = generation;
        scheduler->tasks[slot].handle = (generation << 8) | (slot + 1);
        scheduler->tasks[slot].state = MV_TASK_READY;
        *handle = scheduler->tasks[slot].handle;
        return 1;
    }
    return 0;
}

int mv_scheduler_terminate(mv_scheduler *scheduler, unsigned handle)
{
    unsigned slot;

    if (!slot_for_handle(scheduler, handle, &slot))
        return 0;
    if (handle == scheduler->current && scheduler->critical_depth != 0)
        return 0;
    if (handle == scheduler->current)
        scheduler->current = MV_TASK_NONE;
    scheduler->tasks[slot].handle = MV_TASK_NONE;
    scheduler->tasks[slot].state = MV_TASK_FREE;
    return 1;
}

int mv_scheduler_wait(mv_scheduler *scheduler, unsigned handle)
{
    unsigned slot;

    if (!slot_for_handle(scheduler, handle, &slot))
        return 0;
    if (scheduler->tasks[slot].state != MV_TASK_READY &&
        scheduler->tasks[slot].state != MV_TASK_RUNNING)
        return 0;
    if (handle == scheduler->current && scheduler->critical_depth != 0)
        return 0;
    scheduler->tasks[slot].state = MV_TASK_WAITING;
    if (handle == scheduler->current)
        scheduler->current = MV_TASK_NONE;
    return 1;
}

int mv_scheduler_wake(mv_scheduler *scheduler, unsigned handle)
{
    unsigned slot;

    if (!slot_for_handle(scheduler, handle, &slot) ||
        scheduler->tasks[slot].state != MV_TASK_WAITING)
        return 0;
    scheduler->tasks[slot].state = MV_TASK_READY;
    return 1;
}

int mv_scheduler_dispatch(mv_scheduler *scheduler, unsigned *handle)
{
    unsigned slot;
    unsigned offset;

    if (scheduler->critical_depth != 0) {
        if (!slot_for_handle(scheduler, scheduler->current, &slot) ||
            scheduler->tasks[slot].state != MV_TASK_RUNNING)
            return 0;
        if (handle != 0)
            *handle = scheduler->current;
        return 1;
    }
    if (slot_for_handle(scheduler, scheduler->current, &slot) &&
        scheduler->tasks[slot].state == MV_TASK_RUNNING)
        scheduler->tasks[slot].state = MV_TASK_READY;
    scheduler->current = MV_TASK_NONE;

    for (offset = 1; offset <= MV_SCHEDULER_TASKS; ++offset) {
        slot = (scheduler->cursor + offset) % MV_SCHEDULER_TASKS;
        if (scheduler->tasks[slot].state != MV_TASK_READY)
            continue;
        scheduler->tasks[slot].state = MV_TASK_RUNNING;
        scheduler->current = scheduler->tasks[slot].handle;
        scheduler->cursor = slot;
        if (handle != 0)
            *handle = scheduler->current;
        return 1;
    }
    if (handle != 0)
        *handle = MV_TASK_NONE;
    return 0;
}

int mv_scheduler_enter_critical(mv_scheduler *scheduler, unsigned handle)
{
    unsigned slot;

    if (!slot_for_handle(scheduler, handle, &slot) ||
        handle != scheduler->current ||
        scheduler->tasks[slot].state != MV_TASK_RUNNING ||
        scheduler->critical_depth == (unsigned)-1)
        return 0;
    ++scheduler->critical_depth;
    return 1;
}

int mv_scheduler_leave_critical(mv_scheduler *scheduler, unsigned handle)
{
    if (handle != scheduler->current || scheduler->critical_depth == 0)
        return 0;
    --scheduler->critical_depth;
    return 1;
}

unsigned mv_scheduler_current(const mv_scheduler *scheduler)
{
    return scheduler->current;
}

unsigned mv_scheduler_state(const mv_scheduler *scheduler, unsigned handle)
{
    unsigned slot;

    if (!slot_for_handle(scheduler, handle, &slot))
        return MV_TASK_FREE;
    return scheduler->tasks[slot].state;
}

unsigned mv_scheduler_runnable(const mv_scheduler *scheduler)
{
    unsigned slot;
    unsigned count = 0;

    for (slot = 0; slot < MV_SCHEDULER_TASKS; ++slot)
        if (scheduler->tasks[slot].state == MV_TASK_READY ||
            scheduler->tasks[slot].state == MV_TASK_RUNNING)
            ++count;
    return count;
}
