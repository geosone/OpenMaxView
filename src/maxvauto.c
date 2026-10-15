/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Automatic DOS program discovery for Open MaxView. */
#include <conio.h>
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "autodetect.h"
#include "catalog.h"
#include "mvui.h"

#define MVA_PATH_LEN       128
#define MVA_MAX_FOUND      MVA_MAX_RULES
#define MVA_MAX_ROOTS      8
#define MVA_MAX_SCAN_DIRS  128

typedef struct mva_found {
    unsigned rule_index;
    char directory[ODQ_DIR_LEN + 1];
    int selected;
} mva_found;

typedef struct mva_scan {
    const mva_rules *rules;
    const odq_catalog *catalog;
    mva_found found[MVA_MAX_FOUND];
    unsigned count;
} mva_scan;

static int join_path(char *target, unsigned capacity, const char *directory,
                     const char *name)
{
    size_t directory_length = strlen(directory);
    size_t name_length = strlen(name);
    int separator = directory_length != 0 &&
                    directory[directory_length - 1] != '\\' &&
                    directory[directory_length - 1] != '/';

    if (directory_length + (separator ? 1 : 0) + name_length + 1 > capacity)
        return 0;
    strcpy(target, directory);
    if (separator) strcat(target, "\\");
    strcat(target, name);
    return 1;
}

static int rule_already_found(const mva_scan *scan, unsigned rule_index)
{
    unsigned index;
    for (index = 0; index < scan->count; ++index)
        if (scan->found[index].rule_index == rule_index)
            return 1;
    return 0;
}

static void scan_directory(mva_scan *scan, const char *directory)
{
    unsigned index;
    char candidate[MVA_PATH_LEN * 2];

    if (*directory == '\0' || strlen(directory) > ODQ_DIR_LEN)
        return;
    for (index = 0; index < scan->rules->count &&
                    scan->count < MVA_MAX_FOUND; ++index) {
        const mva_rule *rule = &scan->rules->rules[index];
        mva_found *found;
        if (rule_already_found(scan, index) ||
            mva_catalog_has_file(scan->catalog, rule->filename) ||
            !join_path(candidate, sizeof(candidate), directory,
                       rule->filename) ||
            access(candidate, 0) != 0)
            continue;
        found = &scan->found[scan->count++];
        found->rule_index = index;
        strcpy(found->directory, directory);
        found->selected = 1;
    }
}

static void scan_tree(mva_scan *scan, const char *directory, unsigned depth)
{
    static char directories[MVA_MAX_SCAN_DIRS][ODQ_DIR_LEN + 1];
    struct find_t entry;
    char pattern[MVA_PATH_LEN * 2], child[MVA_PATH_LEN * 2];
    unsigned result, current = 0, count = 0;

    (void)depth;
    if (strlen(directory) > ODQ_DIR_LEN)
        return;
    strcpy(directories[count++], directory);
    while (current < count && scan->count < MVA_MAX_FOUND) {
        const char *active = directories[current++];
        scan_directory(scan, active);
        if (!join_path(pattern, sizeof(pattern), active, "*.*"))
            continue;
        result = _dos_findfirst(pattern, _A_SUBDIR, &entry);
        if (result == 0) {
            do {
                if ((entry.attrib & _A_SUBDIR) != 0 &&
                    strcmp(entry.name, ".") != 0 &&
                    strcmp(entry.name, "..") != 0 &&
                    count < MVA_MAX_SCAN_DIRS &&
                    join_path(child, sizeof(child), active, entry.name) &&
                    strlen(child) <= ODQ_DIR_LEN)
                    strcpy(directories[count++], child);
                result = _dos_findnext(&entry);
            } while (result == 0);
            _dos_findclose(&entry);
        }
    }
}

static void scan_path(mva_scan *scan)
{
    const char *path = getenv("PATH");
    char directory[ODQ_DIR_LEN + 1];
    unsigned length;

    scan_directory(scan, ".");
    if (path == NULL)
        return;
    while (*path != '\0') {
        length = 0;
        while (*path != '\0' && *path != ';') {
            if (length < ODQ_DIR_LEN)
                directory[length++] = *path;
            ++path;
        }
        directory[length] = '\0';
        if (*path == ';') ++path;
        if (length != 0)
            scan_directory(scan, directory);
    }
}

static void run_scan(mva_scan *scan, const char **roots, unsigned root_count)
{
    unsigned index;
    scan->count = 0;
    scan_path(scan);
    for (index = 0; index < root_count; ++index)
        scan_tree(scan, roots[index], 0);
}

static void draw_desktop(const mva_scan *scan, unsigned selected,
                         const char *status)
{
    unsigned index, first, row;

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "Auto Setup", MVUI_MENU);
    mvui_put(0, 1, 'A', MVUI_MENU_TRIGGER);
    mvui_write(0, 60, "Open MaxView 0.8", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 21, 57, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 57);
    mvui_fill(2, 61, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 61, 21, 77);
    mvui_write(3, 15, "Detected DOS Programs", MVUI_DATA_HIGH);
    mvui_write(4, 63, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(6, 63, "Up/Down Move", MVUI_QUICK);
    mvui_write(7, 63, "Space Select", MVUI_QUICK);
    mvui_write(8, 63, "A Select all", MVUI_QUICK);
    mvui_write(9, 63, "N Select none", MVUI_QUICK);
    mvui_write(10, 63, "Enter Apply", MVUI_QUICK);
    mvui_write(11, 63, "Esc Exit", MVUI_QUICK);
    mvui_write(14, 63, "Status:", MVUI_QUICK_HIGH);
    mvui_write(15, 63, status, MVUI_QUICK);

    if (scan->count == 0) {
        mvui_write(7, 5, "No unconfigured programs were detected.", MVUI_DATA);
        mvui_write(9, 5, "Use /R:directory to scan another directory tree.",
                   MVUI_DATA);
    } else {
        first = selected >= 14 ? selected - 13 : 0;
        for (index = first; index < scan->count && index < first + 14;
             ++index) {
            const mva_found *found = &scan->found[index];
            const mva_rule *rule = &scan->rules->rules[found->rule_index];
            unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
            row = 5 + index - first;
            mvui_fill(row, 3, row, 55, ' ', attr);
            mvui_write(row, 4, found->selected ? "[X]" : "[ ]", attr);
            mvui_write(row, 9, rule->title, attr);
            mvui_write(row, 40, rule->filename,
                       index == selected ? MVUI_TRIGGER : MVUI_DATA_HIGH);
        }
    }
    mvui_button(24, 1, 12, "Exit Esc");
    mvui_button(24, 15, 14, "Toggle Space");
    mvui_button(24, 31, 14, "All A");
    mvui_button(24, 47, 14, "Apply Enter");
}

static int apply_found(const char *catalog_path, odq_catalog *catalog,
                       const mva_scan *scan, unsigned *added)
{
    unsigned index;
    *added = 0;
    for (index = 0; index < scan->count; ++index) {
        const mva_found *found = &scan->found[index];
        if (found->selected &&
            mva_catalog_add(catalog,
                            &scan->rules->rules[found->rule_index],
                            found->directory) == MVA_OK)
            ++*added;
    }
    if (*added == 0)
        return MVA_OK;
    return odq_catalog_save(catalog_path, catalog) == ODQ_CATALOG_OK ?
           MVA_OK : MVA_IO;
}

static int interactive(const char *catalog_path, odq_catalog *catalog,
                       mva_scan *scan)
{
    unsigned selected = 0, index, added;
    int key, result;
    char status[48];

    sprintf(status, "%u new program(s)", scan->count);
    mvui_init();
    for (;;) {
        draw_desktop(scan, selected, status);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && selected > 0) --selected;
            else if (key == 80 && selected + 1 < scan->count) ++selected;
            continue;
        }
        if (key == 27) {
            mvui_restore();
            return 0;
        }
        key = toupper(key);
        if (key == ' ' && scan->count != 0) {
            scan->found[selected].selected = !scan->found[selected].selected;
        } else if (key == 'A') {
            for (index = 0; index < scan->count; ++index)
                scan->found[index].selected = 1;
            strcpy(status, "All selected.");
        } else if (key == 'N') {
            for (index = 0; index < scan->count; ++index)
                scan->found[index].selected = 0;
            strcpy(status, "Selection cleared.");
        } else if (key == 13 && scan->count != 0) {
            result = apply_found(catalog_path, catalog, scan, &added);
            mvui_restore();
            if (result != MVA_OK) {
                puts("MAXVAUTO: unable to save program catalogue");
                return 3;
            }
            printf("MAXVAUTO: added %u program(s)\n", added);
            return 0;
        }
    }
}

static void usage(void)
{
    puts("Usage: MAXVAUTO [/SCAN|/APPLY|/CHECK] [/F:catalog] [/D:database]");
    puts("                [/R:directory ...]");
}

int main(int argc, char **argv)
{
    char catalog_path[MVA_PATH_LEN] = "MAXVIEW.CFG";
    char database_path[MVA_PATH_LEN] = "MAXVAUTO.DAT";
    static char root_storage[MVA_MAX_ROOTS][MVA_PATH_LEN];
    const char *roots[MVA_MAX_ROOTS];
    unsigned root_count = 0, error_line = 0, index, added;
    int scan_only = 0, apply = 0, check = 0, result;
    static mva_rules rules;
    static odq_catalog catalog;
    static mva_scan scan;

    for (index = 1; index < (unsigned)argc; ++index) {
        if (stricmp(argv[index], "/SCAN") == 0)
            scan_only = 1;
        else if (stricmp(argv[index], "/APPLY") == 0)
            apply = 1;
        else if (stricmp(argv[index], "/CHECK") == 0)
            check = 1;
        else if (strnicmp(argv[index], "/F:", 3) == 0 && argv[index][3] &&
                 strlen(argv[index] + 3) < sizeof(catalog_path))
            strcpy(catalog_path, argv[index] + 3);
        else if (strnicmp(argv[index], "/D:", 3) == 0 && argv[index][3] &&
                 strlen(argv[index] + 3) < sizeof(database_path))
            strcpy(database_path, argv[index] + 3);
        else if (strnicmp(argv[index], "/R:", 3) == 0 && argv[index][3] &&
                 root_count < MVA_MAX_ROOTS &&
                 strlen(argv[index] + 3) < MVA_PATH_LEN) {
            strcpy(root_storage[root_count], argv[index] + 3);
            roots[root_count] = root_storage[root_count];
            ++root_count;
        }
        else {
            usage();
            return 2;
        }
    }
    if ((scan_only ? 1 : 0) + (apply ? 1 : 0) + (check ? 1 : 0) > 1) {
        usage();
        return 2;
    }
    result = mva_rules_load(database_path, &rules, &error_line);
    if (result != MVA_OK) {
        if (result == MVA_IO)
            printf("MAXVAUTO: cannot read %s\n", database_path);
        else
            printf("MAXVAUTO: database error on line %u\n", error_line);
        return result == MVA_IO ? 1 : 2;
    }
    if (check) {
        printf("MAXVAUTO: %u valid detection rule(s)\n", rules.count);
        return 0;
    }
    result = odq_catalog_load(catalog_path, &catalog, &error_line);
    if (result == ODQ_CATALOG_IO)
        catalog.count = 0;
    else if (result != ODQ_CATALOG_OK) {
        printf("MAXVAUTO: catalogue error on line %u\n", error_line);
        return 2;
    }
    scan.rules = &rules;
    scan.catalog = &catalog;
    run_scan(&scan, roots, root_count);
    if (scan_only) {
        printf("MAXVAUTO: %u new program(s) found\n", scan.count);
        for (index = 0; index < scan.count; ++index) {
            const mva_found *found = &scan.found[index];
            const mva_rule *rule = &rules.rules[found->rule_index];
            printf("%s|%s|%s\n", rule->filename, rule->title,
                   found->directory);
        }
        fflush(stdout);
        return 0;
    }
    if (apply) {
        result = apply_found(catalog_path, &catalog, &scan, &added);
        if (result != MVA_OK) {
            puts("MAXVAUTO: unable to save program catalogue");
            return 3;
        }
        printf("MAXVAUTO: added %u program(s)\n", added);
        fflush(stdout);
        return 0;
    }
    return interactive(catalog_path, &catalog, &scan);
}
