/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "settings.h"

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

static int equal_text(const char *left, const char *right)
{
    while (*left != '\0' && *right != '\0') {
        if (toupper((unsigned char)*left) != toupper((unsigned char)*right))
            return 0;
        ++left;
        ++right;
    }
    return *left == '\0' && *right == '\0';
}

static int parse_boolean(const char *text, unsigned *value)
{
    if (equal_text(text, "YES") || strcmp(text, "1") == 0) {
        *value = 1;
        return 1;
    }
    if (equal_text(text, "NO") || strcmp(text, "0") == 0) {
        *value = 0;
        return 1;
    }
    return 0;
}

void odq_settings_defaults(odq_settings *settings)
{
    memset(settings, 0, sizeof *settings);
    settings->auto_tsr = 1;
    settings->auto_ansi = 1;
    settings->confirm_exit = 1;
    settings->reload_catalog = 1;
    settings->show_memory = 1;
    settings->hotkey_launch = 1;
    settings->quick_help = 1;
    settings->modem_port = 1;
    strcpy(settings->dial, "ATDT");
    strcpy(settings->hangup, "ATZ");
}

/* a text setting:  up to size - 1 characters */
static int parse_text(const char *text, char *value, size_t size)
{
    if (strlen(text) >= size)
        return 0;
    strcpy(value, text);
    return 1;
}

int odq_settings_load(const char *path, odq_settings *settings,
                      unsigned *error_line)
{
    FILE *stream;
    char line[160];
    unsigned line_number = 0;
    odq_settings parsed;

    odq_settings_defaults(settings);
    parsed = *settings;
    if (error_line != NULL)
        *error_line = 0;
    stream = fopen(path, "rt");
    if (stream == NULL)
        return ODQ_SETTINGS_IO;
    while (fgets(line, sizeof(line), stream) != NULL) {
        char *content, *separator, *name, *value;
        unsigned *destination = NULL;
        char *text = NULL;
        size_t text_size = 0;

        ++line_number;
        if (strchr(line, '\n') == NULL && !feof(stream))
            goto syntax_error;
        content = trim(line);
        if (*content == '\0' || *content == '#' || *content == ';')
            continue;
        separator = strchr(content, '=');
        if (separator == NULL)
            goto syntax_error;
        *separator = '\0';
        name = trim(content);
        value = trim(separator + 1);
        if (equal_text(name, "AUTO_TSR"))
            destination = &parsed.auto_tsr;
        else if (equal_text(name, "AUTO_ANSI"))
            destination = &parsed.auto_ansi;
        else if (equal_text(name, "CONFIRM_EXIT"))
            destination = &parsed.confirm_exit;
        else if (equal_text(name, "RELOAD_CATALOG"))
            destination = &parsed.reload_catalog;
        else if (equal_text(name, "SHOW_MEMORY"))
            destination = &parsed.show_memory;
        else if (equal_text(name, "HOTKEY_LAUNCH"))
            destination = &parsed.hotkey_launch;
        else if (equal_text(name, "QUICK_HELP"))
            destination = &parsed.quick_help;
        else if (equal_text(name, "MODEM_PORT")) {
            if (value[0] < '1' || value[0] > '4' || value[1] != '\0')
                goto syntax_error;
            parsed.modem_port = (unsigned)(value[0] - '0');
            continue;
        } else if (equal_text(name, "DIAL"))
            text = parsed.dial, text_size = sizeof parsed.dial;
        else if (equal_text(name, "HANGUP"))
            text = parsed.hangup, text_size = sizeof parsed.hangup;
        else if (equal_text(name, "ACCESS1"))
            text = parsed.access[0], text_size = sizeof parsed.access[0];
        else if (equal_text(name, "ACCESS2"))
            text = parsed.access[1], text_size = sizeof parsed.access[1];
        else if (equal_text(name, "ACCESS3"))
            text = parsed.access[2], text_size = sizeof parsed.access[2];
        else
            goto syntax_error;
        if (text != NULL) {
            if (!parse_text(value, text, text_size))
                goto syntax_error;
        } else if (!parse_boolean(value, destination))
            goto syntax_error;
    }
    fclose(stream);
    *settings = parsed;
    return ODQ_SETTINGS_OK;

syntax_error:
    if (error_line != NULL)
        *error_line = line_number;
    fclose(stream);
    return ODQ_SETTINGS_SYNTAX;
}

int odq_settings_save(const char *path, const odq_settings *settings)
{
    FILE *stream;
    char temporary[260], backup[260];
    const char *slash, *dot;
    size_t stem_length;
    int had_original;

    slash = strrchr(path, '\\');
    if (strrchr(path, '/') != NULL &&
        (slash == NULL || strrchr(path, '/') > slash))
        slash = strrchr(path, '/');
    dot = strrchr(path, '.');
    if (dot == NULL || (slash != NULL && dot < slash))
        dot = path + strlen(path);
    stem_length = (size_t)(dot - path);
    if (stem_length + 5 > sizeof(temporary))
        return ODQ_SETTINGS_IO;
    memcpy(temporary, path, stem_length);
    strcpy(temporary + stem_length, ".NEW");
    memcpy(backup, path, stem_length);
    strcpy(backup + stem_length, ".BAK");

    stream = fopen(temporary, "wt");
    if (stream == NULL)
        return ODQ_SETTINGS_IO;
    fputs("# Open MaxView global settings version 1\n", stream);
    fprintf(stream, "AUTO_TSR=%s\n", settings->auto_tsr ? "YES" : "NO");
    fprintf(stream, "AUTO_ANSI=%s\n",
            settings->auto_ansi ? "YES" : "NO");
    fprintf(stream, "CONFIRM_EXIT=%s\n",
            settings->confirm_exit ? "YES" : "NO");
    fprintf(stream, "RELOAD_CATALOG=%s\n",
            settings->reload_catalog ? "YES" : "NO");
    fprintf(stream, "SHOW_MEMORY=%s\n",
            settings->show_memory ? "YES" : "NO");
    fprintf(stream, "HOTKEY_LAUNCH=%s\n",
            settings->hotkey_launch ? "YES" : "NO");
    fprintf(stream, "QUICK_HELP=%s\n",
            settings->quick_help ? "YES" : "NO");
    fprintf(stream, "MODEM_PORT=%u\n", settings->modem_port);
    fprintf(stream, "DIAL=%s\n", settings->dial);
    fprintf(stream, "HANGUP=%s\n", settings->hangup);
    fprintf(stream, "ACCESS1=%s\n", settings->access[0]);
    fprintf(stream, "ACCESS2=%s\n", settings->access[1]);
    fprintf(stream, "ACCESS3=%s\n", settings->access[2]);
    if (fclose(stream) != 0)
        return ODQ_SETTINGS_IO;

    stream = fopen(path, "rb");
    had_original = stream != NULL;
    if (stream != NULL)
        fclose(stream);
    remove(backup);
    if (had_original && rename(path, backup) != 0) {
        remove(temporary);
        return ODQ_SETTINGS_IO;
    }
    if (rename(temporary, path) != 0) {
        if (had_original)
            rename(backup, path);
        remove(temporary);
        return ODQ_SETTINGS_IO;
    }
    return ODQ_SETTINGS_OK;
}
