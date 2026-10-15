/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Open MaxView DOS Services-style file manager. */
#include <conio.h>
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mvui.h"

#define MVF_PATH_LEN    128
#define MVF_MAX_ENTRIES 192

typedef struct mvf_entry {
    char name[13];
    unsigned char attributes;
    unsigned long size;
} mvf_entry;

static mvf_entry entries[MVF_MAX_ENTRIES];
static unsigned entry_count;
static unsigned char copy_buffer[8192];

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

static int entry_before(const mvf_entry *left, const mvf_entry *right)
{
    int left_dir = (left->attributes & _A_SUBDIR) != 0;
    int right_dir = (right->attributes & _A_SUBDIR) != 0;
    if (left_dir != right_dir)
        return left_dir;
    return stricmp(left->name, right->name) < 0;
}

static void sort_entries(void)
{
    unsigned outer, inner, best;
    mvf_entry temporary;

    for (outer = 0; outer + 1 < entry_count; ++outer) {
        best = outer;
        for (inner = outer + 1; inner < entry_count; ++inner)
            if (entry_before(&entries[inner], &entries[best]))
                best = inner;
        if (best != outer) {
            temporary = entries[outer];
            entries[outer] = entries[best];
            entries[best] = temporary;
        }
    }
}

static int load_directory(const char *directory)
{
    struct find_t found;
    char pattern[MVF_PATH_LEN * 2];
    unsigned result, attributes;

    entry_count = 0;
    if (_dos_getfileattr(directory, &attributes) != 0 ||
        (attributes & _A_SUBDIR) == 0)
        return 0;
    if (!join_path(pattern, sizeof(pattern), directory, "*.*"))
        return 0;
    result = _dos_findfirst(pattern, _A_RDONLY | _A_HIDDEN | _A_SYSTEM |
                            _A_SUBDIR | _A_ARCH, &found);
    if (result != 0)
        return 1;
    do {
        if (strcmp(found.name, ".") != 0 && entry_count < MVF_MAX_ENTRIES) {
            mvf_entry *entry = &entries[entry_count++];
            strcpy(entry->name, found.name);
            entry->attributes = (unsigned char)found.attrib;
            entry->size = found.size;
        }
        result = _dos_findnext(&found);
    } while (result == 0);
    _dos_findclose(&found);
    sort_entries();
    return 1;
}

static int file_exists(const char *path)
{
    return access(path, 0) == 0;
}

static int same_file(const char *left, const char *right)
{
    char left_full[MVF_PATH_LEN * 2], right_full[MVF_PATH_LEN * 2];
    if (_fullpath(left_full, left, sizeof(left_full)) == NULL ||
        _fullpath(right_full, right, sizeof(right_full)) == NULL)
        return stricmp(left, right) == 0;
    return stricmp(left_full, right_full) == 0;
}

static int backup_path(char *backup, unsigned capacity, const char *path)
{
    const char *slash = strrchr(path, '\\');
    const char *forward = strrchr(path, '/');
    const char *dot = strrchr(path, '.');
    size_t stem_length;

    if (forward != NULL && (slash == NULL || forward > slash))
        slash = forward;
    if (dot == NULL || (slash != NULL && dot < slash))
        dot = path + strlen(path);
    stem_length = (size_t)(dot - path);
    if (stem_length + 5 > capacity)
        return 0;
    memcpy(backup, path, stem_length);
    strcpy(backup + stem_length, ".$MV");
    return 1;
}

static int copy_file(const char *source, const char *destination,
                     int overwrite)
{
    FILE *input, *output;
    size_t count;
    int failed = 0, had_destination;
    char backup[MVF_PATH_LEN * 2];

    if (same_file(source, destination))
        return 0;
    had_destination = file_exists(destination);
    if (had_destination && !overwrite)
        return 0;
    input = fopen(source, "rb");
    if (input == NULL)
        return 0;
    if (had_destination) {
        if (!backup_path(backup, sizeof(backup), destination) ||
            file_exists(backup) || rename(destination, backup) != 0) {
            fclose(input);
            return 0;
        }
    }
    output = fopen(destination, "wb");
    if (output == NULL) {
        fclose(input);
        if (had_destination)
            rename(backup, destination);
        return 0;
    }
    while ((count = fread(copy_buffer, 1, sizeof(copy_buffer), input)) != 0)
        if (fwrite(copy_buffer, 1, count, output) != count) {
            failed = 1;
            break;
        }
    if (ferror(input) || fclose(output) != 0)
        failed = 1;
    fclose(input);
    if (failed) {
        remove(destination);
        if (had_destination)
            rename(backup, destination);
    } else if (had_destination) {
        remove(backup);
    }
    return !failed;
}

static void write_size(unsigned row, unsigned col, unsigned long size,
                       unsigned char attr)
{
    char text[12];
    sprintf(text, "%10lu", size);
    mvui_write(row, col, text, attr);
}

static void write_clipped(unsigned row, unsigned col, const char *text,
                          unsigned width, unsigned char attr)
{
    unsigned count = 0;
    while (*text != '\0' && count < width) {
        mvui_put(row, col + count, (unsigned char)*text++, attr);
        ++count;
    }
}

static int resolve_path(char *target, unsigned capacity, const char *directory,
                        const char *value)
{
    if (value[0] == '\\' || value[0] == '/' ||
        (value[0] != '\0' && value[1] == ':')) {
        if (strlen(value) + 1 > capacity)
            return 0;
        strcpy(target, value);
        return 1;
    }
    return join_path(target, capacity, directory, value);
}

static void draw_desktop(const char *directory, unsigned selected,
                         const char *status)
{
    unsigned index, first, row;

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "Files", MVUI_MENU);
    mvui_put(0, 1, 'F', MVUI_MENU_TRIGGER);
    mvui_write(0, 60, "Open MaxView 0.8", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 21, 58, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 21, 58);
    mvui_fill(2, 62, 21, 77, ' ', MVUI_QUICK);
    mvui_shadow(2, 62, 21, 77);
    mvui_write(3, 4, "Directory:", MVUI_DATA_HIGH);
    write_clipped(3, 15, directory, 40, MVUI_DATA);
    mvui_write(4, 4, "Name", MVUI_DATA_HIGH);
    mvui_write(4, 42, "Size", MVUI_DATA_HIGH);
    mvui_write(4, 64, "Quick Help", MVUI_QUICK_HIGH);
    mvui_write(6, 64, "Enter Open", MVUI_QUICK);
    mvui_write(7, 64, "Back Parent", MVUI_QUICK);
    mvui_write(8, 64, "F5 Copy", MVUI_QUICK);
    mvui_write(9, 64, "F6 Rename", MVUI_QUICK);
    mvui_write(10, 64, "F7 Make dir", MVUI_QUICK);
    mvui_write(11, 64, "F8 Delete", MVUI_QUICK);
    mvui_write(12, 64, "Esc Exit", MVUI_QUICK);
    mvui_write(15, 64, "Status:", MVUI_QUICK_HIGH);
    write_clipped(16, 64, status, 13, MVUI_QUICK);

    if (entry_count == 0) {
        mvui_write(7, 5, "This directory is empty.", MVUI_DATA);
    } else {
        first = selected >= 14 ? selected - 13 : 0;
        for (index = first; index < entry_count && index < first + 14;
             ++index) {
            const mvf_entry *entry = &entries[index];
            unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
            row = 5 + index - first;
            mvui_fill(row, 3, row, 56, ' ', attr);
            if ((entry->attributes & _A_SUBDIR) != 0)
                mvui_write(row, 4, "<DIR>", attr);
            mvui_write(row, 11, entry->name, attr);
            if ((entry->attributes & _A_SUBDIR) == 0)
                write_size(row, 40, entry->size, attr);
        }
    }
    mvui_button(24, 1, 10, "Exit Esc");
    mvui_button(24, 13, 10, "Copy F5");
    mvui_button(24, 25, 12, "Rename F6");
    mvui_button(24, 39, 12, "Mkdir F7");
    mvui_button(24, 53, 12, "Delete F8");
}

static int input_path(const char *title, const char *prompt, char *value,
                      unsigned capacity)
{
    char original[MVF_PATH_LEN];
    unsigned length, first;
    int key;

    strcpy(original, value);
    length = strlen(value);
    mvui_frame(7, 7, 15, 72, title);
    mvui_write(10, 11, prompt, MVUI_ACTIVE);
    mvui_write(13, 11, "Enter accepts; Esc cancels.", MVUI_ACTIVE);
    for (;;) {
        first = length > 47 ? length - 47 : 0;
        mvui_fill(11, 11, 11, 61, ' ', MVUI_QUICK);
        mvui_write(11, 12, value + first, MVUI_QUICK_HIGH);
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
            return length != 0;
        if (key == 8 && length != 0)
            value[--length] = '\0';
        else if (isprint((unsigned char)key) && length + 1 < capacity) {
            value[length++] = (char)key;
            value[length] = '\0';
        }
    }
}

static int confirm_action(const char *verb, const char *name)
{
    int key;
    mvui_frame(8, 13, 15, 66, verb);
    mvui_write(10, 17, verb, MVUI_ACTIVE);
    mvui_write(10, 29, name, MVUI_ACTIVE);
    mvui_write(12, 17, "Press Y to confirm or N to cancel.", MVUI_ACTIVE);
    do {
        key = toupper(getch());
    } while (key != 'Y' && key != 'N' && key != 27);
    return key == 'Y';
}

static void select_after_reload(unsigned *selected)
{
    if (entry_count == 0)
        *selected = 0;
    else if (*selected >= entry_count)
        *selected = entry_count - 1;
}

static int interactive(const char *start_directory)
{
    char directory[MVF_PATH_LEN], source[MVF_PATH_LEN * 2];
    char target[MVF_PATH_LEN * 2], input[MVF_PATH_LEN];
    char status[48];
    unsigned selected = 0;
    int key;

    if (chdir(start_directory) != 0 ||
        getcwd(directory, sizeof(directory)) == NULL ||
        !load_directory(directory)) {
        printf("MAXVFILE: cannot open %s\n", start_directory);
        return 1;
    }
    strcpy(status, "Ready.");
    mvui_init();
    for (;;) {
        draw_desktop(directory, selected, status);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && selected > 0) --selected;
            else if (key == 80 && selected + 1 < entry_count) ++selected;
            else if (key == 63 && entry_count != 0 &&
                     (entries[selected].attributes & _A_SUBDIR) == 0) {
                if (join_path(source, sizeof(source), directory,
                              entries[selected].name)) {
                    input[0] = '\0';
                    if (input_path("Copy File", "Destination:", input,
                                   sizeof(input)) &&
                        resolve_path(target, sizeof(target), directory, input)) {
                        int overwrite = !file_exists(target) ||
                            confirm_action("Overwrite", input);
                        strcpy(status, overwrite &&
                               copy_file(source, target, 1) ?
                               "File copied." : "Copy cancelled or failed.");
                        load_directory(directory);
                        select_after_reload(&selected);
                    }
                }
            } else if (key == 64 && entry_count != 0 &&
                       strcmp(entries[selected].name, "..") != 0) {
                if (join_path(source, sizeof(source), directory,
                              entries[selected].name)) {
                    strcpy(input, entries[selected].name);
                    if (input_path("Rename", "New name:", input,
                                   sizeof(input)) &&
                        join_path(target, sizeof(target), directory, input) &&
                        !file_exists(target) && rename(source, target) == 0)
                        strcpy(status, "Entry renamed.");
                    else
                        strcpy(status, "Rename cancelled or failed.");
                    load_directory(directory);
                    select_after_reload(&selected);
                }
            } else if (key == 65) {
                input[0] = '\0';
                if (input_path("Create Directory", "Directory name:", input,
                               sizeof(input)) &&
                    join_path(target, sizeof(target), directory, input) &&
                    mkdir(target) == 0)
                    strcpy(status, "Directory created.");
                else
                    strcpy(status, "Create cancelled or failed.");
                load_directory(directory);
                select_after_reload(&selected);
            } else if (key == 66 && entry_count != 0 &&
                       strcmp(entries[selected].name, "..") != 0 &&
                       confirm_action("Delete", entries[selected].name)) {
                if (join_path(target, sizeof(target), directory,
                              entries[selected].name) &&
                    (((entries[selected].attributes & _A_SUBDIR) != 0 &&
                      rmdir(target) == 0) ||
                     ((entries[selected].attributes & _A_SUBDIR) == 0 &&
                      remove(target) == 0)))
                    strcpy(status, "Entry deleted.");
                else
                    strcpy(status, "Unable to delete entry.");
                load_directory(directory);
                select_after_reload(&selected);
            }
            continue;
        }
        if (key == 27) {
            mvui_restore();
            return 0;
        }
        if ((key == 13 && entry_count != 0 &&
             (entries[selected].attributes & _A_SUBDIR) != 0) || key == 8) {
            const char *name = key == 8 ? ".." : entries[selected].name;
            if (chdir(name) == 0 && getcwd(directory, sizeof(directory)) != NULL) {
                load_directory(directory);
                selected = 0;
                strcpy(status, "Directory opened.");
            } else {
                strcpy(status, "Unable to open directory.");
            }
        } else if (key == 13 && entry_count != 0) {
            strcpy(status, "Use MaxView to run this file.");
        } else if (toupper(key) == 'R') {
            load_directory(directory);
            select_after_reload(&selected);
            strcpy(status, "Directory refreshed.");
        }
    }
}

static int list_directory(const char *path)
{
    unsigned index;
    if (!load_directory(path)) {
        printf("MAXVFILE: cannot open %s\n", path);
        return 1;
    }
    printf("MAXVFILE: %u entries in %s\n", entry_count, path);
    for (index = 0; index < entry_count; ++index)
        printf("%c|%s|%lu\n",
               (entries[index].attributes & _A_SUBDIR) != 0 ? 'D' : 'F',
               entries[index].name, entries[index].size);
    return 0;
}

static void usage(void)
{
    puts("Usage: MAXVFILE [/P:directory]");
    puts("       MAXVFILE /LIST [/P:directory]");
    puts("       MAXVFILE /COPY source destination [/Y]");
    puts("       MAXVFILE /DELETE file /Y");
}

int main(int argc, char **argv)
{
    char directory[MVF_PATH_LEN] = ".";
    char source[MVF_PATH_LEN * 2], destination[MVF_PATH_LEN * 2];
    int list = 0, copy = 0, delete_file = 0, overwrite = 0;
    int index;

    source[0] = destination[0] = '\0';
    for (index = 1; index < argc; ++index) {
        if (stricmp(argv[index], "/LIST") == 0)
            list = 1;
        else if (stricmp(argv[index], "/COPY") == 0 && index + 2 < argc) {
            copy = 1;
            if (strlen(argv[index + 1]) >= sizeof(source) ||
                strlen(argv[index + 2]) >= sizeof(destination)) {
                usage();
                return 2;
            }
            strcpy(source, argv[++index]);
            strcpy(destination, argv[++index]);
        } else if (stricmp(argv[index], "/DELETE") == 0 && index + 1 < argc) {
            delete_file = 1;
            if (strlen(argv[index + 1]) >= sizeof(source)) {
                usage();
                return 2;
            }
            strcpy(source, argv[++index]);
        } else if (stricmp(argv[index], "/Y") == 0)
            overwrite = 1;
        else if (strnicmp(argv[index], "/P:", 3) == 0 && argv[index][3] &&
                 strlen(argv[index] + 3) < sizeof(directory))
            strcpy(directory, argv[index] + 3);
        else {
            usage();
            return 2;
        }
    }
    if ((list ? 1 : 0) + (copy ? 1 : 0) + (delete_file ? 1 : 0) > 1) {
        usage();
        return 2;
    }
    if (copy) {
        if (!copy_file(source, destination, overwrite)) {
            puts("MAXVFILE: copy failed");
            return 1;
        }
        puts("MAXVFILE: file copied");
        return 0;
    }
    if (delete_file) {
        if (!overwrite) {
            puts("MAXVFILE: /DELETE requires /Y");
            return 2;
        }
        if (remove(source) != 0) {
            puts("MAXVFILE: delete failed");
            return 1;
        }
        puts("MAXVFILE: file deleted");
        return 0;
    }
    if (list)
        return list_directory(directory);
    return interactive(directory);
}
