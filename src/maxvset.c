/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Global Open MaxView settings editor. */
#include <conio.h>
#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mvui.h"
#include "settings.h"

/* the pages:  MaxView's own options, then those of DESQview's Advanced
 * Setup that MaxView has (letters as DESQview's) */
#define PAGES 9
static const char *page_names[PAGES] = {
    "Global", "Autodial", "Colors", "Keyboard", "Mouse", "Perform",
    "Swapping", "Video", "Windows"
};
static const char *page_titles[PAGES] = {
    "Global", "Auto Dialer", "Colors", "Keyboard", "Mouse", "Performance",
    "Swapping", "Video", "Window Positions"
};
static const char page_keys[PAGES] = {
    'G', 'A', 'C', 'K', 'M', 'P', 'S', 'V', 'W'
};

enum { F_BOOL, F_NUM, F_BYTE, F_TEXT };

typedef struct field {
    unsigned char page, row, col, type;
    unsigned low, high;         /* F_NUM, F_BYTE; F_TEXT:  high its size */
    unsigned offset;            /* in odq_settings */
    const char *label;          /* at column 4 (F_BOOL:  after its box) */
} field;

#define AT(member) (unsigned)offsetof(odq_settings, member)

static const field fixed[] = {
    { 0, 5, 6, F_BOOL, 0, 1, AT(auto_tsr), "Load resident API automatically" },
    { 0, 7, 6, F_BOOL, 0, 1, AT(auto_ansi), "Load ANSI console automatically" },
    { 0, 9, 6, F_BOOL, 0, 1, AT(confirm_exit), "Confirm before leaving MaxView" },
    { 0, 11, 6, F_BOOL, 0, 1, AT(reload_catalog),
      "Reload program catalogue after a child" },
    { 0, 13, 6, F_BOOL, 0, 1, AT(show_memory),
      "Show memory limits in program list" },
    { 0, 15, 6, F_BOOL, 0, 1, AT(hotkey_launch), "Launch programs by red hotkey" },
    { 0, 17, 6, F_BOOL, 0, 1, AT(quick_help), "Show the Quick Help instructions" },
    { 1, 5, 24, F_NUM, 1, 4, AT(modem_port), "Dialer port (COM)" },
    { 1, 7, 24, F_NUM, 0, 6, AT(dial_baud), "Dialer baud rate" },
    { 1, 9, 24, F_TEXT, 0, sizeof(((odq_settings *)0)->dial), AT(dial),
      "Dial command" },
    { 1, 11, 24, F_TEXT, 0, sizeof(((odq_settings *)0)->hangup), AT(hangup),
      "Hang up command" },
    { 1, 14, 24, F_TEXT, 0, sizeof(((odq_settings *)0)->access[0]), AT(access[0]),
      "Access code 1" },
    { 1, 16, 24, F_TEXT, 0, sizeof(((odq_settings *)0)->access[1]), AT(access[1]),
      "Access code 2" },
    { 1, 18, 24, F_TEXT, 0, sizeof(((odq_settings *)0)->access[2]), AT(access[2]),
      "Access code 3" },
    { 2, 5, 6, F_BOOL, 0, 1, AT(colors), "Programs in their window's colours" },
    { 3, 6, 6, F_BOOL, 0, 1, AT(learn), "Use Learn (Shift+Alt)" },
    { 4, 6, 6, F_BOOL, 0, 1, AT(mouse), "Use a mouse" },
    { 4, 8, 6, F_BOOL, 0, 1, AT(left_handed), "Left-handed (buttons swapped)" },
    { 5, 7, 30, F_NUM, 1, 15, AT(fg_ticks), "Foreground ticks" },
    { 5, 9, 30, F_NUM, 1, 15, AT(bg_ticks), "Background ticks" },
    { 5, 15, 6, F_BOOL, 0, 1, AT(printer), "Manage printer contention" },
    { 6, 6, 6, F_BOOL, 0, 1, AT(swapping),
      "Swap programs out as needed" },
    { 6, 9, 4, F_TEXT, 0, 41, AT(swap_dir), "" },    /* (40 shown) */
    { 7, 6, 6, F_BOOL, 0, 1, AT(sync_video),
      "Synchronized access (CGA snow)" },
    { 7, 9, 40, F_NUM, 0, 99, AT(blank_minutes), "Blank the screen after minutes" }
};

#define FIXED (sizeof fixed / sizeof fixed[0])
#define FIELDS (FIXED + 36 + 8)
static field fields[FIELDS];

/* the Window Positions' grid:  row, column, height, width of windows 1-9 */
static void fields_init(void)
{
    static const unsigned low[4] = { 0, 0, 1, 1 }, high[4] = { 23, 79, 23, 78 };
    unsigned i, j;

    memcpy(fields, fixed, sizeof fixed);
    for (i = 0; i < 9; ++i)
        for (j = 0; j < 4; ++j) {
            field *f = &fields[FIXED + i * 4 + j];

            f->page = 8;
            f->row = (unsigned char)(6 + i);
            f->col = (unsigned char)(17 + j * 8);
            f->type = F_BYTE;
            f->low = low[j];
            f->high = high[j];
            f->offset = AT(window[0][0]) + i * 4 + j;
            f->label = "";
        }
    for (i = 0; i < 4; ++i)             /* Colors:  windows 1-4 */
        for (j = 0; j < 2; ++j) {
            field *f = &fields[FIXED + 36 + i * 2 + j];

            f->page = 2;
            f->row = (unsigned char)(9 + i);
            f->col = (unsigned char)(15 + j * 9);
            f->type = F_BYTE;
            f->low = 0;
            f->high = j == 0 ? 15 : 7;
            f->offset = AT(color[0][0]) + i * 2 + j;
            f->label = "";
        }
}

static void *value_of(odq_settings *settings, const field *f)
{
    return (char *)settings + f->offset;
}

static unsigned number_of(odq_settings *settings, const field *f)
{
    if (f->type == F_BYTE)
        return *(unsigned char *)value_of(settings, f);
    return *(unsigned *)value_of(settings, f);
}

static unsigned field_width(const field *f)
{
    if (f->type == F_TEXT)
        return f->high - 1 > 40 ? 40 : f->high - 1;
    return 3;
}

static const char *baud_names[7] = {
    "Leave as is", "300", "600", "1200", "2400", "4800", "9600"
};

/* the field's value as shown */
static void field_text(odq_settings *settings, const field *f, char *text)
{
    if (f->type == F_BOOL)
        strcpy(text, number_of(settings, f) ? "[X]" : "[ ]");
    else if (f->type == F_TEXT)
        sprintf(text, "%-*.*s", (int)field_width(f), (int)field_width(f),
                (char *)value_of(settings, f));
    else
        sprintf(text, "%3u", number_of(settings, f));
}

static void draw(odq_settings *settings, unsigned page, unsigned selected,
                 const char *status, const char *edit)
{
    unsigned i, col = 1;
    char text[48];

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    for (i = 0; i < PAGES; ++i) {       /* the pages, their letters red */
        const char *name = page_names[i];
        unsigned k = (unsigned)(strchr(name, page_keys[i]) - name);

        mvui_fill(0, col - 1, 0, col + (unsigned)strlen(name),
                  ' ', i == page ? MVUI_ACTIVE : MVUI_MENU);
        mvui_write(0, col, name, i == page ? MVUI_ACTIVE : MVUI_MENU);
        mvui_put(0, col + k, (unsigned char)page_keys[i],
                 i == page ? MVUI_TRIGGER : MVUI_MENU_TRIGGER);
        col += (unsigned)strlen(name) + 2;
    }
    mvui_fill(2, 1, 21, 55, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 55);
    mvui_fill(2, 59, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 59, 21, 77);
    mvui_write(3, (unsigned)(28 - strlen(page_titles[page]) / 2),
               page_titles[page], MVUI_DATA_HIGH);
    switch (page) {
    case 1:
        mvui_write(7, 29, baud_names[settings->dial_baud], MVUI_DATA);
        mvui_write(13, 4, "Long distance:  put before a number", MVUI_DATA);
        break;
    case 2:
        mvui_write(8, 6, "Window   Text  Background", MVUI_DATA);
        for (i = 0; i < 4; ++i) {
            sprintf(text, "%u", i + 1);
            mvui_write(9 + i, 9, text, MVUI_DATA);
            mvui_write(9 + i, 35, " Sample ", (unsigned char)
                       (settings->color[i][1] << 4 | settings->color[i][0]));
        }
        mvui_write(14, 4, "Text 0-15 (8-15 bright), background", MVUI_DATA);
        mvui_write(15, 4, "0-7.  Windows 5-9 as 1-4 again.  The", MVUI_DATA);
        mvui_write(16, 4, "program in front:  its black and grey", MVUI_DATA);
        mvui_write(17, 4, "as these (VGA palette, text modes).", MVUI_DATA);
        break;
    case 3:
        mvui_write(8, 4, "Off:  Shift+Alt does not open Learn.", MVUI_DATA);
        break;
    case 4:
        mvui_write(11, 4, "For DESQview programs' pointers and", MVUI_DATA);
        mvui_write(12, 4, "select fields (MAXVTSR).", MVUI_DATA);
        break;
    case 5:
        mvui_write(5, 4, "Time slices in clock ticks (1-15)", MVUI_DATA);
        mvui_write(12, 4, "Tune Performance changes them while", MVUI_DATA);
        mvui_write(13, 4, "MaxView runs.", MVUI_DATA);
        mvui_write(17, 4, "A window printing waits while another", MVUI_DATA);
        mvui_write(18, 4, "printed in the last 3 seconds.", MVUI_DATA);
        break;
    case 6:
        mvui_write(8, 4, "Swapping directory:", MVUI_DATA);
        mvui_write(11, 4, "Blank:  the current directory.", MVUI_DATA);
        break;
    case 7:
        mvui_write(11, 4, "0 minutes:  never.  A key or the mouse", MVUI_DATA);
        mvui_write(12, 4, "shows it again (the key goes on).", MVUI_DATA);
        break;
    case 8:
        mvui_write(5, 6, "Window     Row  Column  Height   Width", MVUI_DATA);
        for (i = 0; i < 9; ++i) {
            sprintf(text, "%u", i + 1);
            mvui_write(6 + i, 9, text, MVUI_DATA);
        }
        mvui_write(16, 4, "Where a window opens whose program", MVUI_DATA);
        mvui_write(17, 4, "has no starting position.", MVUI_DATA);
        break;
    }
    for (i = 0; i < FIELDS; ++i) {
        const field *f = &fields[i];
        unsigned char attr = i == selected ? MVUI_ACTIVE : MVUI_DATA;

        if (f->page != page)
            continue;
        if (f->type == F_BOOL) {
            mvui_fill(f->row, 4, f->row, 52, ' ', attr);
            mvui_write(f->row, 11, f->label, attr);
        } else if (*f->label != '\0')
            mvui_write(f->row, 4, f->label, MVUI_DATA);
        if (i == selected && edit != NULL)
            sprintf(text, "%-*s", (int)field_width(f), edit);
        else
            field_text(settings, f, text);
        mvui_write(f->row, f->col, text, attr);
        if (i == selected && f->type == F_BOOL)
            mvui_put(f->row, f->col + 1, (unsigned char)text[1],
                     MVUI_TRIGGER);
    }
    mvui_write(4, 61, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(6, 61, "G A C K M P S V W", MVUI_QUICK);
    mvui_write(5, 61, "Page:", MVUI_QUICK);
    mvui_write(7, 61, "Arrows  Select", MVUI_QUICK);
    mvui_write(8, 61, "Space   Toggle", MVUI_QUICK);
    mvui_write(9, 61, "Enter   Change", MVUI_QUICK);
    mvui_write(10, 61, "F2      Save", MVUI_QUICK);
    mvui_write(11, 61, "Esc     Exit", MVUI_QUICK);
    mvui_write(14, 61, "Status:", MVUI_QUICK_HIGH);
    mvui_write(15, 61, status, MVUI_QUICK);
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

static unsigned first_field(unsigned page)
{
    unsigned i;

    for (i = 0; i < FIELDS && fields[i].page != page; ++i)
        ;
    return i;
}

/* the field on page above (dir -1) or below (+1) the selected one:  on the
 * nearest row, the nearest column */
static unsigned field_near(unsigned selected, int dir)
{
    const field *s = &fields[selected];
    unsigned i, best = selected, row = 0, dist = 0;

    for (i = 0; i < FIELDS; ++i) {
        const field *f = &fields[i];
        unsigned d = f->col > s->col ? f->col - s->col : s->col - f->col;

        if (f->page != s->page ||
            (dir < 0 ? f->row >= s->row : f->row <= s->row))
            continue;
        if (best == selected || (dir < 0 ? f->row > row : f->row < row) ||
            (f->row == row && d < dist)) {
            best = i;
            row = f->row;
            dist = d;
        }
    }
    return best;
}

/* the selected field's next (+1) or previous (-1) one on its page */
static unsigned field_step(unsigned selected, int dir)
{
    unsigned i = selected;

    do
        i = (unsigned)((int)i + dir + (int)FIELDS) % FIELDS;
    while (fields[i].page != fields[selected].page);
    return i;
}

/* Enter:  the number or text typed in its place (Enter takes, Esc not);
 * 1:  changed */
static int field_edit(odq_settings *settings, unsigned page,
                      unsigned selected, char *status)
{
    const field *f = &fields[selected];
    unsigned size = f->type == F_TEXT ? f->high : 4, n;
    char edit[64];
    int key;

    if (f->type == F_TEXT)
        strcpy(edit, (char *)value_of(settings, f));
    else
        sprintf(edit, "%u", number_of(settings, f));
    for (;;) {
        n = (unsigned)strlen(edit);
        draw(settings, page, selected, status, edit);
        key = getch();
        if (key == 0 || key == 0xe0) {
            getch();
            continue;
        }
        if (key == 27)
            return 0;
        if (key == 8 && n != 0)
            edit[n - 1] = '\0';
        else if (key == 13)
            break;
        else if (key >= ' ' && key < 127 && n + 1 < size &&
                 (f->type == F_TEXT || isdigit(key))) {
            edit[n] = (char)(f->type == F_TEXT ? toupper(key) : key);
            edit[n + 1] = '\0';
        }
    }
    if (f->type == F_TEXT) {
        strcpy((char *)value_of(settings, f), edit);
        return 1;
    }
    n = (unsigned)atoi(edit);
    if (edit[0] == '\0' || n < f->low || n > f->high) {
        sprintf(status, "From %u to %u.", f->low, f->high);
        return 0;
    }
    if (f->type == F_BYTE)
        *(unsigned char *)value_of(settings, f) = (unsigned char)n;
    else
        *(unsigned *)value_of(settings, f) = n;
    return 1;
}

static int interactive(const char *path)
{
    odq_settings settings;
    unsigned page = 0, selected = 0, error_line = 0, i;
    int result, key, dirty = 0;
    char status[32];

    fields_init();
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
        draw(&settings, page, selected, status, NULL);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72)
                selected = field_near(selected, -1);
            else if (key == 80)
                selected = field_near(selected, 1);
            else if (key == 75)
                selected = field_step(selected, -1);
            else if (key == 77)
                selected = field_step(selected, 1);
            else if (key == 73 || key == 81) {          /* PgUp, PgDn */
                page = (page + (key == 73 ? PAGES - 1 : 1)) % PAGES;
                selected = first_field(page);
            } else if (key == 60 && save_settings(path, &settings, status))
                dirty = 0;
            continue;
        }
        key = toupper(key);
        if (key == 27) {
            if (dirty && !save_settings(path, &settings, status))
                continue;
            break;
        }
        if (key == 9) {
            selected = field_step(selected, 1);
            continue;
        }
        for (i = 0; i < PAGES && page_keys[i] != key; ++i)
            ;
        if (i < PAGES) {
            page = i;
            selected = first_field(page);
        } else if (fields[selected].type == F_BOOL &&
                   (key == ' ' || key == 13)) {
            unsigned *value = value_of(&settings, &fields[selected]);

            *value = !*value;
            dirty = 1;
            strcpy(status, "Changed; save F2.");
        } else if (fields[selected].type != F_BOOL && key == 13 &&
                   field_edit(&settings, page, selected, status)) {
            dirty = 1;
            strcpy(status, "Changed; save F2.");
        }
    }
    mvui_restore();
    return 0;
}

static void print_settings(const odq_settings *settings)
{
    unsigned index;

    printf("AUTO_TSR=%s\n", settings->auto_tsr ? "YES" : "NO");
    printf("AUTO_ANSI=%s\n", settings->auto_ansi ? "YES" : "NO");
    printf("CONFIRM_EXIT=%s\n", settings->confirm_exit ? "YES" : "NO");
    printf("RELOAD_CATALOG=%s\n",
           settings->reload_catalog ? "YES" : "NO");
    printf("SHOW_MEMORY=%s\n", settings->show_memory ? "YES" : "NO");
    printf("HOTKEY_LAUNCH=%s\n", settings->hotkey_launch ? "YES" : "NO");
    printf("QUICK_HELP=%s\n", settings->quick_help ? "YES" : "NO");
    printf("MODEM_PORT=%u\n", settings->modem_port);
    printf("DIAL=%s\n", settings->dial);
    printf("HANGUP=%s\n", settings->hangup);
    printf("ACCESS1=%s\n", settings->access[0]);
    printf("ACCESS2=%s\n", settings->access[1]);
    printf("ACCESS3=%s\n", settings->access[2]);
    printf("DIAL_BAUD=%u\n", settings->dial_baud);
    printf("FOREGROUND=%u\n", settings->fg_ticks);
    printf("BACKGROUND=%u\n", settings->bg_ticks);
    printf("SWAPPING=%s\n", settings->swapping ? "YES" : "NO");
    printf("SWAP_DIR=%s\n", settings->swap_dir);
    printf("LEARN=%s\n", settings->learn ? "YES" : "NO");
    printf("MOUSE=%s\n", settings->mouse ? "YES" : "NO");
    printf("LEFT_HANDED=%s\n", settings->left_handed ? "YES" : "NO");
    printf("BLANK=%u\n", settings->blank_minutes);
    printf("SYNC_VIDEO=%s\n", settings->sync_video ? "YES" : "NO");
    printf("PRINTER_CONTENTION=%s\n", settings->printer ? "YES" : "NO");
    printf("COLORS=%s\n", settings->colors ? "YES" : "NO");
    for (index = 0; index < 4; ++index)
        printf("COLOR%u=%u,%u\n", index + 1,
               settings->color[index][0], settings->color[index][1]);
    for (index = 0; index < 9; ++index)
        printf("WINDOW%u=%u,%u,%u,%u\n", index + 1,
               settings->window[index][0], settings->window[index][1],
               settings->window[index][2], settings->window[index][3]);
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
