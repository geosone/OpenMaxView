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

static int safe_field(const char *text)
{
    return strchr(text, '|') == NULL && strchr(text, '\n') == NULL &&
           strchr(text, '\r') == NULL;
}

int odq_program_valid(const odq_program *program)
{
    return isprint((unsigned char)program->hotkey) && program->hotkey != '|' &&
           program->title[0] != '\0' &&
           program->command[0] != '\0' && safe_field(program->title) &&
           safe_field(program->command) && safe_field(program->directory) &&
           (program->max_kb == 0 || program->min_kb <= program->max_kb);
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
        {
            unsigned previous;
            for (previous = 0; previous < catalog->count; ++previous)
                if (catalog->programs[previous].hotkey ==
                    catalog->programs[catalog->count].hotkey) {
                    if (error_line != NULL)
                        *error_line = line_number;
                    fclose(stream);
                    return ODQ_CATALOG_SYNTAX;
                }
        }
        ++catalog->count;
    }
    fclose(stream);
    return ODQ_CATALOG_OK;
}

int odq_catalog_save(const char *path, const odq_catalog *catalog)
{
    FILE *stream;
    unsigned index, previous;
    char temporary[260], backup[260];
    const char *slash, *dot;
    size_t stem_length;
    int had_original;

    if (catalog->count > ODQ_MAX_PROGRAMS)
        return ODQ_CATALOG_FULL;
    for (index = 0; index < catalog->count; ++index)
        if (!odq_program_valid(&catalog->programs[index]))
            return ODQ_CATALOG_SYNTAX;
    for (index = 0; index < catalog->count; ++index)
        for (previous = 0; previous < index; ++previous)
            if (toupper((unsigned char)catalog->programs[index].hotkey) ==
                toupper((unsigned char)catalog->programs[previous].hotkey))
                return ODQ_CATALOG_SYNTAX;

    slash = strrchr(path, '\\');
    if (strrchr(path, '/') != NULL &&
        (slash == NULL || strrchr(path, '/') > slash))
        slash = strrchr(path, '/');
    dot = strrchr(path, '.');
    if (dot == NULL || (slash != NULL && dot < slash))
        dot = path + strlen(path);
    stem_length = (size_t)(dot - path);
    if (stem_length + 5 > sizeof(temporary))
        return ODQ_CATALOG_IO;
    memcpy(temporary, path, stem_length);
    strcpy(temporary + stem_length, ".NEW");
    memcpy(backup, path, stem_length);
    strcpy(backup + stem_length, ".BAK");

    stream = fopen(temporary, "wt");
    if (stream == NULL)
        return ODQ_CATALOG_IO;
    fputs("# Open MaxView program catalogue version 1\n", stream);
    fputs("# hotkey|title|command|working-directory|min-kb|max-kb\n", stream);
    for (index = 0; index < catalog->count; ++index) {
        const odq_program *program = &catalog->programs[index];
        if (fprintf(stream, "%c|%s|%s|%s|%u|%u\n",
                    toupper((unsigned char)program->hotkey), program->title,
                    program->command, program->directory, program->min_kb,
                    program->max_kb) < 0) {
            fclose(stream);
            return ODQ_CATALOG_IO;
        }
    }
    if (fclose(stream) != 0)
        return ODQ_CATALOG_IO;

    stream = fopen(path, "rb");
    had_original = stream != NULL;
    if (stream != NULL)
        fclose(stream);
    remove(backup);
    if (had_original && rename(path, backup) != 0) {
        remove(temporary);
        return ODQ_CATALOG_IO;
    }
    if (rename(temporary, path) != 0) {
        if (had_original)
            rename(backup, path);
        remove(temporary);
        return ODQ_CATALOG_IO;
    }
    return ODQ_CATALOG_OK;
}

