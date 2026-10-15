/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Open MaxView catalogue editor: independent replacement for Add/Change Program. */
#include <conio.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "catalog.h"
#include "mvui.h"

#define CFG_PATH_LEN 128

static void draw_desktop(const odq_catalog *catalog, unsigned selected,
                         const char *status)
{
    unsigned index, first, row;

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "Programs", MVUI_MENU);
    mvui_put(0, 1, 'P', MVUI_MENU_TRIGGER);
    mvui_write(0, 63, "MaxView Setup", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 21, 55, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 55);
    mvui_fill(2, 59, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 59, 21, 77);
    mvui_write(3, 18, "Configured Programs", MVUI_DATA_HIGH);
    mvui_write(4, 61, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(6, 61, "Ins/A  Add", MVUI_QUICK);
    mvui_write(7, 61, "Enter  Change", MVUI_QUICK);
    mvui_write(8, 61, "Del/D  Delete", MVUI_QUICK);
    mvui_write(9, 61, "F2/S   Save", MVUI_QUICK);
    mvui_write(10, 61, "Esc    Exit", MVUI_QUICK);
    mvui_write(13, 61, "Status:", MVUI_QUICK_HIGH);
    mvui_write(14, 61, status, MVUI_QUICK);

    if (catalog->count == 0) {
        mvui_write(6, 5, "No programs configured. Press Insert to add one.",
                   MVUI_DATA);
    } else {
        first = selected >= 14 ? selected - 13 : 0;
        for (index = first; index < catalog->count && index < first + 14;
             ++index) {
            unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
            row = 5 + index - first;
            mvui_fill(row, 3, row, 53, ' ', attr);
            mvui_put(row, 5, catalog->programs[index].hotkey,
                     index == selected ? MVUI_TRIGGER : MVUI_DATA_HIGH);
            mvui_write(row, 6, ") ", attr);
            mvui_write(row, 8, catalog->programs[index].title, attr);
        }
    }
    mvui_button(24, 1, 12, "Exit Esc");
    mvui_button(24, 15, 12, "Add Ins");
    mvui_button(24, 29, 14, "Change Enter");
    mvui_button(24, 45, 12, "Save F2");
}

static int input_field(unsigned row, unsigned col, unsigned width,
                       char *value, unsigned capacity)
{
    char original[ODQ_COMMAND_LEN + 1];
    unsigned length;
    int key;

    strcpy(original, value);
    length = strlen(value);
    for (;;) {
        unsigned shown = length > width ? length - width : 0;
        mvui_fill(row, col, row, col + width - 1, ' ', MVUI_QUICK);
        mvui_write(row, col, value + shown, MVUI_QUICK_HIGH);
        key = getch();
        if (key == 0 || key == 0xe0) {
            getch();
            continue;
        }
        if (key == 27) {
            strcpy(value, original);
            return 0;
        }
        if (key == 13)
            return 1;
        if (key == 8 && length != 0) {
            value[--length] = '\0';
        } else if (isprint((unsigned char)key) && key != '|' &&
                   length + 1 < capacity) {
            value[length++] = (char)key;
            value[length] = '\0';
        }
    }
}

static int parse_number(const char *text, unsigned *value)
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

static int hotkey_available(const odq_catalog *catalog, unsigned editing,
                            char hotkey)
{
    unsigned index;
    hotkey = (char)toupper((unsigned char)hotkey);
    for (index = 0; index < catalog->count; ++index)
        if (index != editing && catalog->programs[index].hotkey == hotkey)
            return 0;
    return 1;
}

static int edit_program(odq_catalog *catalog, unsigned index, int adding,
                        char *status)
{
    odq_program work;
    char hotkey[2], minimum[6], maximum[6];

    if (adding) {
        memset(&work, 0, sizeof(work));
        work.min_kb = 128;
        work.max_kb = 640;
    } else {
        work = catalog->programs[index];
    }
    hotkey[0] = work.hotkey;
    hotkey[1] = '\0';
    sprintf(minimum, "%u", work.min_kb);
    sprintf(maximum, "%u", work.max_kb);

    mvui_frame(3, 7, 20, 72, adding ? "Add Program" : "Change Program");
    mvui_write(5, 11, "Hotkey", MVUI_ACTIVE);
    mvui_write(7, 11, "Title", MVUI_ACTIVE);
    mvui_write(9, 11, "Command", MVUI_ACTIVE);
    mvui_write(11, 11, "Directory", MVUI_ACTIVE);
    mvui_write(13, 11, "Minimum KB", MVUI_ACTIVE);
    mvui_write(15, 11, "Maximum KB (0=unlimited)", MVUI_ACTIVE);
    if (work.profile.version != 0)
        mvui_write(17, 11, "Imported process profile is preserved.",
                   MVUI_DATA_HIGH);
    mvui_write(18, 11, "Enter accepts each field; Esc cancels.", MVUI_ACTIVE);

    if (!input_field(5, 38, 1, hotkey, sizeof(hotkey)) ||
        !input_field(7, 24, 38, work.title, sizeof(work.title)) ||
        !input_field(9, 24, 44, work.command, sizeof(work.command)) ||
        !input_field(11, 24, 44, work.directory, sizeof(work.directory)) ||
        !input_field(13, 38, 5, minimum, sizeof(minimum)) ||
        !input_field(15, 38, 5, maximum, sizeof(maximum))) {
        strcpy(status, "Edit cancelled.");
        return 0;
    }
    if (hotkey[0] == '\0' || !parse_number(minimum, &work.min_kb) ||
        !parse_number(maximum, &work.max_kb)) {
        strcpy(status, "Invalid hotkey or memory value.");
        return 0;
    }
    work.hotkey = (char)toupper((unsigned char)hotkey[0]);
    if (!hotkey_available(catalog, adding ? catalog->count : index,
                          work.hotkey)) {
        strcpy(status, "That hotkey is already in use.");
        return 0;
    }
    if (!odq_program_valid(&work)) {
        strcpy(status, "Title, command or memory range is invalid.");
        return 0;
    }
    if (adding)
        ++catalog->count;
    catalog->programs[index] = work;
    strcpy(status, adding ? "Program added; save with F2."
                          : "Program changed; save with F2.");
    return 1;
}

static int confirm_delete(const odq_program *program)
{
    int key;
    mvui_frame(8, 14, 15, 65, "Delete Program");
    mvui_write(10, 18, "Delete", MVUI_ACTIVE);
    mvui_write(10, 25, program->title, MVUI_ACTIVE);
    mvui_write(12, 18, "Press Y to delete or N to keep it.", MVUI_ACTIVE);
    do {
        key = toupper(getch());
    } while (key != 'Y' && key != 'N' && key != 27);
    return key == 'Y';
}

static int save_catalog(const char *path, const odq_catalog *catalog,
                        char *status)
{
    int result = odq_catalog_save(path, catalog);
    if (result == ODQ_CATALOG_OK)
        strcpy(status, "Catalogue saved.");
    else
        strcpy(status, "Unable to save catalogue.");
    return result == ODQ_CATALOG_OK;
}

static int interactive(const char *path)
{
    odq_catalog catalog;
    unsigned selected = 0, error_line = 0, index;
    int result, key, dirty = 0;
    char status[48];

    result = odq_catalog_load(path, &catalog, &error_line);
    if (result == ODQ_CATALOG_IO) {
        catalog.count = 0;
        strcpy(status, "New catalogue.");
    } else if (result != ODQ_CATALOG_OK) {
        printf("MAXVAPP: syntax error on line %u\n", error_line);
        return 2;
    } else {
        sprintf(status, "%u program(s) loaded.", catalog.count);
    }

    mvui_init();
    for (;;) {
        draw_desktop(&catalog, selected, status);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && selected > 0)
                --selected;
            else if (key == 80 && selected + 1 < catalog.count)
                ++selected;
            else if (key == 82 && catalog.count < ODQ_MAX_PROGRAMS) {
                if (edit_program(&catalog, catalog.count, 1, status)) {
                    selected = catalog.count - 1;
                    dirty = 1;
                }
            } else if (key == 83 && catalog.count != 0 &&
                       confirm_delete(&catalog.programs[selected])) {
                for (index = selected + 1; index < catalog.count; ++index)
                    catalog.programs[index - 1] = catalog.programs[index];
                --catalog.count;
                if (selected >= catalog.count && selected != 0)
                    --selected;
                dirty = 1;
                strcpy(status, "Program deleted; save with F2.");
            } else if (key == 60 && save_catalog(path, &catalog, status)) {
                dirty = 0;
            }
            continue;
        }
        key = toupper(key);
        if (key == 27) {
            if (dirty && !save_catalog(path, &catalog, status))
                continue;
            break;
        }
        if ((key == 'A') && catalog.count < ODQ_MAX_PROGRAMS) {
            if (edit_program(&catalog, catalog.count, 1, status)) {
                selected = catalog.count - 1;
                dirty = 1;
            }
        } else if ((key == 13 || key == 'C') && catalog.count != 0) {
            if (edit_program(&catalog, selected, 0, status))
                dirty = 1;
        } else if (key == 'D' && catalog.count != 0 &&
                   confirm_delete(&catalog.programs[selected])) {
            for (index = selected + 1; index < catalog.count; ++index)
                catalog.programs[index - 1] = catalog.programs[index];
            --catalog.count;
            if (selected >= catalog.count && selected != 0)
                --selected;
            dirty = 1;
            strcpy(status, "Program deleted; save with F2.");
        } else if (key == 'S' && save_catalog(path, &catalog, status)) {
            dirty = 0;
        }
    }
    mvui_restore();
    return 0;
}

int main(int argc, char **argv)
{
    const char *path = "MAXVIEW.CFG";
    int list = 0, check = 0, index, result;
    unsigned error_line = 0, item;
    odq_catalog catalog;

    for (index = 1; index < argc; ++index) {
        if (stricmp(argv[index], "/LIST") == 0)
            list = 1;
        else if (stricmp(argv[index], "/CHECK") == 0)
            check = 1;
        else if (strnicmp(argv[index], "/F:", 3) == 0 && argv[index][3])
            path = argv[index] + 3;
        else {
            puts("Usage: MAXVAPP [/LIST|/CHECK] [/F:file]");
            return 2;
        }
    }
    if (!list && !check)
        return interactive(path);
    result = odq_catalog_load(path, &catalog, &error_line);
    if (result != ODQ_CATALOG_OK) {
        if (result == ODQ_CATALOG_IO)
            printf("MAXVAPP: cannot read %s\n", path);
        else
            printf("MAXVAPP: syntax error on line %u\n", error_line);
        return result == ODQ_CATALOG_IO ? 1 : 2;
    }
    if (list)
        for (item = 0; item < catalog.count; ++item) {
            odq_program *program = &catalog.programs[item];
            printf("%c|%s|%s|%s|%u|%u", program->hotkey,
                   program->title, program->command, program->directory,
                   program->min_kb, program->max_kb);
            if (program->profile.version != 0) {
                odq_process_profile *profile = &program->profile;
                printf("|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u|%u",
                       profile->version, profile->source_version,
                       profile->system_kb, profile->script_bytes,
                       profile->idle_polls, profile->max_ems_kb,
                       profile->extra_system, profile->rows,
                       profile->columns, profile->text_pages,
                       profile->graphics_pages, profile->serial_ports,
                       profile->protection, profile->flags1,
                       profile->flags2, profile->flags3, profile->flags4);
            }
            putchar('\n');
        }
    else
        printf("MAXVAPP: %u valid program(s)\n", catalog.count);
    return 0;
}
