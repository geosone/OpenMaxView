/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <dos.h>
#include <stdio.h>
#include <string.h>

#include "maxbackend.h"
#include "odqapi.h"

typedef struct far_block {
    unsigned segment;
    unsigned offset;
} far_block;

static int allocate_block(unsigned function, unsigned bytes,
                          far_block *block)
{
    union REGS inregs, outregs;
    struct SREGS segreg;

    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = function;
    inregs.x.bx = bytes;
    int86x(0x15, &inregs, &outregs, &segreg);
    block->segment = segreg.es;
    block->offset = outregs.x.di;
    return outregs.x.ax == 0 &&
           (block->segment != 0 || block->offset != 0);
}

static int release_block(unsigned function, const far_block *block)
{
    union REGS inregs, outregs;
    struct SREGS segreg;

    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = function;
    inregs.x.di = block->offset;
    segreg.es = block->segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    return outregs.x.ax == 0;
}

static int common_status(unsigned expected_free)
{
    union REGS inregs, outregs;

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_COMMON_STATUS;
    int86(0x15, &inregs, &outregs);
    return outregs.x.bx == expected_free &&
           outregs.x.cx == (expected_free ? ODQ_MEMORY_SLOT_SIZE : 0) &&
           outregs.x.dx == ODQ_COMMON_SLOT_COUNT * ODQ_MEMORY_SLOT_SIZE;
}

static int query_state(unsigned expected_depth, unsigned *video_segment)
{
    union REGS inregs, outregs;

    inregs.x.ax = ODQ_MUX_INFO;
    int86(0x2f, &inregs, &outregs);
    if (outregs.x.bx != ODQ_CAPABILITIES ||
        outregs.x.cx != expected_depth)
        return 0;
    *video_segment = outregs.x.dx;
    inregs.x.ax = ODQ_MUX_CAPS2;
    int86(0x2f, &inregs, &outregs);
    return outregs.x.bx == ODQ_CAPABILITIES2 &&
           outregs.x.cx == 0 && outregs.x.dx == 0;
}

static int query_task(unsigned expected_level, unsigned expected_flags)
{
    union REGS inregs, outregs;

    inregs.x.ax = ODQ_MUX_TASK_INFO;
    int86(0x2f, &inregs, &outregs);
    return outregs.x.bx == expected_level && outregs.x.cx == 1 &&
           outregs.x.dx == expected_flags;
}

int main(void)
{
    union REGS inregs, outregs;
    struct SREGS segreg;
    unsigned video_segment = 0;
    unsigned task_segment;
    unsigned enumerated_segment;
    unsigned buffer_segment;
    unsigned i;
    unsigned char window_info[ODQ_WININFO_SIZE];
    char install_path[ODQ_DV_PATH_SIZE];
    far_block system_blocks[ODQ_SYSTEM_SLOT_COUNT];
    far_block common_block;
    far_block failed_block;
    unsigned char far *memory;
    volatile unsigned far *status_line;
    unsigned saved_status_0;
    unsigned saved_status_1;
    odq_max_backend_info backend;

    inregs.x.ax = ODQ_MUX_RESET;
    int86(0x2f, &inregs, &outregs);

    inregs.x.ax = 0x2b01;
    inregs.x.cx = 0x4445;
    inregs.x.dx = 0x5351;
    int86(0x21, &inregs, &outregs);
    if (outregs.h.al == 0xff) {
        puts("No DESQview-compatible API detected.");
        return 1;
    }
    printf("DESQview-compatible API version %u.%02X detected.\n",
           outregs.x.bx >> 8, outregs.x.bx & 0xff);

    memset(install_path, 0xff, sizeof(install_path));
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_GET_PATH;
    inregs.x.di = FP_OFF(install_path);
    segreg.es = FP_SEG(install_path);
    int86x(0x15, &inregs, &outregs, &segreg);
    if (install_path[ODQ_DV_PATH_SIZE - 1] != '\0' ||
        stricmp(install_path, "C:\\BUILD") != 0) {
        printf("GETDVPATH failed: %s\n", install_path);
        return 38;
    }
    puts("Resident installation-path API passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_GET_VERSION;
    inregs.x.bx = 0;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != 0x0a01) {
        puts("TopView-compatible GETVER identity failed.");
        return 27;
    }
    puts("TopView-compatible GETVER identity passed.");

    inregs.x.ax = ODQ_DVC_PAUSE;
    int86(0x15, &inregs, &outregs);
    puts("PAUSE call returned successfully.");

    inregs.x.ax = ODQ_DVC_APP_NUMBER;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != 1 ||
        !query_task(0x0100, ODQ_TASK_JUSTIFY)) {
        puts("Foreground task defaults failed.");
        return 2;
    }
    puts("Foreground APPNUM and task defaults passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_KEYBOARD_MOUSE;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.bl != 0) {
        puts("Default keyboard-mouse mode failed.");
        return 52;
    }
    inregs.x.ax = ODQ_DVC_KEYBOARD_MOUSE;
    inregs.h.bl = 1;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_KEYBOARD_MOUSE;
    inregs.h.bl = 0;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.bl != 1) {
        puts("Keyboard-mouse enable/query failed.");
        return 53;
    }
    inregs.x.ax = ODQ_DVC_KEYBOARD_MOUSE;
    inregs.h.bl = 2;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_KEYBOARD_MOUSE;
    inregs.h.bl = 0;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.bl != 0) {
        puts("Keyboard-mouse disable/query failed.");
        return 54;
    }
    puts("Foreground keyboard-mouse state API passed.");

    inregs.x.ax = ODQ_DVC_API_LEVEL;
    inregs.x.bx = 0x0230;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != ODQ_DV_VERSION ||
        !query_task(0x0230, ODQ_TASK_JUSTIFY)) {
        puts("APILEVEL negotiation failed.");
        return 3;
    }

    inregs.x.ax = ODQ_DVC_JUSTIFY;
    inregs.h.bl = 0;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_C_STYLE;
    inregs.x.bx = 1;
    int86(0x15, &inregs, &outregs);
    if (!query_task(0x0230, ODQ_TASK_C_STYLE)) {
        puts("JUSTIFY/CSTYLE task state failed.");
        return 4;
    }
    puts("APILEVEL, JUSTIFY and CSTYLE APIs passed.");

    inregs.x.ax = ODQ_DVC_GET_ERROR;
    inregs.h.bl = 0xff;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.bl != 0) {
        puts("Default error-handling mode failed.");
        return 5;
    }
    inregs.x.ax = ODQ_DVC_SET_ERROR;
    inregs.h.bl = 2;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_GET_ERROR;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.bl != 2) {
        puts("SET/GET ERROR API failed.");
        return 6;
    }
    puts("SET/GET ERROR APIs passed.");

    for (i = 0; i < ODQ_SYSTEM_SLOT_COUNT; ++i) {
        unsigned function = i == 0 ? ODQ_DVC_GET_MEMORY_TV :
                                     ODQ_DVC_GET_MEMORY;
        if (!allocate_block(function, ODQ_MEMORY_SLOT_SIZE,
                            &system_blocks[i])) {
            puts("System-memory allocation failed.");
            return 7;
        }
        memory = (unsigned char far *)MK_FP(system_blocks[i].segment,
                                             system_blocks[i].offset);
        if (memory[0] != 0 || memory[ODQ_MEMORY_SLOT_SIZE - 1] != 0) {
            puts("System-memory zero-fill failed.");
            return 8;
        }
        memory[0] = (unsigned char)(i + 1);
    }
    if (allocate_block(ODQ_DVC_GET_MEMORY, 1, &failed_block) ||
        allocate_block(ODQ_DVC_GET_MEMORY,
                       ODQ_MEMORY_SLOT_SIZE + 1, &failed_block)) {
        puts("System-memory bounds check failed.");
        return 9;
    }
    for (i = 0; i < ODQ_SYSTEM_SLOT_COUNT; ++i) {
        unsigned function = i == 0 ? ODQ_DVC_PUT_MEMORY_TV :
                                     ODQ_DVC_PUT_MEMORY;
        if (!release_block(function, &system_blocks[i])) {
            puts("System-memory release failed.");
            return 10;
        }
    }
    puts("Resident system-memory APIs passed.");

    if (!common_status(ODQ_COMMON_SLOT_COUNT * ODQ_MEMORY_SLOT_SIZE) ||
        !allocate_block(ODQ_DVC_GET_COMMON, 64, &common_block) ||
        !common_status((ODQ_COMMON_SLOT_COUNT - 1) *
                       ODQ_MEMORY_SLOT_SIZE)) {
        puts("Common-memory allocation/status failed.");
        return 11;
    }
    memory = (unsigned char far *)MK_FP(common_block.segment,
                                        common_block.offset);
    memory[63] = 0xa5;
    if (memory[63] != 0xa5 ||
        !release_block(ODQ_DVC_PUT_COMMON, &common_block) ||
        !common_status(ODQ_COMMON_SLOT_COUNT * ODQ_MEMORY_SLOT_SIZE)) {
        puts("Common-memory release failed.");
        return 12;
    }
    puts("Resident common-memory APIs passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_CONVENTIONAL_STATUS;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.dx != 640 || outregs.x.bx == 0 ||
        outregs.x.cx == 0 || outregs.x.cx > outregs.x.bx ||
        outregs.x.bx > outregs.x.dx) {
        puts("Conventional-memory status API failed.");
        return 49;
    }
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_EXPANDED_STATUS;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.dx == 0 || outregs.x.bx == 0 ||
        outregs.x.cx != outregs.x.bx || outregs.x.bx > outregs.x.dx) {
        puts("Expanded-memory status API failed.");
        return 50;
    }
    puts("Conventional and expanded memory status APIs passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_GET_FOREGROUND;
    int86(0x15, &inregs, &outregs);
    task_segment = outregs.x.bx;
    if (task_segment == 0) {
        puts("Foreground task handle query failed.");
        return 13;
    }
    memory = (unsigned char far *)MK_FP(task_segment, 0);
    if (*((unsigned far *)(memory + 4)) != 0xfedc ||
        *((unsigned far *)(memory + 6)) != 0) {
        puts("Foreground task object header failed.");
        return 14;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_IS_OBJECT;
    inregs.x.di = 0;
    segreg.es = task_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.bx != 0xffff) {
        puts("ISOBJ rejected the foreground task handle.");
        return 15;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_OBJECT_TYPE;
    inregs.x.di = 0;
    segreg.es = task_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.h.bl != ODQ_OBJECT_WINDOW_TASK) {
        puts("Foreground object type query failed.");
        return 16;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_IS_OBJECT;
    inregs.x.di = 1;
    segreg.es = task_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.bx != 0) {
        puts("ISOBJ accepted an invalid task pointer.");
        return 17;
    }
    puts("Foreground task object APIs passed.");

    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_LOCATE;
    inregs.h.bh = 0;
    inregs.h.bl = 0;
    segreg.es = 0;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (segreg.es != task_segment) {
        puts("LOCATE did not find the foreground window.");
        return 39;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_LOCATE;
    inregs.h.bh = 80;
    inregs.h.bl = 0;
    segreg.es = 0;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (segreg.es != 0) {
        puts("LOCATE accepted an off-screen coordinate.");
        return 40;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_LOCATE;
    inregs.x.bx = 0;
    segreg.es = task_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (segreg.es != 0) {
        puts("LOCATE did not terminate below the foreground window.");
        return 41;
    }

    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_GET_BUFFER;
    inregs.x.bx = task_segment;
    segreg.es = 0;
    int86x(0x15, &inregs, &outregs, &segreg);
    buffer_segment = segreg.es;
    if (buffer_segment == 0 || outregs.x.di != 0 ||
        outregs.x.cx != 80U * 25U * 2U || outregs.h.dl != 0) {
        puts("GETBUF foreground text-buffer query failed.");
        return 42;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_GET_BUFFER;
    inregs.x.bx = 0;
    segreg.es = 0;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (segreg.es != buffer_segment || outregs.x.di != 0 ||
        outregs.x.cx != 80U * 25U * 2U || outregs.h.dl != 0) {
        puts("GETBUF default-window selection failed.");
        return 43;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_GET_BUFFER;
    inregs.x.bx = task_segment + 1;
    segreg.es = 0xffff;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (segreg.es != 0 || outregs.x.di != 0 || outregs.x.cx != 0) {
        puts("GETBUF accepted an invalid task handle.");
        return 44;
    }
    puts("Foreground LOCATE and GETBUF APIs passed.");

    if (!allocate_block(ODQ_DVC_GET_MEMORY, 64, &system_blocks[0])) {
        puts("PROCESSMEM setup allocation failed.");
        return 45;
    }
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_PROCESS_MEMORY;
    inregs.x.dx = task_segment;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != 0 ||
        outregs.x.bx != ODQ_MEMORY_SLOT_SIZE / 16 ||
        outregs.x.cx != ODQ_MEMORY_SLOT_SIZE / 16 || outregs.x.dx == 0) {
        puts("PROCESSMEM foreground accounting failed.");
        return 46;
    }
    if (!release_block(ODQ_DVC_PUT_MEMORY, &system_blocks[0])) {
        puts("PROCESSMEM setup release failed.");
        return 47;
    }
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_PROCESS_MEMORY;
    inregs.x.dx = task_segment + 1;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != 0xffff || outregs.x.bx != 0 ||
        outregs.x.cx != 0 || outregs.x.dx != 0) {
        puts("PROCESSMEM accepted an invalid task handle.");
        return 48;
    }
    puts("Foreground PROCESSMEM API passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_DOS_USER;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != task_segment) {
        puts("DOSUSER did not return the foreground task.");
        return 28;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_OBJECT_NEXT;
    inregs.x.di = 0;
    segreg.es = 0;
    int86x(0x15, &inregs, &outregs, &segreg);
    enumerated_segment = segreg.es;
    if (outregs.x.ax != 0 || enumerated_segment != task_segment ||
        outregs.x.di != 0) {
        puts("OBJNEXT did not enumerate the foreground task.");
        return 29;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_OBJECT_NEXT;
    inregs.x.di = 0;
    segreg.es = enumerated_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.ax != 0 || segreg.es != 0 || outregs.x.di != 0) {
        puts("OBJNEXT did not terminate the foreground object list.");
        return 30;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_OBJECT_NEXT;
    inregs.x.di = 1;
    segreg.es = task_segment;
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.ax != 1) {
        puts("OBJNEXT accepted an invalid object pointer.");
        return 33;
    }
    memset(window_info, 0xff, sizeof(window_info));
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_WINDOW_INFO;
    inregs.x.bx = task_segment;
    inregs.x.dx = ODQ_WININFO_VERSION;
    inregs.x.di = FP_OFF(window_info);
    segreg.es = FP_SEG(window_info);
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.ax != 0 || window_info[0] != ODQ_WININFO_TASK ||
        window_info[1] != 1 ||
        *((unsigned *)(window_info + 2)) != task_segment ||
        *((unsigned *)(window_info + 4)) != 0 || window_info[6] != 0 ||
        *((unsigned *)(window_info + 8)) != ODQ_WININFO_PROCESS ||
        window_info[10] != ODQ_WININFO_FOREGROUND_ONLY) {
        puts("WININFO foreground descriptor failed.");
        return 31;
    }
    memset(window_info, 0xff, sizeof(window_info));
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_WINDOW_INFO;
    inregs.x.bx = 0;
    inregs.x.dx = ODQ_WININFO_VERSION;
    inregs.x.di = FP_OFF(window_info);
    segreg.es = FP_SEG(window_info);
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.ax != 0 ||
        *((unsigned *)(window_info + 2)) != task_segment) {
        puts("WININFO default-task selection failed.");
        return 34;
    }
    memset(&inregs, 0, sizeof(inregs));
    segread(&segreg);
    inregs.x.ax = ODQ_DVC_WINDOW_INFO;
    inregs.x.bx = task_segment;
    inregs.x.dx = 0;
    inregs.x.di = FP_OFF(window_info);
    segreg.es = FP_SEG(window_info);
    int86x(0x15, &inregs, &outregs, &segreg);
    if (outregs.x.ax != 1) {
        puts("WININFO accepted an unsupported format version.");
        return 32;
    }
    puts("Foreground DOSUSER, OBJNEXT and WININFO APIs passed.");

    if (!query_state(0, &video_segment)) {
        puts("Private capability query failed.");
        return 18;
    }
    inregs.x.ax = ODQ_DVC_BEGIN_CRITICAL;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_ENTER_CRITICAL;
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_GET_CRITICAL;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != 2) {
        puts("GETCRIT API failed.");
        return 19;
    }
    inregs.x.ax = ODQ_DVC_PAUSE;
    int86(0x15, &inregs, &outregs);
    if (!query_state(2, &video_segment)) {
        puts("Nested critical-section state failed.");
        return 20;
    }
    inregs.x.ax = ODQ_DVC_END_CRITICAL;
    int86(0x15, &inregs, &outregs);
    int86(0x15, &inregs, &outregs);
    int86(0x15, &inregs, &outregs);
    if (!query_state(0, &video_segment)) {
        puts("Critical-section underflow protection failed.");
        return 21;
    }
    puts("Nested critical-section state passed.");

    inregs.x.ax = ODQ_DVC_SCREEN_INFO;
    int86(0x15, &inregs, &outregs);
    if (outregs.h.ch != 80 || outregs.h.cl != 25 || outregs.h.bl != 3) {
        puts("SCRNINFO API failed (80x25 colour mode expected).");
        return 22;
    }
    inregs.x.ax = ODQ_DVC_VIDEO_NOTIFY;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != 0) {
        puts("VIDEONOTIFY foreground state failed.");
        return 23;
    }
    inregs.x.ax = ODQ_DVC_DVX_VERSION;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.bx != 0) {
        puts("DESQview/X identity guard failed.");
        return 24;
    }
    puts("SCRNINFO and video identity APIs passed.");

    status_line = (volatile unsigned far *)
                  MK_FP(video_segment, 24U * 80U * 2U);
    saved_status_0 = status_line[0];
    saved_status_1 = status_line[1];
    status_line[0] = 0x1e2e;
    status_line[1] = 0x2f2e;
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_DEBUG_POKE;
    inregs.h.bl = 'A';
    int86(0x15, &inregs, &outregs);
    inregs.x.ax = ODQ_DVC_DEBUG_POKE;
    inregs.h.bl = 'B';
    int86(0x15, &inregs, &outregs);
    if (status_line[0] != 0x1e41 || status_line[1] != 0x2f42) {
        status_line[0] = saved_status_0;
        status_line[1] = saved_status_1;
        puts("DBGPOKE physical status-line API failed.");
        return 51;
    }
    status_line[0] = saved_status_0;
    status_line[1] = saved_status_1;
    puts("DBGPOKE physical status-line API passed.");

    segread(&segreg);
    segreg.es = video_segment;
    inregs.h.ah = 0xfe;
    inregs.x.di = 0xffff;
    int86x(0x10, &inregs, &outregs, &segreg);
    if (segreg.es != video_segment || outregs.x.di != 0) {
        puts("Alternate video-buffer query failed.");
        return 25;
    }
    inregs.h.ah = 0xff;
    int86(0x10, &inregs, &outregs);
    puts("Alternate video-buffer API passed.");

    inregs.x.ax = ODQ_DVC_PUSH_KEY;
    inregs.h.bh = 0x2d;
    inregs.h.bl = 'x';
    int86(0x15, &inregs, &outregs);
    inregs.h.ah = 0x00;
    int86(0x16, &inregs, &outregs);
    if (outregs.h.ah != 0x2d || outregs.h.al != 'x') {
        puts("Foreground PUSHKEY API failed.");
        return 26;
    }
    puts("Foreground PUSHKEY API passed.");

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_PUT_KEY;
    inregs.h.bh = 0x15;
    inregs.h.bl = 'y';
    inregs.x.dx = task_segment;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax != 0) {
        puts("Foreground PUTKEY rejected the task handle.");
        return 35;
    }
    memset(&inregs, 0, sizeof(inregs));
    inregs.h.ah = 0x00;
    int86(0x16, &inregs, &outregs);
    if (outregs.h.ah != 0x15 || outregs.h.al != 'y') {
        puts("Foreground PUTKEY queue result failed.");
        return 36;
    }
    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_DVC_PUT_KEY;
    inregs.h.bh = 0x16;
    inregs.h.bl = 'u';
    inregs.x.dx = task_segment + 1;
    int86(0x15, &inregs, &outregs);
    if (outregs.x.ax == 0) {
        puts("PUTKEY accepted an invalid task handle.");
        return 37;
    }
    puts("Foreground targeted PUTKEY API passed.");

    inregs.x.ax = ODQ_MUX_RESET;
    int86(0x2f, &inregs, &outregs);

    if (odq_max_backend_query(&backend))
        printf("Open 386MAX backend ABI %u.%u, %u/%u contexts, "
               "QPI %u.%u, table %04X.\n",
               backend.abi_version >> 8, backend.abi_version & 0xff,
               backend.active_contexts, backend.context_limit,
               backend.qpi_version >> 8, backend.qpi_version & 0xff,
               backend.qpi_context);
    else
        puts("Open 386MAX backend not detected (foreground mode).");
    return 0;
}

