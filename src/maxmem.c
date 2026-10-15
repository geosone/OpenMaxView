/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Open MaxView memory/backend status utility. */
#include <conio.h>
#include <ctype.h>
#include <dos.h>
#include <stdio.h>
#include <string.h>

#include "maxbackend.h"
#include "memquery.h"
#include "mvui.h"
#include "odqapi.h"

typedef struct memory_status {
    unsigned dos_total_kb;
    unsigned dos_valid;
    unsigned long dos_available_kb;
    unsigned long dos_largest_kb;
    unsigned ems_present;
    unsigned long ems_total_kb;
    unsigned long ems_available_kb;
    unsigned xms_present;
    unsigned xms_total_kb;
    unsigned xms_largest_kb;
    unsigned resident_present;
    unsigned resident_version;
    unsigned resident_caps;
    unsigned common_valid;
    unsigned common_total_bytes;
    unsigned common_available_bytes;
    unsigned common_largest_bytes;
    unsigned process_valid;
    unsigned process_total_paragraphs;
    unsigned process_system_paragraphs;
    unsigned process_largest_system_paragraphs;
    unsigned dv_present;
    unsigned dv_version;
    unsigned vcpi_present;
    unsigned vcpi_version;
    unsigned backend_present;
    odq_max_backend_info backend;
} memory_status;

static int conventional_free(unsigned long *available_kb,
                             unsigned long *largest_kb)
{
    union REGS inregs, outregs;
    struct SREGS segments;
    unsigned segment, next, iterations;
    unsigned long available = 0, largest = 0;

    memset(&inregs, 0, sizeof(inregs));
    inregs.h.ah = 0x52;
    int86x(0x21, &inregs, &outregs, &segments);
    if (outregs.x.bx < 2)
        return 0;
    segment = *((unsigned short far *)MK_FP(segments.es,
                                            outregs.x.bx - 2));
    for (iterations = 0; iterations < 4096; ++iterations) {
        unsigned char far *mcb;
        unsigned owner, paragraphs;
        unsigned long block_kb;
        char type;

        if (segment == 0 || segment >= 0xa000)
            return 0;
        mcb = (unsigned char far *)MK_FP(segment, 0);
        type = (char)mcb[0];
        owner = *((unsigned short far *)(mcb + 1));
        paragraphs = *((unsigned short far *)(mcb + 3));
        if ((type != 'M' && type != 'Z') || paragraphs == 0)
            return 0;
        if (owner == 0) {
            block_kb = ((unsigned long)paragraphs * 16UL) / 1024UL;
            available += block_kb;
            if (block_kb > largest)
                largest = block_kb;
        }
        if (type == 'Z') {
            *available_kb = available;
            *largest_kb = largest;
            return 1;
        }
        next = segment + paragraphs + 1;
        if (next <= segment || next >= 0xa000)
            return 0;
        segment = next;
    }
    return 0;
}

static void collect(memory_status *status)
{
    union REGS inregs, outregs;

    memset(status, 0, sizeof(*status));
    memset(&inregs, 0, sizeof(inregs));
    int86(0x12, &inregs, &outregs);
    status->dos_total_kb = outregs.x.ax;
    status->dos_valid = conventional_free(&status->dos_available_kb,
                                          &status->dos_largest_kb);

    memset(&inregs, 0, sizeof(inregs));
    inregs.h.ah = 0x40;
    int86(0x67, &inregs, &outregs);
    if (outregs.h.ah == 0) {
        inregs.h.ah = 0x42;
        int86(0x67, &inregs, &outregs);
        if (outregs.h.ah == 0) {
            status->ems_present = 1;
            status->ems_total_kb = (unsigned long)outregs.x.dx * 16UL;
            status->ems_available_kb = (unsigned long)outregs.x.bx * 16UL;
        }
    }

    status->xms_present = odq_xms_query(&status->xms_total_kb,
                                        &status->xms_largest_kb);

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = ODQ_MUX_STATUS;
    int86(0x2f, &inregs, &outregs);
    if (outregs.x.bx == ODQ_MUX_SIGNATURE) {
        status->resident_present = 1;
        status->resident_version = outregs.x.cx;
        inregs.x.ax = ODQ_MUX_INFO;
        int86(0x2f, &inregs, &outregs);
        status->resident_caps = outregs.x.bx;
        if ((status->resident_caps & ODQ_CAP_MEMORY_STATUS) != 0) {
            memset(&inregs, 0, sizeof(inregs));
            inregs.x.ax = ODQ_DVC_COMMON_STATUS;
            int86(0x15, &inregs, &outregs);
            status->common_valid = 1;
            status->common_available_bytes = outregs.x.bx;
            status->common_largest_bytes = outregs.x.cx;
            status->common_total_bytes = outregs.x.dx;
        }
        memset(&inregs, 0, sizeof(inregs));
        inregs.x.ax = ODQ_DVC_GET_FOREGROUND;
        int86(0x15, &inregs, &outregs);
        if (outregs.x.bx != 0) {
            unsigned task_segment = outregs.x.bx;
            memset(&inregs, 0, sizeof(inregs));
            inregs.x.ax = ODQ_DVC_PROCESS_MEMORY;
            inregs.x.dx = task_segment;
            int86(0x15, &inregs, &outregs);
            if (outregs.x.ax == 0) {
                status->process_valid = 1;
                status->process_system_paragraphs = outregs.x.bx;
                status->process_largest_system_paragraphs = outregs.x.cx;
                status->process_total_paragraphs = outregs.x.dx;
            }
        }
    }

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = 0x2b01;
    inregs.x.cx = 0x4445;
    inregs.x.dx = 0x5351;
    int86(0x21, &inregs, &outregs);
    if (outregs.h.al != 0xff) {
        status->dv_present = 1;
        status->dv_version = outregs.x.bx;
    }

    memset(&inregs, 0, sizeof(inregs));
    inregs.x.ax = 0xde00;
    int86(0x67, &inregs, &outregs);
    if (outregs.h.ah == 0) {
        status->vcpi_present = 1;
        status->vcpi_version = outregs.x.bx;
    }
    status->backend_present = odq_max_backend_query(&status->backend);
}

static void print_text(const memory_status *status)
{
    printf("DOS_TOTAL_KB=%u\n", status->dos_total_kb);
    if (status->dos_valid) {
        printf("DOS_AVAILABLE_KB=%lu\n", status->dos_available_kb);
        printf("DOS_LARGEST_KB=%lu\n", status->dos_largest_kb);
    } else {
        puts("DOS_AVAILABLE_KB=N/A");
        puts("DOS_LARGEST_KB=N/A");
    }
    printf("EMS_PRESENT=%u\n", status->ems_present);
    if (status->ems_present)
        printf("EMS_TOTAL_KB=%lu\nEMS_AVAILABLE_KB=%lu\n",
               status->ems_total_kb, status->ems_available_kb);
    printf("XMS_PRESENT=%u\n", status->xms_present);
    if (status->xms_present)
        printf("XMS_TOTAL_FREE_KB=%u\nXMS_LARGEST_FREE_KB=%u\n",
               status->xms_total_kb, status->xms_largest_kb);
    printf("MV_API=%s", status->resident_present ? "0." : "absent");
    if (status->resident_present)
        printf("%u", status->resident_version);
    putchar('\n');
    printf("MV_CAPS=%04X\n", status->resident_caps);
    if (status->common_valid) {
        printf("MV_COMMON_TOTAL_BYTES=%u\n", status->common_total_bytes);
        printf("MV_COMMON_AVAILABLE_BYTES=%u\n",
               status->common_available_bytes);
        printf("MV_COMMON_LARGEST_BYTES=%u\n",
               status->common_largest_bytes);
    }
    if (status->process_valid) {
        printf("MV_PROCESS_TOTAL_PARAS=%u\n",
               status->process_total_paragraphs);
        printf("MV_PROCESS_SYSTEM_PARAS=%u\n",
               status->process_system_paragraphs);
        printf("MV_PROCESS_LARGEST_SYSTEM_PARAS=%u\n",
               status->process_largest_system_paragraphs);
    }
    printf("DV_API=%s", status->dv_present ? "present" : "absent");
    if (status->dv_present)
        printf("-%u.%02X", status->dv_version >> 8,
               status->dv_version & 0xff);
    putchar('\n');
    printf("VCPI_PRESENT=%u\n", status->vcpi_present);
    printf("MAX_BACKEND=%u\n", status->backend_present);
    if (status->backend_present) {
        printf("MAX_ABI=%u.%u\n", status->backend.abi_version >> 8,
               status->backend.abi_version & 0xff);
        printf("MAX_CAPS=%04X\n", status->backend.capabilities);
        printf("MAX_CONTEXTS=%u/%u\n", status->backend.active_contexts,
               status->backend.context_limit);
        if (status->backend.qpi_version != 0) {
            printf("MAX_QPI=%u.%u\n", status->backend.qpi_version >> 8,
                   status->backend.qpi_version & 0xff);
            printf("MAX_QPI_CONTEXT=%08lX\n",
                   status->backend.qpi_context);
        }
    }
}

static void value_or_na(unsigned row, unsigned col, int valid,
                        unsigned long value)
{
    char text[16];
    if (valid)
        sprintf(text, "%lu K", value);
    else
        strcpy(text, "N/A");
    mvui_write(row, col, text, valid ? MVUI_ACTIVE : MVUI_TRIGGER);
}

static void draw(const memory_status *status)
{
    char line[68];

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "Memory", MVUI_MENU);
    mvui_put(0, 1, 'M', MVUI_MENU_TRIGGER);
    mvui_write(0, 63, "MaxView Status", MVUI_MENU_TRIGGER);
    mvui_frame(2, 5, 20, 74, "Open MaxView Memory Status");
    mvui_write(4, 9, "Memory type", MVUI_ACTIVE);
    mvui_write(4, 35, "Total", MVUI_ACTIVE);
    mvui_write(4, 49, "Available", MVUI_ACTIVE);
    mvui_write(4, 63, "Largest", MVUI_ACTIVE);
    mvui_write(6, 9, "DOS conventional", MVUI_ACTIVE);
    value_or_na(6, 35, 1, status->dos_total_kb);
    value_or_na(6, 49, status->dos_valid, status->dos_available_kb);
    value_or_na(6, 63, status->dos_valid, status->dos_largest_kb);
    mvui_write(8, 9, "EMS expanded", MVUI_ACTIVE);
    value_or_na(8, 35, status->ems_present, status->ems_total_kb);
    value_or_na(8, 49, status->ems_present, status->ems_available_kb);
    value_or_na(8, 63, status->ems_present, status->ems_available_kb);
    mvui_write(10, 9, "XMS extended (free)", MVUI_ACTIVE);
    value_or_na(10, 35, status->xms_present, status->xms_total_kb);
    value_or_na(10, 49, status->xms_present, status->xms_total_kb);
    value_or_na(10, 63, status->xms_present, status->xms_largest_kb);

    if (status->common_valid)
        sprintf(line, "MaxView common: %u total, %u free, %u largest bytes",
                status->common_total_bytes, status->common_available_bytes,
                status->common_largest_bytes);
    else
        strcpy(line, "MaxView common pool: unavailable");
    mvui_write(12, 9, line, MVUI_ACTIVE);

    if (status->process_valid)
        sprintf(line, "Current task: %u DOS, %u system paragraphs",
                status->process_total_paragraphs,
                status->process_system_paragraphs);
    else
        strcpy(line, "Current task memory: unavailable");
    mvui_write(13, 9, line, MVUI_ACTIVE);

    sprintf(line, "MAXVTSR: %s   caps %04X",
            status->resident_present ? "present" : "absent",
            status->resident_caps);
    mvui_write(14, 9, line, MVUI_ACTIVE);
    sprintf(line, "DESQview API: %s   VCPI: %s",
            status->dv_present ? "present" : "absent",
            status->vcpi_present ? "present" : "absent");
    mvui_write(16, 9, line, MVUI_ACTIVE);
    if (status->backend_present)
        sprintf(line, "Open 386MAX ABI %u.%u: %u active, limit %u",
                status->backend.abi_version >> 8,
                status->backend.abi_version & 0xff,
                status->backend.active_contexts,
                status->backend.context_limit);
    else
        strcpy(line, "Open 386MAX MaxView backend: not detected");
    mvui_write(18, 9, line, MVUI_ACTIVE);
    if (status->backend_present && status->backend.qpi_version != 0)
        sprintf(line, "QPI %u.%u active page table %08lX",
                status->backend.qpi_version >> 8,
                status->backend.qpi_version & 0xff,
                status->backend.qpi_context);
    else
        strcpy(line, "QPI context interface: unavailable");
    mvui_write(19, 9, line, MVUI_ACTIVE);
    mvui_button(24, 1, 12, "Exit Esc");
    mvui_button(24, 15, 14, "Refresh F5");
}

int main(int argc, char **argv)
{
    memory_status status;
    int key;

    if (argc > 2 || (argc == 2 && stricmp(argv[1], "/T") != 0)) {
        puts("Usage: MAXVMEM [/T]");
        return 2;
    }
    collect(&status);
    if (argc == 2) {
        print_text(&status);
        return 0;
    }
    mvui_init();
    for (;;) {
        draw(&status);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 63)
                collect(&status);
        } else if (key == 27 || toupper(key) == 'Q') {
            break;
        }
    }
    mvui_restore();
    return 0;
}
