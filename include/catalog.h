/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef ODQ_CATALOG_H
#define ODQ_CATALOG_H

#define ODQ_MAX_PROGRAMS 24
#define ODQ_TITLE_LEN    38
#define ODQ_COMMAND_LEN  127
#define ODQ_DIR_LEN      79
#define ODQ_PROFILE_VERSION 1

typedef struct odq_process_profile {
    unsigned version;
    unsigned source_version;
    unsigned system_kb;
    unsigned script_bytes;
    unsigned idle_polls;
    unsigned max_ems_kb;
    unsigned extra_system;
    unsigned rows;
    unsigned columns;
    unsigned text_pages;
    unsigned graphics_pages;
    unsigned serial_ports;
    unsigned protection;
    unsigned flags1;
    unsigned flags2;
    unsigned flags3;
    unsigned flags4;
} odq_process_profile;

typedef struct odq_program {
    char hotkey;
    char title[ODQ_TITLE_LEN + 1];
    char command[ODQ_COMMAND_LEN + 1];
    char directory[ODQ_DIR_LEN + 1];
    unsigned min_kb;
    unsigned max_kb;
    odq_process_profile profile;
} odq_program;

typedef struct odq_catalog {
    odq_program programs[ODQ_MAX_PROGRAMS];
    unsigned count;
} odq_catalog;

enum odq_catalog_result {
    ODQ_CATALOG_OK = 0,
    ODQ_CATALOG_IO = -1,
    ODQ_CATALOG_SYNTAX = -2,
    ODQ_CATALOG_FULL = -3
};

int odq_catalog_load(const char *path, odq_catalog *catalog,
                     unsigned *error_line);
int odq_catalog_save(const char *path, const odq_catalog *catalog);
int odq_program_valid(const odq_program *program);
/* Can be swapped out (DVP 2.x):  0 when the profile says N (flags4 bit 6
 * clear, flags1 bit 0 clear, as DESQview 2.80 writes it), else 1 (Y, the
 * field blank, no DVP profile) */
int odq_program_swappable(const odq_program *program);
/* Share EGA when foreground/zoomed (DVP 2.x):  flags4 bit 0, as DESQview
 * 2.80 writes it; 1 without a DVP profile */
int odq_program_share_ega(const odq_program *program);

#endif

