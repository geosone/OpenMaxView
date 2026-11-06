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

/* DESQview 2.80's Window Positions (measured) */
static const unsigned char default_window[9][4] = {
    { 1, 1, 10, 78 }, { 14, 1, 10, 78 }, { 5, 16, 15, 48 },
    { 1, 1, 23, 38 }, { 1, 42, 23, 37 }, { 1, 1, 10, 38 },
    { 1, 42, 10, 37 }, { 14, 1, 10, 38 }, { 14, 42, 10, 37 }
};

/* DESQview 2.80's Colors:  windows 1-4, text and background (measured) */
static const unsigned char default_color[4][2] = {
    { 1, 3 }, { 1, 6 }, { 7, 4 }, { 1, 2 }
};

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
    settings->fg_ticks = 6;
    settings->bg_ticks = 2;
    settings->swapping = 1;
    settings->learn = 1;
    strcpy(settings->learn_quote, "`");
    settings->shift_states = 1;
    settings->mouse = 1;
    memcpy(settings->window, default_window, sizeof settings->window);
    memcpy(settings->color, default_color, sizeof settings->color);
}

/* a number from low to high */
static int parse_number(const char *text, unsigned low, unsigned high,
                        unsigned *value)
{
    unsigned long number = 0;

    if (*text == '\0')
        return 0;
    for (; *text != '\0'; ++text) {
        if (!isdigit((unsigned char)*text))
            return 0;
        number = number * 10 + (unsigned)(*text - '0');
        if (number > high)
            return 0;
    }
    if (number < low)
        return 0;
    *value = (unsigned)number;
    return 1;
}

/* WINDOWn:  row,column,height,width */
static int parse_window(char *text, unsigned char *window)
{
    static const unsigned high[4] = { 23, 79, 23, 78 };
    unsigned i, value;
    char *comma;

    for (i = 0; i < 4; ++i) {
        comma = strchr(text, ',');
        if ((comma == NULL) != (i == 3))
            return 0;
        if (comma != NULL)
            *comma = '\0';
        if (!parse_number(trim(text), i < 2 ? 0 : 1, high[i], &value))
            return 0;
        window[i] = (unsigned char)value;
        text = comma + 1;
    }
    return 1;
}

/* COLORn:  text,background */
static int parse_color(char *text, unsigned char *color)
{
    char *comma = strchr(text, ',');
    unsigned value;

    if (comma == NULL)
        return 0;
    *comma = '\0';
    if (!parse_number(trim(text), 0, 15, &value))
        return 0;
    color[0] = (unsigned char)value;
    if (!parse_number(trim(comma + 1), 0, 7, &value))
        return 0;
    color[1] = (unsigned char)value;
    return 1;
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
        else if (equal_text(name, "SWAPPING"))
            destination = &parsed.swapping;
        else if (equal_text(name, "SHIFT_STATES"))
            destination = &parsed.shift_states;
        else if (equal_text(name, "LEARN_QUOTE"))
            text = parsed.learn_quote, text_size = sizeof parsed.learn_quote;
        else if (equal_text(name, "LEARN"))
            destination = &parsed.learn;
        else if (equal_text(name, "MOUSE"))
            destination = &parsed.mouse;
        else if (equal_text(name, "LEFT_HANDED"))
            destination = &parsed.left_handed;
        else if (equal_text(name, "SYNC_VIDEO"))
            destination = &parsed.sync_video;
        else if (equal_text(name, "PRINTER_CONTENTION"))
            destination = &parsed.printer;
        else if (equal_text(name, "COLORS"))
            destination = &parsed.colors;
        else if (strlen(name) == 6 && name[5] >= '1' && name[5] <= '4') {
            unsigned index = (unsigned)(name[5] - '1');

            name[5] = '\0';
            if (!equal_text(name, "COLOR") ||
                !parse_color(value, parsed.color[index]))
                goto syntax_error;
            continue;
        }
        else if (equal_text(name, "BLANK")) {
            if (!parse_number(value, 0, 99, &parsed.blank_minutes))
                goto syntax_error;
            continue;
        }
        else if (equal_text(name, "DIAL_BAUD")) {
            if (!parse_number(value, 0, 6, &parsed.dial_baud))
                goto syntax_error;
            continue;
        } else if (equal_text(name, "FOREGROUND")) {
            if (!parse_number(value, 1, 15, &parsed.fg_ticks))
                goto syntax_error;
            continue;
        } else if (equal_text(name, "BACKGROUND")) {
            if (!parse_number(value, 1, 15, &parsed.bg_ticks))
                goto syntax_error;
            continue;
        } else if (equal_text(name, "SWAP_DIR"))
            text = parsed.swap_dir, text_size = sizeof parsed.swap_dir;
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
        else if (strlen(name) == 7 && name[6] >= '1' && name[6] <= '9') {
            unsigned index = (unsigned)(name[6] - '1');

            name[6] = '\0';
            if (!equal_text(name, "WINDOW") ||
                !parse_window(value, parsed.window[index]))
                goto syntax_error;
            continue;
        } else
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
    unsigned index;

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
    fprintf(stream, "DIAL_BAUD=%u\n", settings->dial_baud);
    fprintf(stream, "FOREGROUND=%u\n", settings->fg_ticks);
    fprintf(stream, "BACKGROUND=%u\n", settings->bg_ticks);
    fprintf(stream, "SWAPPING=%s\n", settings->swapping ? "YES" : "NO");
    fprintf(stream, "SWAP_DIR=%s\n", settings->swap_dir);
    fprintf(stream, "LEARN=%s\n", settings->learn ? "YES" : "NO");
    fprintf(stream, "LEARN_QUOTE=%s\n", settings->learn_quote);
    fprintf(stream, "SHIFT_STATES=%s\n",
            settings->shift_states ? "YES" : "NO");
    fprintf(stream, "MOUSE=%s\n", settings->mouse ? "YES" : "NO");
    fprintf(stream, "LEFT_HANDED=%s\n", settings->left_handed ? "YES" : "NO");
    fprintf(stream, "BLANK=%u\n", settings->blank_minutes);
    fprintf(stream, "SYNC_VIDEO=%s\n", settings->sync_video ? "YES" : "NO");
    fprintf(stream, "PRINTER_CONTENTION=%s\n",
            settings->printer ? "YES" : "NO");
    fprintf(stream, "COLORS=%s\n", settings->colors ? "YES" : "NO");
    for (index = 0; index < 4; ++index)
        fprintf(stream, "COLOR%u=%u,%u\n", index + 1,
                settings->color[index][0], settings->color[index][1]);
    for (index = 0; index < 9; ++index)
        fprintf(stream, "WINDOW%u=%u,%u,%u,%u\n", index + 1,
                settings->window[index][0], settings->window[index][1],
                settings->window[index][2], settings->window[index][3]);
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
