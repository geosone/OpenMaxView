/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVIEW_DVP_H
#define MAXVIEW_DVP_H

#include "catalog.h"

#define DVP_BASE_SIZE 0x173
#define DVP_20_SIZE   0x18d

typedef struct dvp_info {
    char title[31];
    char pathname[65];
    char directory[65];
    char parameters[65];
    char menu_keys[3];
    char default_drive;
    unsigned min_kb;
    unsigned max_kb;
    unsigned system_kb;
    unsigned script_bytes;
    unsigned idle_polls;
    unsigned max_ems_kb;
    unsigned extra_system;
    unsigned rows;
    unsigned columns;
    unsigned text_pages;
    unsigned graphics_pages;
    unsigned version;
    unsigned flags1;
    unsigned flags2;
    unsigned flags3;
    unsigned flags4;
    unsigned serial_ports;
    unsigned protection;
    int has_v20;
} dvp_info;

enum dvp_result {
    DVP_OK = 0,
    DVP_IO = -1,
    DVP_TOO_SHORT = -2,
    DVP_CHECKSUM = -3,
    DVP_INVALID = -4
};

int dvp_load(const char *path, dvp_info *info);
int dvp_make_program(const dvp_info *info, char hotkey,
                     odq_program *program);

#endif
