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
    /* Mark's Auto Dialer:  the modem's port (1-4), the commands to dial
     * and to hang up, the access codes put before a number */
    unsigned modem_port;
    char dial[16];
    char hangup[16];
    char access[3][24];
    unsigned dial_baud;         /* 0 left as is, 1-6:  300-9600 baud */
    /* as DESQview's Setup:  Performance's ticks (1-15), Swapping and its
     * directory (blank:  the current one), Keyboard's Learn, the Window
     * Positions of windows 1-9 (row, column, height, width) */
    unsigned fg_ticks;
    unsigned bg_ticks;
    unsigned swapping;
    char swap_dir[64];
    unsigned learn;
    unsigned char window[9][4];
    /* Mouse:  used, left-handed; Video:  blank the screen after minutes
     * (0:  never), synchronized access (CGA) */
    unsigned mouse;
    unsigned left_handed;
    unsigned blank_minutes;
    unsigned sync_video;
    /* Colors:  the program in front shows through its window number's
     * colours (windows 1-4, then again):  text 0-15, background 0-7 */
    unsigned colors;
    unsigned char color[4][2];
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
