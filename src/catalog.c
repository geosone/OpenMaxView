/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "catalog.h"

static char *trim(char *text)
{
    char *end;

    while (*text != '\0' && isspace((unsigned char)*text))
        ++text;
    end = text + strlen(text);
    while (end > text && isspace((unsigned char)end[-1]))
        --end;
    *end = '\0';
    return text;
}

static int copy_field(char *dest, unsigned capacity, const char *source)
{
    size_t length = strlen(source);
    if (length >= capacity)
        return 0;
    memcpy(dest, source, length + 1);
    return 1;
}

static int parse_memory(const char *text, unsigned *value)
{
    char *end;
    unsigned long parsed;

    if (*text == '\0') {
        *value = 0;
        return 1;
    }
    parsed = strtoul(text, &end, 10);
    if (*end != '\0' || parsed > 65535UL)
        return 0;
    *value = (unsigned)parsed;
    return 1;
}

static int parse_line(char *line, odq_program *program)
{
    char *fields[6];
    char *cursor;
    unsigned index;

    fields[0] = line;
    for (index = 1; index < 6; ++index) {
        cursor = strchr(fields[index - 1], '|');
        if (cursor == NULL)
            return 0;
        *cursor = '\0';
        fields[index] = cursor + 1;
    }
    if (strchr(fields[5], '|') != NULL)
        return 0;
    for (index = 0; index < 6; ++index)
        fields[index] = trim(fields[index]);

    if (fields[0][0] == '\0' || fields[0][1] != '\0' ||
        fields[1][0] == '\0' || fields[2][0] == '\0')
        return 0;
    program->hotkey = (char)toupper((unsigned char)fields[0][0]);
    if (!copy_field(program->title, sizeof(program->title), fields[1]) ||
        !copy_field(program->command, sizeof(program->command), fields[2]) ||
        !copy_field(program->directory, sizeof(program->directory), fields[3]) ||
        !parse_memory(fields[4], &program->min_kb) ||
        !parse_memory(fields[5], &program->max_kb))
        return 0;
    if (program->max_kb != 0 && program->min_kb > program->max_kb)
        return 0;
    return 1;
}

int odq_catalog_load(const char *path, odq_catalog *catalog,
                     unsigned *error_line)
{
    FILE *stream;
    char line[384];
    unsigned line_number = 0;

    catalog->count = 0;
    if (error_line != NULL)
        *error_line = 0;
    stream = fopen(path, "rt");
    if (stream == NULL)
        return ODQ_CATALOG_IO;

    while (fgets(line, sizeof(line), stream) != NULL) {
        char *content;
        ++line_number;
        if (strchr(line, '\n') == NULL && !feof(stream)) {
            if (error_line != NULL)
                *error_line = line_number;
            fclose(stream);
            return ODQ_CATALOG_SYNTAX;
        }
        content = trim(line);
        if (*content == '\0' || *content == '#' || *content == ';')
            continue;
        if (catalog->count == ODQ_MAX_PROGRAMS) {
            if (error_line != NULL)
                *error_line = line_number;
            fclose(stream);
            return ODQ_CATALOG_FULL;
        }
        if (!parse_line(content, &catalog->programs[catalog->count])) {
            if (error_line != NULL)
                *error_line = line_number;
            fclose(stream);
            return ODQ_CATALOG_SYNTAX;
        }
        ++catalog->count;
    }
    fclose(stream);
    return ODQ_CATALOG_OK;
}

