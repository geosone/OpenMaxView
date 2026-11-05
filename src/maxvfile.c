/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Open MaxView DOS Services:  a directory's files, marked by hand or by
 * name, sorted; Append, Copy, Erase, Move, Print, Rename, Type them; More:
 * Change, Make, Remove Directory, and DOS's own diskette programs (Copy,
 * Format Diskette, Backup, Restore). */
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
    unsigned char marked;
    unsigned long size;
    unsigned date, time;        /* DOS's, as written */
} mvf_entry;

static mvf_entry entries[MVF_MAX_ENTRIES];
static unsigned entry_count;
static unsigned sort_key;               /* 0 name, 1 extension, 2 size,
                                         * 3 date */
static const char *const sort_name[4] = {
    "name", "extension", "size", "date"
};
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

static const char *extension(const char *name)
{
    const char *dot = strchr(name, '.');
    return dot != NULL && name[0] != '.' ? dot + 1 : "";
}

/* directories first, then by the sort key, then by name */
static int entry_before(const mvf_entry *left, const mvf_entry *right)
{
    int left_dir = (left->attributes & _A_SUBDIR) != 0;
    int right_dir = (right->attributes & _A_SUBDIR) != 0;
    int order = 0;

    if (left_dir != right_dir)
        return left_dir;
    if (strcmp(left->name, "..") == 0 || strcmp(right->name, "..") == 0)
        return strcmp(left->name, "..") == 0;
    switch (sort_key) {
    case 1:
        order = stricmp(extension(left->name), extension(right->name));
        break;
    case 2:
        order = left->size < right->size ? -1 : left->size > right->size;
        break;
    case 3:
        order = left->date != right->date ?
                (left->date < right->date ? -1 : 1) :
                left->time != right->time ?
                (left->time < right->time ? -1 : 1) : 0;
        break;
    }
    return order != 0 ? order < 0 : stricmp(left->name, right->name) < 0;
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
            entry->marked = 0;
            entry->size = found.size;
            entry->date = found.wr_date;
            entry->time = found.wr_time;
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

/* DOS's wildcards:  * any characters, ? one; a name without a dot as
 * "NAME." and a pattern without one as "PATTERN.*" */
static int glob(const char *pattern, const char *name)
{
    for (; *pattern != '\0'; ++pattern, ++name) {
        if (*pattern == '*') {
            do
                if (glob(pattern + 1, name))
                    return 1;
            while (*name++ != '\0');
            return 0;
        }
        if (*name == '\0' ||
            (*pattern != '?' && toupper((unsigned char)*pattern) !=
                                toupper((unsigned char)*name)))
            return 0;
    }
    return *name == '\0';
}

static int name_matches(const char *pattern, const char *name)
{
    char p[MVF_PATH_LEN], n[14];

    if (strlen(pattern) + 3 > sizeof p)
        return 0;
    strcpy(p, pattern);
    if (strchr(p, '.') == NULL)
        strcat(p, ".*");
    strcpy(n, name);
    if (strchr(n, '.') == NULL)
        strcat(n, ".");
    return glob(p, n);
}

/* the view:  the entries shown (all, or only the marked ones) */
static unsigned view[MVF_MAX_ENTRIES], view_count;
static int only_marked;

static void make_view(void)
{
    unsigned i;

    view_count = 0;
    for (i = 0; i < entry_count; ++i)
        if (!only_marked || entries[i].marked)
            view[view_count++] = i;
}

static unsigned marked_count(void)
{
    unsigned i, n = 0;

    for (i = 0; i < entry_count; ++i)
        n += entries[i].marked;
    return n;
}

#define LIST_TOP   5
#define LIST_ROWS  16

/* the commands, two pages (More:  the second), as on the right */
static const char *const page_text[2][14] = {
    { "Append        A", "Copy      C F5", "Erase     E F8",
      "Move          M", "Print         P", "Rename    R F6",
      "Type          T", "", "Mark      Space", "Mark by Name  N",
      "Unmark by Name U", "Only Marked   O", "Sort          S",
      "More          *" },
    { "Change Dir    C", "Make Dir  M F7", "Remove Dir    R", "",
      "Copy Diskette K", "Format Disk.  F", "Backup        B",
      "Restore       S", "", "", "", "", "", "Back          *" }
};

static void draw_desktop(const char *directory, unsigned selected,
                         const char *status, int page)
{
    unsigned index, first, row;
    char line[40];

    mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, 219, MVUI_BACKGROUND);
    mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
    mvui_write(0, 1, "DOS Services", MVUI_MENU);
    mvui_put(0, 1, 'D', MVUI_MENU_TRIGGER);
    mvui_write(0, 60, "Open MaxView 0.8", MVUI_MENU_TRIGGER);
    mvui_fill(2, 1, 22, 59, ' ', MVUI_DATA);
    mvui_shadow(2, 1, 22, 59);
    mvui_fill(2, 62, 22, 78, ' ', MVUI_QUICK);
    mvui_shadow(2, 62, 22, 78);
    mvui_write(3, 3, "Directory:", MVUI_DATA_HIGH);
    write_clipped(3, 14, directory, 44, MVUI_DATA);
    sprintf(line, "%u files, %u marked, by %s%s", view_count, marked_count(),
            sort_name[sort_key], only_marked ? ", marked only" : "");
    mvui_write(4, 3, line, MVUI_DATA_HIGH);
    mvui_write(3, 64, page ? "More" : "Commands", MVUI_QUICK_HIGH);
    for (index = 0; index < 14; ++index)
        if (page_text[page][index][0] != '\0') {
            const char *t = page_text[page][index];

            mvui_write(5 + index, 63, t, MVUI_QUICK);
            mvui_put(5 + index, 63, (unsigned char)t[0], MVUI_QUICK_HIGH);
        }
    write_clipped(21, 63, status, 15, MVUI_QUICK);

    if (view_count == 0) {
        mvui_write(7, 5, only_marked ? "No file is marked." :
                   "This directory is empty.", MVUI_DATA);
    } else {
        first = selected >= LIST_ROWS ? selected - LIST_ROWS + 1 : 0;
        for (index = first; index < view_count && index < first + LIST_ROWS;
             ++index) {
            const mvf_entry *entry = &entries[view[index]];
            unsigned char attr = index == selected ? MVUI_ACTIVE : MVUI_DATA;
            row = LIST_TOP + 1 + index - first;
            mvui_fill(row, 2, row, 58, ' ', attr);
            if (entry->marked)
                mvui_put(row, 3, 16, attr);
            mvui_write(row, 5, entry->name, attr);
            if ((entry->attributes & _A_SUBDIR) != 0)
                mvui_write(row, 23, "<DIR>", attr);
            else
                write_size(row, 18, entry->size, attr);
            if (strcmp(entry->name, "..") != 0) {
                unsigned h = entry->time >> 11;

                sprintf(line, "%2u-%02u-%02u %2u:%02u%c",
                        (entry->date >> 5) & 15, entry->date & 31,
                        ((entry->date >> 9) + 80) % 100,
                        h % 12 == 0 ? 12 : h % 12, (entry->time >> 5) & 63,
                        h < 12 ? 'a' : 'p');
                mvui_write(row, 31, line, attr);
            }
        }
    }
    mvui_button(24, 1, 10, "Exit Esc");
    mvui_button(24, 13, 15, "Open Enter");
    mvui_button(24, 30, 16, "Parent Bksp");
    mvui_button(24, 48, 14, "Refresh F9");
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

/* source appended to the end of destination */
static int append_file(const char *source, const char *destination)
{
    FILE *input, *output;
    size_t count;
    int failed = 0;

    if (same_file(source, destination))
        return 0;
    input = fopen(source, "rb");
    if (input == NULL)
        return 0;
    output = fopen(destination, "ab");
    if (output == NULL) {
        fclose(input);
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
    return !failed;
}

/* source to the printer (PRN) */
static int print_file(const char *source)
{
    FILE *input, *output;
    size_t count;
    int failed = 0;

    input = fopen(source, "rb");
    if (input == NULL)
        return 0;
    output = fopen("PRN", "wb");
    if (output == NULL) {
        fclose(input);
        return 0;
    }
    while ((count = fread(copy_buffer, 1, sizeof(copy_buffer), input)) != 0)
        if (fwrite(copy_buffer, 1, count, output) != count) {
            failed = 1;
            break;
        }
    if (fputc('\f', output) == EOF || fclose(output) != 0)
        failed = 1;
    fclose(input);
    return !failed;
}

static int is_directory(const char *path)
{
    unsigned attributes;

    return _dos_getfileattr(path, &attributes) == 0 &&
           (attributes & _A_SUBDIR) != 0;
}

/* Type:  the file's text, a screen at a time (Up, Down, PgUp, PgDn, Home,
 * End; Esc back) */
static void type_file(const char *path, const char *name)
{
    FILE *input = fopen(path, "rb");
    long top = 0, lines = 0, line;
    unsigned row, col;
    int c, key;

    if (input == NULL)
        return;
    col = 0;                    /* (its lines:  78 columns each) */
    while ((c = getc(input)) != EOF)
        if (c == '\n' || ++col > 78) {
            ++lines;
            col = c == '\n' ? 0 : 1;
        }
    if (col != 0)
        ++lines;
    for (;;) {
        mvui_fill(0, 0, MVUI_ROWS - 1, MVUI_COLS - 1, ' ', MVUI_DATA);
        mvui_fill(0, 0, 0, 79, ' ', MVUI_MENU);
        mvui_write(0, 1, "Type", MVUI_MENU);
        mvui_write(0, 7, name, MVUI_MENU_TRIGGER);
        mvui_write(0, 30, "Arrows PgUp PgDn Home End;  Esc back",
                   MVUI_MENU);
        rewind(input);
        line = 0;
        row = 1;
        col = 0;
        while (row < MVUI_ROWS && (c = getc(input)) != EOF) {
            if (c == '\r')
                continue;
            if (c == '\n' || col >= 78) {
                if (line >= top)
                    ++row;
                ++line;
                col = 0;
                if (c == '\n')
                    continue;
            }
            if (line < top || row >= MVUI_ROWS)
                continue;
            if (c == '\t') {
                do
                    mvui_put(row, 1 + col++, ' ', MVUI_DATA);
                while (col % 8 != 0 && col < 78);
            } else
                mvui_put(row, 1 + col++, (unsigned char)(c < ' ' ? '.' : c),
                         MVUI_DATA);
        }
        key = getch();
        if (key == 27)
            break;
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && top > 0) --top;
            else if (key == 80 && top + 1 < lines) ++top;
            else if (key == 73) top = top > 24 ? top - 24 : 0;
            else if (key == 81 && top + 24 < lines) top += 24;
            else if (key == 71) top = 0;
            else if (key == 79) top = lines > 24 ? lines - 24 : 0;
        }
    }
    fclose(input);
}

/* a DOS program run with its parameters (the screen DOS's meanwhile) */
static void run_dos(const char *program, const char *parameters)
{
    char command[MVF_PATH_LEN + 16];

    sprintf(command, "%s %.120s", program, parameters);
    mvui_restore();
    printf("%s\n", command);
    if (system(command) != 0)
        printf("%s could not be run.\n", program);
    printf("Press a key.");
    if (getch() == 0)
        getch();
    mvui_init();
}

/* the files a command works on:  the marked ones, else the one selected
 * (files only) */
static unsigned next_target(unsigned from, unsigned selected)
{
    unsigned i;

    if (marked_count() == 0) {
        if (from == 0 && view_count != 0 &&
            (entries[view[selected]].attributes & _A_SUBDIR) == 0)
            return view[selected] + 1;
        return 0;
    }
    for (i = from; i < entry_count; ++i)
        if (entries[i].marked && (entries[i].attributes & _A_SUBDIR) == 0)
            return i + 1;
    return 0;
}

/* the directory again, its marks kept (by name) */
static void reload(const char *directory, unsigned *selected)
{
    static char kept[MVF_MAX_ENTRIES][13];
    unsigned i, j, n = 0;

    for (i = 0; i < entry_count; ++i)
        if (entries[i].marked)
            strcpy(kept[n++], entries[i].name);
    load_directory(directory);
    for (i = 0; i < entry_count; ++i)
        for (j = 0; j < n; ++j)
            if (strcmp(entries[i].name, kept[j]) == 0)
                entries[i].marked = 1;
    make_view();
    if (view_count == 0)
        *selected = 0;
    else if (*selected >= view_count)
        *selected = view_count - 1;
}

/* Copy, Move or Append (0, 1, 2) of the files to input:  a directory, or
 * for one file (Copy, Move) a file; Append:  a file */
static void transfer(int how, const char *directory, unsigned selected,
                     char *status)
{
    static const char *const title[3] = {
        "Copy", "Move", "Append"
    };
    char source[MVF_PATH_LEN * 2], target[MVF_PATH_LEN * 2];
    char input[MVF_PATH_LEN];
    unsigned i, done = 0, failed = 0;
    int to_dir;

    if (next_target(0, selected) == 0) {
        strcpy(status, "No file.");
        return;
    }
    input[0] = '\0';
    if (!input_path(title[how], how == 2 ? "Append to file:" :
                    "To directory or file:", input, sizeof input) ||
        !resolve_path(target, sizeof target, directory, input)) {
        strcpy(status, "Cancelled.");
        return;
    }
    to_dir = how != 2 && is_directory(target);
    if (!to_dir && how != 2 && marked_count() > 1) {
        strcpy(status, "Not a directory.");
        return;
    }
    for (i = next_target(0, selected); i != 0; i = next_target(i, selected)) {
        char dest[MVF_PATH_LEN * 2];
        const char *name = entries[i - 1].name;
        int ok;

        if (!join_path(source, sizeof source, directory, name)) {
            ++failed;
            continue;
        }
        strcpy(dest, target);
        if (to_dir && !join_path(dest, sizeof dest, target, name)) {
            ++failed;
            continue;
        }
        if (how == 2)
            ok = append_file(source, dest);
        else if (file_exists(dest) && !confirm_action("Overwrite", dest))
            ok = 0;
        else if (how == 1 && !file_exists(dest) && rename(source, dest) == 0)
            ok = 1;             /* (the same drive) */
        else {
            ok = copy_file(source, dest, 1);
            if (ok && how == 1)
                ok = remove(source) == 0;
        }
        if (ok) ++done; else ++failed;
    }
    sprintf(status, "%u done, %u not.", done, failed);
}

static int interactive(const char *start_directory)
{
    char directory[MVF_PATH_LEN], source[MVF_PATH_LEN * 2];
    char target[MVF_PATH_LEN * 2], input[MVF_PATH_LEN];
    char status[48];
    unsigned selected = 0, i;
    int key, page = 0;

    if (chdir(start_directory) != 0 ||
        getcwd(directory, sizeof(directory)) == NULL ||
        !load_directory(directory)) {
        printf("MAXVFILE: cannot open %s\n", start_directory);
        return 1;
    }
    make_view();
    strcpy(status, "Ready.");
    mvui_init();
    for (;;) {
        const mvf_entry *cur = view_count != 0 ? &entries[view[selected]] :
                               NULL;
        int ext = 0;

        draw_desktop(directory, selected, status, page);
        key = getch();
        if (key == 0 || key == 0xe0) {
            ext = getch();
            key = 0;
        } else
            key = toupper(key);
        if (ext == 72 && selected > 0) --selected;
        else if (ext == 80 && selected + 1 < view_count) ++selected;
        else if (ext == 73) selected = selected > LIST_ROWS ?
                                       selected - LIST_ROWS : 0;
        else if (ext == 81) selected = selected + LIST_ROWS < view_count ?
                                       selected + LIST_ROWS :
                                       view_count != 0 ? view_count - 1 : 0;
        else if (ext == 71) selected = 0;
        else if (ext == 79) selected = view_count != 0 ? view_count - 1 : 0;
        else if (ext == 67) {                                   /* F9 */
            reload(directory, &selected);
            strcpy(status, "Refreshed.");
        } else if (key == 27) {
            if (page) {
                page = 0;
                continue;
            }
            mvui_restore();
            return 0;
        } else if (key == '*')
            page = !page;
        else if ((key == 13 && cur != NULL &&
                  (cur->attributes & _A_SUBDIR) != 0) || key == 8) {
            const char *name = key == 8 ? ".." : cur->name;
            if (chdir(name) == 0 && getcwd(directory, sizeof(directory)) != NULL) {
                only_marked = 0;
                reload(directory, &selected);
                selected = 0;
                strcpy(status, "Directory opened.");
            } else
                strcpy(status, "Cannot open it.");
        } else if (key == 13 && cur != NULL)
            strcpy(status, "Open Window runs it.");
        else if (key == ' ' && cur != NULL && strcmp(cur->name, "..") != 0) {
            entries[view[selected]].marked ^= 1;
            if (selected + 1 < view_count)
                ++selected;
        } else if (ext == 63 || (page == 0 && (key == 'C' || key == 'M' ||
                                                key == 'A'))) {
            /* F5, C:  Copy; M:  Move; A:  Append */
            transfer(key == 'M' ? 1 : key == 'A' ? 2 : 0, directory,
                     selected, status);
            reload(directory, &selected);
        } else if (ext == 66 || ext == 83 || (page == 0 && key == 'E') ||
                 (page == 1 && key == 'R')) {   /* F8, Del:  Erase, RD */
            unsigned n = marked_count(), done = 0, failed = 0;

            if (n == 0 && (cur == NULL || strcmp(cur->name, "..") == 0)) {
                strcpy(status, "Nothing to erase.");
                continue;
            }
            if (n != 0)
                sprintf(input, "%u marked files", n);
            else
                strcpy(input, cur->name);
            if (!confirm_action("Erase", input)) {
                strcpy(status, "Cancelled.");
                continue;
            }
            for (i = 0; i < entry_count; ++i) {
                const mvf_entry *e = &entries[i];

                if (n != 0 ? !e->marked : e != cur)
                    continue;
                if (join_path(target, sizeof target, directory, e->name) &&
                    ((e->attributes & _A_SUBDIR) != 0 ? rmdir(target) :
                                                        remove(target)) == 0)
                    ++done;
                else
                    ++failed;
            }
            sprintf(status, "%u erased, %u not.", done, failed);
            reload(directory, &selected);
        } else if (page == 0 && key == 'P') {
            unsigned done = 0, failed = 0;

            for (i = next_target(0, selected); i != 0;
                 i = next_target(i, selected))
                if (join_path(source, sizeof source, directory,
                              entries[i - 1].name) && print_file(source))
                    ++done;
                else
                    ++failed;
            sprintf(status, "%u printed, %u not.", done, failed);
        } else if ((ext == 64 || (page == 0 && key == 'R')) && cur != NULL &&
                   strcmp(cur->name, "..") != 0) {             /* F6 */
            if (join_path(source, sizeof(source), directory, cur->name)) {
                strcpy(input, cur->name);
                if (input_path("Rename", "New name:", input,
                               sizeof(input)) &&
                    join_path(target, sizeof(target), directory, input) &&
                    !file_exists(target) && rename(source, target) == 0)
                    strcpy(status, "Renamed.");
                else
                    strcpy(status, "Not renamed.");
                reload(directory, &selected);
            }
        } else if (page == 0 && key == 'T' && cur != NULL &&
                   (cur->attributes & _A_SUBDIR) == 0) {
            if (join_path(source, sizeof source, directory, cur->name))
                type_file(source, cur->name);
        } else if (page == 0 && (key == 'N' || key == 'U')) {
            unsigned n = 0;

            input[0] = '\0';
            if (input_path(key == 'N' ? "Mark by Name" : "Unmark by Name",
                           "Names (* and ? as in DOS):", input,
                           sizeof input)) {
                for (i = 0; i < entry_count; ++i)
                    if ((entries[i].attributes & _A_SUBDIR) == 0 &&
                        name_matches(input, entries[i].name)) {
                        entries[i].marked = (unsigned char)(key == 'N');
                        ++n;
                    }
                make_view();
                if (selected >= view_count)
                    selected = view_count != 0 ? view_count - 1 : 0;
                sprintf(status, "%u %smarked.", n, key == 'N' ? "" : "un");
            }
        } else if (page == 0 && key == 'O') {
            only_marked = !only_marked;
            make_view();
            selected = 0;
        } else if (page == 0 && key == 'S') {
            sort_key = (sort_key + 1) % 4;
            sort_entries();
            make_view();
            selected = 0;
            sprintf(status, "By %s.", sort_name[sort_key]);
        } else if (page == 1 && key == 'C') {
            strcpy(input, directory);
            if (input_path("Change Directory", "Directory (a drive too):",
                           input, sizeof input)) {
                if (input[1] == ':')
                    _chdrive(toupper((unsigned char)input[0]) - 'A' + 1);
                if ((input[1] != ':' || input[2] != '\0' ? chdir(input) : 0)
                    == 0 && getcwd(directory, sizeof directory) != NULL) {
                    only_marked = 0;
                    reload(directory, &selected);
                    selected = 0;
                    strcpy(status, "Directory changed.");
                } else
                    strcpy(status, "No such directory.");
            }
        } else if (ext == 65 || (page == 1 && key == 'M')) {   /* F7 */
            input[0] = '\0';
            if (input_path("Make Directory", "Directory name:", input,
                           sizeof(input)) &&
                resolve_path(target, sizeof(target), directory, input) &&
                mkdir(target) == 0)
                strcpy(status, "Directory made.");
            else
                strcpy(status, "Not made.");
            reload(directory, &selected);
        } else if (page == 1 && (key == 'K' || key == 'F' || key == 'B' ||
                                 key == 'S')) {
            static const char *const program[4] = {
                "DISKCOPY", "FORMAT", "BACKUP", "RESTORE"
            };
            static const char *const prompt[4] = {
                "DISKCOPY from and to (A: A:):", "FORMAT the diskette (A:):",
                "BACKUP files and diskette (C:\\*.* A: /S):",
                "RESTORE from diskette, to files (A: C:\\*.* /S):"
            };
            unsigned k = key == 'K' ? 0 : key == 'F' ? 1 : key == 'B' ? 2 : 3;

            input[0] = '\0';
            if (input_path(program[k], prompt[k], input, sizeof input))
                run_dos(program[k], input);
            reload(directory, &selected);
            strcpy(status, "Back from DOS.");
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
