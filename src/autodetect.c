/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "autodetect.h"

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

static int same_text(const char *left, const char *right)
{
    while (*left != '\0' && *right != '\0') {
        if (toupper((unsigned char)*left) != toupper((unsigned char)*right))
            return 0;
        ++left;
        ++right;
    }
    return *left == '\0' && *right == '\0';
}

static int safe_field(const char *text)
{
    return strchr(text, '|') == NULL && strchr(text, '\n') == NULL &&
           strchr(text, '\r') == NULL;
}

static int copy_field(char *target, unsigned capacity, const char *source)
{
    size_t length = strlen(source);
    if (length >= capacity)
        return 0;
    memcpy(target, source, length + 1);
    return 1;
}

static int parse_memory(const char *text, unsigned *value)
{
    char *end;
    unsigned long parsed;

    if (*text == '\0')
        return 0;
    parsed = strtoul(text, &end, 10);
    if (*end != '\0' || parsed > 65535UL)
        return 0;
    *value = (unsigned)parsed;
    return 1;
}

static int valid_filename(const char *filename)
{
    const char *dot = NULL;
    unsigned stem = 0, extension = 0;

    if (*filename == '\0' || strlen(filename) > MVA_FILENAME_LEN)
        return 0;
    while (*filename != '\0') {
        unsigned char ch = (unsigned char)*filename++;
        if (ch == '.') {
            if (dot != NULL || stem == 0) return 0;
            dot = filename - 1;
        } else if (!isalnum(ch) && ch != '_' && ch != '-' && ch != '$' &&
                   ch != '~') {
            return 0;
        } else if (dot == NULL) {
            ++stem;
        } else {
            ++extension;
        }
    }
    return stem <= 8 && extension <= 3 && (dot == NULL || extension != 0);
}

static int parse_line(char *line, mva_rule *rule)
{
    char *field[5];
    char *separator;
    unsigned index;

    field[0] = line;
    for (index = 1; index < 5; ++index) {
        separator = strchr(field[index - 1], '|');
        if (separator == NULL)
            return 0;
        *separator = '\0';
        field[index] = separator + 1;
    }
    if (strchr(field[4], '|') != NULL)
        return 0;
    for (index = 0; index < 5; ++index)
        field[index] = trim(field[index]);

    if (!valid_filename(field[0]) || field[1][0] == '\0' ||
        field[2][0] == '\0' || !safe_field(field[1]) ||
        !safe_field(field[2]) ||
        !copy_field(rule->filename, sizeof(rule->filename), field[0]) ||
        !copy_field(rule->title, sizeof(rule->title), field[1]) ||
        !copy_field(rule->command, sizeof(rule->command), field[2]) ||
        !parse_memory(field[3], &rule->min_kb) ||
        !parse_memory(field[4], &rule->max_kb) ||
        (rule->max_kb != 0 && rule->min_kb > rule->max_kb))
        return 0;
    for (index = 0; rule->filename[index] != '\0'; ++index)
        rule->filename[index] =
            (char)toupper((unsigned char)rule->filename[index]);
    return 1;
}

int mva_rules_load(const char *path, mva_rules *rules, unsigned *error_line)
{
    FILE *stream;
    char line[384];
    unsigned line_number = 0, previous;

    rules->count = 0;
    if (error_line != NULL)
        *error_line = 0;
    stream = fopen(path, "rt");
    if (stream == NULL)
        return MVA_IO;
    while (fgets(line, sizeof(line), stream) != NULL) {
        char *content;
        ++line_number;
        if (strchr(line, '\n') == NULL && !feof(stream)) {
            if (error_line != NULL) *error_line = line_number;
            fclose(stream);
            return MVA_SYNTAX;
        }
        content = trim(line);
        if (*content == '\0' || *content == '#' || *content == ';')
            continue;
        if (rules->count == MVA_MAX_RULES) {
            if (error_line != NULL) *error_line = line_number;
            fclose(stream);
            return MVA_FULL;
        }
        if (!parse_line(content, &rules->rules[rules->count])) {
            if (error_line != NULL) *error_line = line_number;
            fclose(stream);
            return MVA_SYNTAX;
        }
        for (previous = 0; previous < rules->count; ++previous)
            if (same_text(rules->rules[previous].filename,
                          rules->rules[rules->count].filename)) {
                if (error_line != NULL) *error_line = line_number;
                fclose(stream);
                return MVA_DUPLICATE;
            }
        ++rules->count;
    }
    fclose(stream);
    return MVA_OK;
}

static void command_filename(const char *command, char *filename)
{
    const char *start, *end, *base;
    size_t length;

    while (isspace((unsigned char)*command)) ++command;
    if (*command == '"') {
        start = ++command;
        end = strchr(start, '"');
        if (end == NULL) end = start + strlen(start);
    } else {
        start = command;
        end = start;
        while (*end != '\0' && !isspace((unsigned char)*end)) ++end;
    }
    base = start;
    while (start < end) {
        if (*start == '\\' || *start == '/' || *start == ':')
            base = start + 1;
        ++start;
    }
    length = (size_t)(end - base);
    if (length > MVA_FILENAME_LEN) length = MVA_FILENAME_LEN;
    memcpy(filename, base, length);
    filename[length] = '\0';
}

int mva_catalog_has_file(const odq_catalog *catalog, const char *filename)
{
    unsigned index;
    char configured[MVA_FILENAME_LEN + 1];

    for (index = 0; index < catalog->count; ++index) {
        command_filename(catalog->programs[index].command, configured);
        if (same_text(configured, filename))
            return 1;
    }
    return 0;
}

static int hotkey_used(const odq_catalog *catalog, int key)
{
    unsigned index;
    key = toupper((unsigned char)key);
    for (index = 0; index < catalog->count; ++index)
        if (toupper((unsigned char)catalog->programs[index].hotkey) == key)
            return 1;
    return 0;
}

static char choose_hotkey(const odq_catalog *catalog, const mva_rule *rule)
{
    const char *scan;
    int key;

    for (scan = rule->title; *scan != '\0'; ++scan)
        if (isalnum((unsigned char)*scan) && !hotkey_used(catalog, *scan))
            return (char)toupper((unsigned char)*scan);
    for (scan = rule->filename; *scan != '\0'; ++scan)
        if (isalnum((unsigned char)*scan) && !hotkey_used(catalog, *scan))
            return (char)toupper((unsigned char)*scan);
    for (key = 'A'; key <= 'Z'; ++key)
        if (!hotkey_used(catalog, key)) return (char)key;
    for (key = '0'; key <= '9'; ++key)
        if (!hotkey_used(catalog, key)) return (char)key;
    return '\0';
}

int mva_catalog_add(odq_catalog *catalog, const mva_rule *rule,
                    const char *directory)
{
    odq_program *program;
    char hotkey;

    if (catalog->count == ODQ_MAX_PROGRAMS)
        return MVA_FULL;
    if (mva_catalog_has_file(catalog, rule->filename))
        return MVA_DUPLICATE;
    if (strlen(directory) > ODQ_DIR_LEN)
        return MVA_SYNTAX;
    hotkey = choose_hotkey(catalog, rule);
    if (hotkey == '\0')
        return MVA_FULL;
    program = &catalog->programs[catalog->count];
    memset(program, 0, sizeof(*program));
    program->hotkey = hotkey;
    strcpy(program->title, rule->title);
    strcpy(program->command, rule->command);
    strcpy(program->directory, directory);
    program->min_kb = rule->min_kb;
    program->max_kb = rule->max_kb;
    if (!odq_program_valid(program))
        return MVA_SYNTAX;
    ++catalog->count;
    return MVA_OK;
}
