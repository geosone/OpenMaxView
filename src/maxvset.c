/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Global Open MaxView settings editor. */
#include <conio.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include "mvui.h"
#include "settings.h"

#define OPTION_COUNT 7

static const char *option_names[OPTION_COUNT] = {
    "Load resident API automatically",
    "Load ANSI console automatically",
    "Confirm before leaving MaxView",
    "Reload program catalogue after a child",
    "Show memory limits in program list",
    "Launch programs by red hotkey",
    "Show the Quick Help instructions"
};

static unsigned *option_value(odq_settings *settings, unsigned index)
{
    switch (index) {
    case 0: return &settings->auto_tsr;
    case 1: return &settings->auto_ansi;
    case 2: return &settings->confirm_exit;
    case 3: return &settings->reload_catalog;
    case 4: return &settings->show_memory;
    case 5: return &settings->hotkey_launch;
    default: return &settings->quick_help;
    }
}

static unsigned option_enabled(const odq_settings *settings, unsigned index)
{
    switch (index) {
    case 0: return settings->auto_tsr;
    case 1: return settings->auto_ansi;
    case 2: return settings->confirm_exit;
    case 3: return settings->reload_catalog;
    case 4: return settings->show_memory;
    case 5: return settings->hotkey_launch;
    default: return settings->quick_help;
    }
}

static void draw(const odq_settings *settings, unsigned selected,
                 const char *status)
{
    unsigned index, row;

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "Setup", MVUI_MENU);
    mvui_put(0, 1, 'S', MVUI_MENU_TRIGGER);
    mvui_write(0, 61, "MaxView Settings", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 21, 55, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 55);
    mvui_fill(2, 59, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 59, 21, 77);
    mvui_write(3, 18, "Global Options", MVUI_DATA_HIGH);
    for (index = 0; index < OPTION_COUNT; ++index) {
        unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
        row = 5 + index * 2;
        mvui_fill(row, 4, row, 52, ' ', attr);
        mvui_write(row, 6, option_enabled(settings, index) ? "[X]" : "[ ]",
                   attr);
        mvui_write(row, 11, option_names[index], attr);
        if (index == selected)
            mvui_put(row, 7, option_enabled(settings, index) ? 'X' : ' ',
                     MVUI_TRIGGER);
    }
    mvui_write(4, 61, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(6, 61, "Up/Down Select", MVUI_QUICK);
    mvui_write(7, 61, "Space   Toggle", MVUI_QUICK);
    mvui_write(8, 61, "F2/S    Save", MVUI_QUICK);
    mvui_write(9, 61, "Esc     Exit", MVUI_QUICK);
    mvui_write(13, 61, "Status:", MVUI_QUICK_HIGH);
    mvui_write(14, 61, status, MVUI_QUICK);
    mvui_write(18, 5, "Backend scheduling options appear only when supported.",
               MVUI_DATA);
    mvui_button(24, 1, 12, "Exit Esc");
    mvui_button(24, 15, 14, "Toggle Space");
    mvui_button(24, 31, 12, "Save F2");
}

static int save_settings(const char *path, const odq_settings *settings,
                         char *status)
{
    if (odq_settings_save(path, settings) != ODQ_SETTINGS_OK) {
        strcpy(status, "Save failed.");
        return 0;
    }
    strcpy(status, "Settings saved.");
    return 1;
}

static int interactive(const char *path)
{
    odq_settings settings;
    unsigned selected = 0, error_line = 0;
    int result, key, dirty = 0;
    char status[32];

    result = odq_settings_load(path, &settings, &error_line);
    if (result == ODQ_SETTINGS_IO) {
        odq_settings_defaults(&settings);
        strcpy(status, "Using defaults.");
    } else if (result != ODQ_SETTINGS_OK) {
        printf("MAXVSET: syntax error on line %u\n", error_line);
        return 2;
    } else {
        strcpy(status, "Settings loaded.");
    }

    mvui_init();
    for (;;) {
        draw(&settings, selected, status);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && selected > 0)
                --selected;
            else if (key == 80 && selected + 1 < OPTION_COUNT)
                ++selected;
            else if (key == 60 && save_settings(path, &settings, status))
                dirty = 0;
            continue;
        }
        key = toupper(key);
        if (key == 27) {
            if (dirty && !save_settings(path, &settings, status))
                continue;
            break;
        }
        if (key == ' ' || key == 13) {
            unsigned *value = option_value(&settings, selected);
            *value = !*value;
            dirty = 1;
            strcpy(status, "Changed; save F2.");
        } else if (key == 'S' && save_settings(path, &settings, status)) {
            dirty = 0;
        }
    }
    mvui_restore();
    return 0;
}

static void print_settings(const odq_settings *settings)
{
    printf("AUTO_TSR=%s\n", settings->auto_tsr ? "YES" : "NO");
    printf("AUTO_ANSI=%s\n", settings->auto_ansi ? "YES" : "NO");
    printf("CONFIRM_EXIT=%s\n", settings->confirm_exit ? "YES" : "NO");
    printf("RELOAD_CATALOG=%s\n",
           settings->reload_catalog ? "YES" : "NO");
    printf("SHOW_MEMORY=%s\n", settings->show_memory ? "YES" : "NO");
    printf("HOTKEY_LAUNCH=%s\n", settings->hotkey_launch ? "YES" : "NO");
    printf("QUICK_HELP=%s\n", settings->quick_help ? "YES" : "NO");
}

int main(int argc, char **argv)
{
    const char *path = "MAXVSET.INI";
    int list = 0, check = 0, index, result;
    unsigned error_line = 0;
    odq_settings settings;

    for (index = 1; index < argc; ++index) {
        if (stricmp(argv[index], "/LIST") == 0)
            list = 1;
        else if (stricmp(argv[index], "/CHECK") == 0)
            check = 1;
        else if (strnicmp(argv[index], "/F:", 3) == 0 && argv[index][3])
            path = argv[index] + 3;
        else {
            puts("Usage: MAXVSET [/LIST|/CHECK] [/F:file]");
            return 2;
        }
    }
    if (!list && !check)
        return interactive(path);
    result = odq_settings_load(path, &settings, &error_line);
    if (result != ODQ_SETTINGS_OK) {
        if (result == ODQ_SETTINGS_IO)
            printf("MAXVSET: cannot read %s\n", path);
        else
            printf("MAXVSET: syntax error on line %u\n", error_line);
        return result == ODQ_SETTINGS_IO ? 1 : 2;
    }
    if (list)
        print_settings(&settings);
    else
        puts("MAXVSET: settings valid");
    return 0;
}
