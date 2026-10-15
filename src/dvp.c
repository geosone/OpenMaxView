/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "dvp.h"

#define DVP_READ_SIZE 0x1a0

static unsigned get_word(const unsigned char *data, unsigned offset)
{
    return (unsigned)data[offset] | ((unsigned)data[offset + 1] << 8);
}

static void copy_fixed(char *target, unsigned capacity,
                       const unsigned char *source, unsigned length,
                       int blank_padded)
{
    unsigned count = 0;

    while (count < length && count + 1 < capacity && source[count] != 0) {
        unsigned char ch = source[count];
        target[count] = (ch >= 32 && ch < 127) ? (char)ch : ' ';
        ++count;
    }
    if (blank_padded)
        while (count > 0 && target[count - 1] == ' ')
            --count;
    target[count] = '\0';
}

static int field_terminated(const unsigned char *source, unsigned length)
{
    unsigned index;
    for (index = 0; index < length; ++index)
        if (source[index] == 0)
            return 1;
    return 0;
}

int dvp_load(const char *path, dvp_info *info)
{
    FILE *stream;
    unsigned char data[DVP_READ_SIZE];
    size_t length;
    unsigned index, checksum = 0;

    memset(info, 0, sizeof(*info));
    stream = fopen(path, "rb");
    if (stream == NULL)
        return DVP_IO;
    length = fread(data, 1, sizeof(data), stream);
    if (ferror(stream)) {
        fclose(stream);
        return DVP_IO;
    }
    fclose(stream);
    if (length < DVP_BASE_SIZE)
        return DVP_TOO_SHORT;
    for (index = 2; index <= 0x170; ++index)
        checksum = (checksum + data[index]) & 0xff;
    if (checksum != data[1])
        return DVP_CHECKSUM;
    if (!field_terminated(data + 0x24, 64) ||
        !field_terminated(data + 0x65, 64) ||
        !field_terminated(data + 0xa5, 64))
        return DVP_INVALID;

    copy_fixed(info->title, sizeof(info->title), data + 0x02, 30, 1);
    copy_fixed(info->pathname, sizeof(info->pathname), data + 0x24, 64, 0);
    copy_fixed(info->directory, sizeof(info->directory), data + 0x65, 64, 0);
    copy_fixed(info->parameters, sizeof(info->parameters), data + 0xa5, 64, 0);
    copy_fixed(info->menu_keys, sizeof(info->menu_keys), data + 0x171, 2, 1);
    info->max_kb = get_word(data, 0x20);
    info->min_kb = get_word(data, 0x22);
    info->default_drive = (char)toupper((unsigned char)data[0x64]);
    info->text_pages = data[0xe6];
    info->rows = data[0xe9];
    info->columns = data[0xea];
    info->system_kb = get_word(data, 0xed);
    info->flags1 = data[0x16f];
    info->flags2 = data[0x170];
    if (info->title[0] == '\0' || info->pathname[0] == '\0' ||
        (info->max_kb != 0 && info->min_kb > info->max_kb))
        return DVP_INVALID;

    if (length >= DVP_20_SIZE) {
        info->has_v20 = 1;
        info->script_bytes = get_word(data, 0x173);
        info->idle_polls = get_word(data, 0x175);
        info->version = data[0x17e];
        info->max_ems_kb = get_word(data, 0x182);
        info->flags3 = data[0x184];
        info->graphics_pages = data[0x186];
        info->extra_system = get_word(data, 0x187);
        info->serial_ports = data[0x18a];
        info->flags4 = data[0x18b];
        info->protection = data[0x18c];
    }
    return DVP_OK;
}

int dvp_make_program(const dvp_info *info, char hotkey,
                     odq_program *program)
{
    size_t path_length, parameter_length, directory_length;
    int add_drive, add_slash;

    memset(program, 0, sizeof(*program));
    path_length = strlen(info->pathname);
    parameter_length = strlen(info->parameters);
    directory_length = strlen(info->directory);
    add_drive = directory_length != 0 &&
                !(directory_length >= 2 && info->directory[1] == ':') &&
                info->default_drive >= 'A' && info->default_drive <= 'Z';
    add_slash = add_drive && info->directory[0] != '\\' &&
                info->directory[0] != '/';
    if (strlen(info->title) > ODQ_TITLE_LEN ||
        path_length + (parameter_length != 0 ? 1 : 0) + parameter_length >
            ODQ_COMMAND_LEN ||
        directory_length + (add_drive ? 2 : 0) + (add_slash ? 1 : 0) >
            ODQ_DIR_LEN)
        return DVP_INVALID;

    program->hotkey = (char)toupper((unsigned char)hotkey);
    strcpy(program->title, info->title);
    strcpy(program->command, info->pathname);
    if (parameter_length != 0) {
        strcat(program->command, " ");
        strcat(program->command, info->parameters);
    }
    if (add_drive) {
        program->directory[0] = info->default_drive;
        program->directory[1] = ':';
        program->directory[2] = '\0';
        if (add_slash)
            strcat(program->directory, "\\");
        strcat(program->directory, info->directory);
    } else {
        strcpy(program->directory, info->directory);
    }
    program->min_kb = info->min_kb;
    program->max_kb = info->max_kb;
    program->profile.version = ODQ_PROFILE_VERSION;
    program->profile.source_version = info->version;
    program->profile.system_kb = info->system_kb;
    program->profile.script_bytes = info->script_bytes;
    program->profile.idle_polls = info->idle_polls;
    program->profile.max_ems_kb = info->max_ems_kb;
    program->profile.extra_system = info->extra_system;
    program->profile.rows = info->rows;
    program->profile.columns = info->columns;
    program->profile.text_pages = info->text_pages;
    program->profile.graphics_pages = info->graphics_pages;
    program->profile.serial_ports = info->serial_ports;
    program->profile.protection = info->protection;
    program->profile.flags1 = info->flags1;
    program->profile.flags2 = info->flags2;
    program->profile.flags3 = info->flags3;
    program->profile.flags4 = info->flags4;
    return odq_program_valid(program) ? DVP_OK : DVP_INVALID;
}
