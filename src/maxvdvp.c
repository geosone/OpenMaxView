/* SPDX-License-Identifier: GPL-3.0-or-later */
/* DESQview Program Information File importer for Open MaxView. */
#include <conio.h>
#include <ctype.h>
#include <dos.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "catalog.h"
#include "dvp.h"
#include "mvui.h"

enum command_mode {
    MODE_INTERACTIVE,
    MODE_CHECK,
    MODE_LIST,
    MODE_IMPORT
};

#define MAX_DVP_FILES 32

static int select_dvp_file(char *path)
{
    struct find_t entry;
    char files[MAX_DVP_FILES][13];
    unsigned count = 0, selected = 0, first, index, row;
    int result, key;

    result = _dos_findfirst("*.DVP", _A_NORMAL | _A_RDONLY | _A_ARCH,
                            &entry);
    while (result == 0 && count < MAX_DVP_FILES) {
        strcpy(files[count++], entry.name);
        result = _dos_findnext(&entry);
    }
    if (count != 0)
        _dos_findclose(&entry);
    if (count == 0) {
        puts("MAXVDVP: no .DVP files in the current directory");
        return 0;
    }

    mvui_init();
    for (;;) {
        mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219,
                  MVUI_BACKGROUND);
        mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
        mvui_write(0, 1, "DVP Import", MVUI_MENU);
        mvui_put(0, 1, 'D', MVUI_MENU_TRIGGER);
        mvui_write(0, 60, "Open MaxView 0.8", MVUI_MENU_TRIGGER);
        mvui_fill(2, 2, 21, 57, ' ', MVUI_DATA);
        mvui_shadow(2, 2, 21, 57);
        mvui_fill(2, 62, 21, 77, ' ', MVUI_QUICK);
        mvui_shadow(2, 62, 21, 77);
        mvui_write(3, 17, "DESQview Program Files", MVUI_DATA_HIGH);
        mvui_write(4, 64, "Quick Help", MVUI_QUICK_HIGH);
        mvui_write(7, 64, "Up/Down move", MVUI_QUICK);
        mvui_write(9, 64, "Enter opens", MVUI_QUICK);
        mvui_write(11, 64, "Esc cancels", MVUI_QUICK);
        first = selected >= 14 ? selected - 13 : 0;
        for (index = first; index < count && index < first + 14; ++index) {
            unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
            row = 5 + index - first;
            mvui_fill(row, 5, row, 54, ' ', attr);
            mvui_write(row, 8, files[index], attr);
        }
        mvui_button(24, 2, 15, "Cancel Esc");
        mvui_button(24, 20, 18, "Open Enter");
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && selected > 0) --selected;
            else if (key == 80 && selected + 1 < count) ++selected;
            continue;
        }
        if (key == 27) {
            mvui_restore();
            return 0;
        }
        if (key == 13) {
            strcpy(path, files[selected]);
            mvui_restore();
            return 1;
        }
    }
}

static int hotkey_used(const odq_catalog *catalog, char key)
{
    unsigned index;
    key = (char)toupper((unsigned char)key);
    for (index = 0; index < catalog->count; ++index)
        if (toupper((unsigned char)catalog->programs[index].hotkey) == key)
            return 1;
    return 0;
}

static char choose_hotkey(const dvp_info *info, const odq_catalog *catalog,
                          char requested)
{
    unsigned index;
    char key;

    if (requested != 0 && isprint((unsigned char)requested) &&
        requested != '|' && !hotkey_used(catalog, requested))
        return (char)toupper((unsigned char)requested);
    for (index = 0; info->menu_keys[index] != '\0'; ++index) {
        key = (char)toupper((unsigned char)info->menu_keys[index]);
        if (isalnum((unsigned char)key) && !hotkey_used(catalog, key))
            return key;
    }
    for (index = 0; info->title[index] != '\0'; ++index) {
        key = (char)toupper((unsigned char)info->title[index]);
        if (isalnum((unsigned char)key) && !hotkey_used(catalog, key))
            return key;
    }
    for (key = 'A'; key <= 'Z'; ++key)
        if (!hotkey_used(catalog, key)) return key;
    for (key = '0'; key <= '9'; ++key)
        if (!hotkey_used(catalog, key)) return key;
    return 0;
}

static int command_used(const odq_catalog *catalog, const char *command)
{
    unsigned index;
    for (index = 0; index < catalog->count; ++index)
        if (stricmp(catalog->programs[index].command, command) == 0)
            return 1;
    return 0;
}

static const char *result_text(int result)
{
    switch (result) {
    case DVP_IO: return "unable to read file";
    case DVP_TOO_SHORT: return "file is shorter than a DESQview DVP";
    case DVP_CHECKSUM: return "base PIF/DVP checksum is invalid";
    case DVP_INVALID: return "required DVP fields are invalid";
    default: return "unknown DVP error";
    }
}

static int load_catalog(const char *path, odq_catalog *catalog)
{
    unsigned line;
    int result;

    if (access(path, 0) != 0) {
        catalog->count = 0;
        return 1;
    }
    result = odq_catalog_load(path, catalog, &line);
    if (result != ODQ_CATALOG_OK) {
        if (line != 0)
            printf("MAXVDVP: invalid catalogue line %u\n", line);
        else
            puts("MAXVDVP: unable to read program catalogue");
        return 0;
    }
    return 1;
}

static int prepare_program(const dvp_info *info, odq_catalog *catalog,
                           char requested, odq_program *program)
{
    char hotkey;

    if (catalog->count == ODQ_MAX_PROGRAMS) {
        puts("MAXVDVP: program catalogue is full");
        return 0;
    }
    hotkey = choose_hotkey(info, catalog, requested);
    if (hotkey == 0) {
        puts("MAXVDVP: no unused catalogue hotkey is available");
        return 0;
    }
    if (dvp_make_program(info, hotkey, program) != DVP_OK) {
        puts("MAXVDVP: DVP fields do not fit the Open MaxView catalogue");
        return 0;
    }
    if (command_used(catalog, program->command)) {
        puts("MAXVDVP: program command is already in the catalogue");
        return 0;
    }
    return 1;
}

static int import_program(const char *catalog_path, odq_catalog *catalog,
                          const odq_program *program)
{
    catalog->programs[catalog->count++] = *program;
    if (odq_catalog_save(catalog_path, catalog) != ODQ_CATALOG_OK) {
        --catalog->count;
        puts("MAXVDVP: unable to save program catalogue");
        return 0;
    }
    printf("MAXVDVP: imported %s as hotkey %c\n",
           program->title, program->hotkey);
    return 1;
}

static void show_value(unsigned row, const char *label, const char *value)
{
    mvui_write(row, 4, label, MVUI_DATA_HIGH);
    mvui_write(row, 24, value, MVUI_DATA);
}

static int interactive(const dvp_info *info, const char *catalog_path,
                       odq_catalog *catalog, char requested)
{
    odq_program program;
    char value[32];
    int key;

    if (!prepare_program(info, catalog, requested, &program))
        return 3;
    mvui_init();
    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "DVP Import", MVUI_MENU);
    mvui_put(0, 1, 'D', MVUI_MENU_TRIGGER);
    mvui_write(0, 60, "Open MaxView 0.8", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 21, 58, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 58);
    mvui_fill(2, 62, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 62, 21, 77);
    mvui_write(3, 18, "DESQview Program Import", MVUI_DATA_HIGH);
    show_value(5, "Program", program.title);
    show_value(7, "Command", program.command);
    show_value(9, "Directory", program.directory);
    sprintf(value, "%u KB", program.min_kb);
    show_value(11, "Minimum memory", value);
    sprintf(value, "%u KB", program.max_kb);
    show_value(12, "Maximum memory", value);
    value[0] = program.hotkey;
    value[1] = '\0';
    show_value(14, "Open-menu key", value);
    sprintf(value, "%u / %u", info->text_pages, info->graphics_pages);
    show_value(16, "Text/graphics pages", value);
    sprintf(value, "%u", info->version);
    show_value(18, "DVP version", info->has_v20 ? value : "1.x");
    mvui_write(4, 64, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(7, 64, "Enter imports", MVUI_QUICK);
    mvui_write(9, 64, "Esc cancels", MVUI_QUICK);
    mvui_write(12, 64, "DVP profile", MVUI_QUICK_HIGH);
    mvui_write(13, 64, "is retained", MVUI_QUICK);
    mvui_write(14, 64, "for later 1.x", MVUI_QUICK);
    mvui_write(15, 64, "enforcement.", MVUI_QUICK);
    mvui_button(24, 2, 15, "Cancel Esc");
    mvui_button(24, 20, 18, "Import Enter");
    for (;;) {
        key = getch();
        if (key == 0 || key == 0xe0) {
            getch();
            continue;
        }
        if (key == 27) {
            mvui_restore();
            return 0;
        }
        if (key == 13) {
            mvui_restore();
            return import_program(catalog_path, catalog, &program) ? 0 : 4;
        }
    }
}

static void list_info(const dvp_info *info)
{
    printf("TITLE=%s\n", info->title);
    printf("PATH=%s\n", info->pathname);
    printf("DIRECTORY=%s\n", info->directory);
    printf("DEFAULT_DRIVE=%c\n", info->default_drive);
    printf("PARAMETERS=%s\n", info->parameters);
    printf("MENU_KEYS=%s\n", info->menu_keys);
    printf("MIN_KB=%u\nMAX_KB=%u\n", info->min_kb, info->max_kb);
    printf("SYSTEM_KB=%u\nTEXT_PAGES=%u\n", info->system_kb,
           info->text_pages);
    printf("ROWS=%u\nCOLUMNS=%u\n", info->rows, info->columns);
    printf("DVP_VERSION=%u\nSCRIPT_BYTES=%u\nIDLE_POLLS=%u\n",
           info->version, info->script_bytes, info->idle_polls);
    printf("MAX_EMS_KB=%u\nGRAPHICS_PAGES=%u\n", info->max_ems_kb,
           info->graphics_pages);
    printf("SERIAL_PORTS=%u\nPROTECTION=%u\n", info->serial_ports,
           info->protection);
    printf("FLAGS=%02X,%02X,%02X,%02X\n", info->flags1, info->flags2,
           info->flags3, info->flags4);
}

static void usage(void)
{
    puts("Usage: MAXVDVP file.dvp [/F:catalog] [/K:key]");
    puts("       MAXVDVP /CHECK|/LIST file.dvp");
    puts("       MAXVDVP /IMPORT file.dvp [/F:catalog] [/K:key]");
}

int main(int argc, char **argv)
{
    enum command_mode mode = MODE_INTERACTIVE;
    const char *dvp_path = NULL;
    char selected_path[128];
    const char *catalog_path = "MAXVIEW.CFG";
    char requested = 0;
    dvp_info info;
    odq_catalog catalog;
    odq_program program;
    int index, result;

    for (index = 1; index < argc; ++index) {
        if (stricmp(argv[index], "/CHECK") == 0)
            mode = MODE_CHECK;
        else if (stricmp(argv[index], "/LIST") == 0)
            mode = MODE_LIST;
        else if (stricmp(argv[index], "/IMPORT") == 0)
            mode = MODE_IMPORT;
        else if (strnicmp(argv[index], "/F:", 3) == 0 && argv[index][3])
            catalog_path = argv[index] + 3;
        else if (strnicmp(argv[index], "/K:", 3) == 0 && argv[index][3] &&
                 argv[index][4] == '\0')
            requested = argv[index][3];
        else if (argv[index][0] != '/' && dvp_path == NULL)
            dvp_path = argv[index];
        else {
            usage();
            return 2;
        }
    }
    if (dvp_path == NULL) {
        if (mode != MODE_INTERACTIVE) {
            usage();
            return 2;
        }
        if (!select_dvp_file(selected_path))
            return 1;
        dvp_path = selected_path;
    }
    result = dvp_load(dvp_path, &info);
    if (result != DVP_OK) {
        printf("MAXVDVP: %s: %s\n", dvp_path, result_text(result));
        return 3;
    }
    if (mode == MODE_CHECK) {
        printf("MAXVDVP: valid DVP for %s\n", info.title);
        return 0;
    }
    if (mode == MODE_LIST) {
        list_info(&info);
        return 0;
    }
    if (!load_catalog(catalog_path, &catalog))
        return 4;
    if (mode == MODE_IMPORT) {
        if (!prepare_program(&info, &catalog, requested, &program))
            return 5;
        return import_program(catalog_path, &catalog, &program) ? 0 : 6;
    }
    return interactive(&info, catalog_path, &catalog, requested);
}
