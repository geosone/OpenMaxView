/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef SETTINGS_H
#define SETTINGS_H

typedef struct odq_settings {
    unsigned auto_tsr;
    unsigned auto_ansi;
    unsigned confirm_exit;
    unsigned reload_catalog;
    unsigned show_memory;
    unsigned hotkey_launch;
    unsigned quick_help;
} odq_settings;

enum odq_settings_result {
    ODQ_SETTINGS_OK = 0,
    ODQ_SETTINGS_IO = -1,
    ODQ_SETTINGS_SYNTAX = -2
};

void odq_settings_defaults(odq_settings *settings);
int odq_settings_load(const char *path, odq_settings *settings,
                      unsigned *error_line);
int odq_settings_save(const char *path, const odq_settings *settings);

#endif
