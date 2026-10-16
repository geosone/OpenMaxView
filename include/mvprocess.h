/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVIEW_PROCESS_H
#define MAXVIEW_PROCESS_H

#include "catalog.h"
#include "scheduler.h"

#define MV_PROCESS_CONVENTIONAL 0x0001
#define MV_PROCESS_SYSTEM       0x0002
#define MV_PROCESS_SCRIPT       0x0004
#define MV_PROCESS_IDLE         0x0008
#define MV_PROCESS_EMS          0x0010
#define MV_PROCESS_TEXT_VIDEO   0x0020
#define MV_PROCESS_GRAPHICS     0x0040
#define MV_PROCESS_SERIAL       0x0080
#define MV_PROCESS_PROTECTION   0x0100
#define MV_PROCESS_RAW_FLAGS    0x0200
#define MV_PROCESS_ALL          0x03ff

typedef struct mv_process_descriptor {
    unsigned task_handle;
    unsigned min_kb;
    unsigned max_kb;
    unsigned requested;
    unsigned enforced;
    odq_process_profile profile;
} mv_process_descriptor;

int mv_process_build(const odq_program *program,
                     mv_process_descriptor *descriptor);
int mv_process_bind(mv_process_descriptor *descriptor,
                    const mv_scheduler *scheduler, unsigned task_handle);
int mv_process_unbind(mv_process_descriptor *descriptor,
                      unsigned task_handle);
int mv_process_enable(mv_process_descriptor *descriptor, unsigned features);
unsigned mv_process_pending(const mv_process_descriptor *descriptor);

#endif
