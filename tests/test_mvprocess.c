/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mvprocess.h"

static void fail(const char *message)
{
    fprintf(stderr, "process descriptor test failed: %s\n", message);
    exit(1);
}

static void require(int condition, const char *message)
{
    if (!condition)
        fail(message);
}

int main(void)
{
    odq_program program;
    mv_process_descriptor descriptor;
    mv_scheduler scheduler;
    unsigned task;
    unsigned expected;

    memset(&program, 0, sizeof(program));
    program.hotkey = 'T';
    strcpy(program.title, "Profile test");
    strcpy(program.command, "TEST.COM");
    program.min_kb = 128;
    program.max_kb = 640;
    program.profile.version = ODQ_PROFILE_VERSION;
    program.profile.system_kb = 4;
    program.profile.script_bytes = 1000;
    program.profile.idle_polls = 7;
    program.profile.max_ems_kb = 2048;
    program.profile.rows = 25;
    program.profile.columns = 80;
    program.profile.text_pages = 2;
    program.profile.graphics_pages = 1;
    program.profile.serial_ports = 3;
    program.profile.protection = 0x9a;
    program.profile.flags2 = 0x34;

    expected = MV_PROCESS_CONVENTIONAL | MV_PROCESS_SYSTEM |
               MV_PROCESS_SCRIPT | MV_PROCESS_IDLE | MV_PROCESS_EMS |
               MV_PROCESS_TEXT_VIDEO | MV_PROCESS_GRAPHICS |
               MV_PROCESS_SERIAL | MV_PROCESS_PROTECTION |
               MV_PROCESS_RAW_FLAGS;
    require(mv_process_build(&program, &descriptor), "build failed");
    require(descriptor.requested == expected && descriptor.enforced == 0 &&
            mv_process_pending(&descriptor) == expected,
            "requirements were not classified");
    require(descriptor.min_kb == 128 && descriptor.max_kb == 640 &&
            descriptor.profile.serial_ports == 3,
            "profile values were not retained");

    require(mv_process_enable(&descriptor,
                              MV_PROCESS_CONVENTIONAL | MV_PROCESS_EMS),
            "valid feature enable failed");
    require(mv_process_pending(&descriptor) ==
            (expected & ~(MV_PROCESS_CONVENTIONAL | MV_PROCESS_EMS)),
            "pending feature mask is wrong");
    require(!mv_process_enable(&descriptor, 0x8000),
            "unknown feature was enabled");

    mv_scheduler_init(&scheduler);
    require(mv_scheduler_create(&scheduler, &task), "task creation failed");
    require(mv_process_bind(&descriptor, &scheduler, task), "bind failed");
    require(!mv_process_bind(&descriptor, &scheduler, task),
            "duplicate bind succeeded");
    require(!mv_process_unbind(&descriptor, task + 1),
            "foreign unbind succeeded");
    require(mv_process_unbind(&descriptor, task), "unbind failed");
    require(descriptor.task_handle == MV_TASK_NONE &&
            descriptor.enforced == 0 &&
            mv_process_pending(&descriptor) == expected,
            "unbind did not reset runtime enforcement");

    program.profile.version = 2;
    require(!mv_process_build(&program, &descriptor),
            "invalid profile was accepted");
    require(!mv_process_bind(&descriptor, &scheduler, 0xffff),
            "stale task handle was accepted");

    puts("process descriptor tests passed");
    return 0;
}
