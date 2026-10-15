/* SPDX-License-Identifier: GPL-3.0-or-later */
/*
 * Open MaxView DOS installer.
 *
 * The installation flow and screen vocabulary are derived from the
 * GPL-licensed Open 386MAX INSTALL and QUILIB sources.  This smaller
 * implementation contains only the operations Open MaxView needs.
 */
#include <conio.h>
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <io.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SCREEN_COLS 80
#define SCREEN_ROWS 25
#define PATH_SIZE   128

#define ATTR_BACKGROUND   0x08
#define ATTR_DATA         0x1f
#define ATTR_DATA_HIGH    0x1e
#define ATTR_QUICK        0x70
#define ATTR_QUICK_HIGH   0x71
#define ATTR_MENU         0x70
#define ATTR_MENU_TRIGGER 0x74
#define ATTR_ACTIVE       0x3f
#define ATTR_SHADOW       0x08

typedef struct install_file {
    const char *source;
    const char *destination;
    int required;
    int preserve;
} install_file;

static const install_file files[] = {
    { "MAXVIEW.EXE", "MAXVIEW.EXE", 1, 0 },
    { "MAXVTSR.COM", "MAXVTSR.COM", 1, 0 },
    { "MAXVAPP.EXE", "MAXVAPP.EXE", 1, 0 },
    { "MAXVMEM.EXE", "MAXVMEM.EXE", 1, 0 },
    { "MAXVSET.EXE", "MAXVSET.EXE", 1, 0 },
    { "MAXVAUTO.EXE", "MAXVAUTO.EXE", 1, 0 },
    { "MAXVFILE.EXE", "MAXVFILE.EXE", 1, 0 },
    { "MAXVANSI.COM", "MAXVANSI.COM", 1, 0 },
    { "MAXVDVP.EXE", "MAXVDVP.EXE", 1, 0 },
    { "MAXVIEW.CFG", "MAXVIEW.CFG", 1, 1 },
    { "MAXVSET.INI", "MAXVSET.INI", 1, 1 },
    { "MAXVAUTO.DAT", "MAXVAUTO.DAT", 1, 1 },
    { "DVPROBE.EXE", "DVPROBE.EXE", 0, 0 },
    { "README.TXT",  "README.TXT",  0, 0 },
    { "LICENSE.TXT", "LICENSE.TXT", 0, 0 },
    { "DOCS.TXT",    "DOCS.TXT",    1, 0 },
    { "USERGUID.TXT", "USERGUID.TXT", 1, 0 },
    { "TOOLS.TXT",   "TOOLS.TXT",   1, 0 },
    { "CONFIG.TXT",  "CONFIG.TXT",  1, 0 },
    { "BUILDING.TXT", "BUILDING.TXT", 1, 0 },
    { "TESTING.TXT", "TESTING.TXT", 1, 0 },
    { "API.TXT",     "API.TXT",     1, 0 },
    { "COMPAT.TXT",  "COMPAT.TXT",  1, 0 },
    { "DEVELOP.TXT", "DEVELOP.TXT", 1, 0 },
    { "ROADMAP.TXT", "ROADMAP.TXT", 1, 0 },
    { "REMOTE2.TXT", "REMOTE2.TXT", 1, 0 },
    { "TROUBLE.TXT", "TROUBLE.TXT", 1, 0 },
    { "ARCHITEC.TXT", "ARCHITEC.TXT", 1, 0 },
    { "HELP.TXT",    "HELP.TXT",    1, 0 },
    { "BBSGUIDE.TXT", "BBSGUIDE.TXT", 1, 0 },
    { "PROGDEV.TXT", "PROGDEV.TXT", 1, 0 },
    { "QUICK.TXT",   "QUICK.TXT",   1, 0 }
};

static unsigned short far *video = (unsigned short far *)0xb8000000UL;
static unsigned char copy_buffer[8192];
static char source_directory[PATH_SIZE];

static void put_cell(unsigned row, unsigned col, unsigned char ch,
                     unsigned char attr)
{
    video[row * SCREEN_COLS + col] = (unsigned short)(ch | (attr << 8));
}

static void fill(unsigned top, unsigned left, unsigned bottom, unsigned right,
                 unsigned char ch, unsigned char attr)
{
    unsigned row, col;
    for (row = top; row <= bottom; ++row)
        for (col = left; col <= right; ++col)
            put_cell(row, col, ch, attr);
}

static void write_at(unsigned row, unsigned col, const char *text,
                     unsigned char attr)
{
    while (*text != '\0' && col < SCREEN_COLS)
        put_cell(row, col++, (unsigned char)*text++, attr);
}

static void shadow(unsigned top, unsigned left, unsigned bottom,
                   unsigned right)
{
    unsigned position;
    if (right + 1 < SCREEN_COLS) {
        for (position = top + 1;
             position <= bottom + 1 && position < SCREEN_ROWS; ++position)
            put_cell(position, right + 1,
                     (unsigned char)(video[position * SCREEN_COLS + right + 1]
                                     & 0xff), ATTR_SHADOW);
    }
    if (bottom + 1 < SCREEN_ROWS) {
        for (position = left + 2;
             position <= right + 1 && position < SCREEN_COLS; ++position)
            put_cell(bottom + 1, position,
                     (unsigned char)(video[(bottom + 1) * SCREEN_COLS + position]
                                     & 0xff), ATTR_SHADOW);
    }
}

static void frame(unsigned top, unsigned left, unsigned bottom, unsigned right,
                  const char *title)
{
    unsigned position;
    fill(top, left, bottom, right, ' ', ATTR_ACTIVE);
    put_cell(top, left, 201, ATTR_ACTIVE);
    put_cell(top, right, 187, ATTR_ACTIVE);
    put_cell(bottom, left, 200, ATTR_ACTIVE);
    put_cell(bottom, right, 188, ATTR_ACTIVE);
    for (position = left + 1; position < right; ++position) {
        put_cell(top, position, 205, ATTR_ACTIVE);
        put_cell(bottom, position, 205, ATTR_ACTIVE);
    }
    for (position = top + 1; position < bottom; ++position) {
        put_cell(position, left, 186, ATTR_ACTIVE);
        put_cell(position, right, 186, ATTR_ACTIVE);
    }
    write_at(top, left + 2, " ", ATTR_ACTIVE);
    write_at(top, left + 3, title, ATTR_ACTIVE);
    write_at(top, left + 3 + strlen(title), " ", ATTR_ACTIVE);
    shadow(top, left, bottom, right);
}

static void initialise_video(void)
{
    union REGS inregs, outregs;
    inregs.h.ah = 0x0f;
    int86(0x10, &inregs, &outregs);
    video = (unsigned short far *)
        ((outregs.h.al == 7) ? 0xb0000000UL : 0xb8000000UL);
    inregs.h.ah = 0x01;
    inregs.x.cx = 0x2000;
    int86(0x10, &inregs, &outregs);
}

static void restore_screen(void)
{
    union REGS inregs, outregs;
    inregs.h.ah = 0x00;
    inregs.h.al = 0x03;
    int86(0x10, &inregs, &outregs);
}

static void draw_setup(const char *destination)
{
    fill(0, 0, SCREEN_ROWS - 1, SCREEN_COLS - 1, 219, ATTR_BACKGROUND);
    fill(0, 0, 0, 79, ' ', ATTR_MENU);
    write_at(0, 1, "Install", ATTR_MENU);
    put_cell(0, 1, 'I', ATTR_MENU_TRIGGER);
    write_at(0, 61, "Open MaxView Setup", ATTR_MENU_TRIGGER);

    fill(2, 2, 21, 54, ' ', ATTR_DATA);
    shadow(2, 2, 21, 54);
    fill(2, 58, 21, 76, ' ', ATTR_QUICK);
    shadow(2, 58, 21, 76);

    write_at(4, 18, "Open MaxView", ATTR_DATA_HIGH);
    write_at(6, 6, "Free DOS multitasking environment", ATTR_DATA);
    write_at(8, 6, "GPL-3.0-or-later", ATTR_DATA);
    write_at(11, 6, "Installation directory:", ATTR_DATA_HIGH);
    fill(13, 6, 13, 49, ' ', ATTR_ACTIVE);
    write_at(13, 7, destination, ATTR_ACTIVE);

    write_at(4, 62, "Quick Help", ATTR_QUICK_HIGH);
    write_at(7, 60, "Type a directory", ATTR_QUICK);
    write_at(8, 60, "and press Enter.", ATTR_QUICK);
    write_at(11, 60, "Esc cancels the", ATTR_QUICK);
    write_at(12, 60, "installation.", ATTR_QUICK);
    write_at(24, 2, " Enter Install ", ATTR_QUICK_HIGH);
    write_at(24, 20, " Esc Abort ", ATTR_QUICK_HIGH);
}

static int edit_destination(char *destination)
{
    unsigned length = strlen(destination);
    int key;

    for (;;) {
        draw_setup(destination);
        key = getch();
        if (key == 0 || key == 0xe0) {
            getch();
            continue;
        }
        if (key == 27)
            return 0;
        if (key == 13)
            return length != 0;
        if (key == 8 && length != 0) {
            destination[--length] = '\0';
        } else if (isprint((unsigned char)key) && length + 1 < PATH_SIZE) {
            destination[length++] = (char)key;
            destination[length] = '\0';
        }
    }
}

static void join_path(char *result, const char *directory, const char *name)
{
    size_t length;
    strcpy(result, directory);
    length = strlen(result);
    if (length != 0 && result[length - 1] != '\\' && result[length - 1] != '/')
        strcat(result, "\\");
    strcat(result, name);
}

static int file_exists(const char *path)
{
    return access(path, 0) == 0;
}

static int same_file_name(const char *left, const char *right)
{
    char left_full[PATH_SIZE * 2], right_full[PATH_SIZE * 2];

    if (_fullpath(left_full, left, sizeof(left_full)) == NULL ||
        _fullpath(right_full, right, sizeof(right_full)) == NULL)
        return stricmp(left, right) == 0;
    return stricmp(left_full, right_full) == 0;
}

static int make_directories(const char *path)
{
    char work[PATH_SIZE];
    unsigned index, start;
    char saved;

    if (strlen(path) >= sizeof(work))
        return 0;
    strcpy(work, path);
    for (index = 0; work[index] != '\0'; ++index)
        if (work[index] == '/')
            work[index] = '\\';
    while (index > 3 && work[index - 1] == '\\')
        work[--index] = '\0';
    start = (index >= 2 && work[1] == ':') ? 3 : 1;
    for (index = start; ; ++index) {
        if (work[index] == '\\' || work[index] == '\0') {
            saved = work[index];
            work[index] = '\0';
            if (!file_exists(work) && mkdir(work) != 0)
                return 0;
            work[index] = saved;
            if (saved == '\0')
                break;
        }
    }
    return 1;
}

static int copy_file(const char *source, const char *destination)
{
    FILE *input, *output;
    size_t count;
    int failed = 0;

    if (same_file_name(source, destination))
        return 1;
    input = fopen(source, "rb");
    if (input == NULL)
        return 0;
    output = fopen(destination, "wb");
    if (output == NULL) {
        fclose(input);
        return 0;
    }
    while ((count = fread(copy_buffer, 1, sizeof(copy_buffer), input)) != 0)
        if (fwrite(copy_buffer, 1, count, output) != count) {
            failed = 1;
            break;
        }
    if (ferror(input))
        failed = 1;
    if (fclose(output) != 0)
        failed = 1;
    fclose(input);
    if (failed)
        remove(destination);
    return !failed;
}

static int verify_source(char *missing)
{
    unsigned index;
    char source[PATH_SIZE * 2];
    for (index = 0; index < sizeof(files) / sizeof(files[0]); ++index) {
        if (!files[index].required)
            continue;
        join_path(source, source_directory, files[index].source);
        if (!file_exists(source)) {
            strcpy(missing, files[index].source);
            return 0;
        }
    }
    return 1;
}

static int install(const char *destination, char *failed_name, int quiet)
{
    unsigned index;
    char source[PATH_SIZE * 2], target[PATH_SIZE * 2], status[70];
    FILE *log;

    if (!make_directories(destination)) {
        strcpy(failed_name, destination);
        return 0;
    }
    for (index = 0; index < sizeof(files) / sizeof(files[0]); ++index) {
        join_path(source, source_directory, files[index].source);
        join_path(target, destination, files[index].destination);
        if (!file_exists(source)) {
            if (files[index].required) {
                strcpy(failed_name, files[index].source);
                return 0;
            }
            continue;
        }
        if (files[index].preserve && file_exists(target))
            continue;
        if (!quiet) {
            sprintf(status, "Copying %-20s", files[index].destination);
            fill(17, 6, 17, 49, ' ', ATTR_DATA);
            write_at(17, 6, status, ATTR_DATA_HIGH);
        }
        if (!copy_file(source, target)) {
            strcpy(failed_name, files[index].destination);
            return 0;
        }
    }
    join_path(target, destination, "MAXVIEW.LOG");
    log = fopen(target, "wt");
    if (log != NULL) {
        fprintf(log, "Open MaxView installation\nDirectory=%s\n", destination);
        fprintf(log, "MAXVIEW.CFG, MAXVSET.INI and MAXVAUTO.DAT are preserved during upgrades.\n");
        fclose(log);
    }
    return 1;
}

static void find_source_directory(const char *program)
{
    const char *separator = NULL, *scan;
    size_t length;

    for (scan = program; *scan != '\0'; ++scan)
        if (*scan == '\\' || *scan == '/' || *scan == ':')
            separator = scan;
    if (separator == NULL) {
        strcpy(source_directory, ".");
        return;
    }
    length = (size_t)(separator - program);
    if (*separator == ':')
        ++length;
    if (length >= sizeof(source_directory))
        length = sizeof(source_directory) - 1;
    memcpy(source_directory, program, length);
    source_directory[length] = '\0';
}

static int parse_arguments(int argc, char **argv, char *destination, int *quiet)
{
    int index;
    const char *value;
    for (index = 1; index < argc; ++index) {
        if (stricmp(argv[index], "/S") == 0 ||
            stricmp(argv[index], "-S") == 0) {
            *quiet = 1;
        } else if (strnicmp(argv[index], "/D:", 3) == 0 ||
                   strnicmp(argv[index], "/D=", 3) == 0) {
            value = argv[index] + 3;
            if (*value == '\0' || strlen(value) >= PATH_SIZE)
                return 0;
            strcpy(destination, value);
        } else {
            return 0;
        }
    }
    return 1;
}

int main(int argc, char **argv)
{
    char destination[PATH_SIZE] = "C:\\MAXVIEW";
    char failed_name[PATH_SIZE * 2];
    int quiet = 0;

    find_source_directory(argv[0]);
    if (!parse_arguments(argc, argv, destination, &quiet)) {
        puts("Usage: SETUP [/S] [/D:directory]");
        return 2;
    }
    if (!verify_source(failed_name)) {
        printf("Open MaxView Setup: missing source file %s\n", failed_name);
        return 3;
    }
    if (!quiet) {
        initialise_video();
        if (!edit_destination(destination)) {
            restore_screen();
            puts("Open MaxView Setup cancelled.");
            return 1;
        }
        draw_setup(destination);
        write_at(16, 6, "Installing Open MaxView...", ATTR_DATA_HIGH);
    }
    if (!install(destination, failed_name, quiet)) {
        if (!quiet) {
            frame(7, 12, 16, 67, "Installation error");
            write_at(10, 16, "Unable to install:", ATTR_ACTIVE);
            write_at(12, 16, failed_name, ATTR_ACTIVE);
            write_at(14, 16, "Press any key.", ATTR_ACTIVE);
            getch();
            restore_screen();
        }
        printf("Open MaxView Setup failed: %s\n", failed_name);
        return 4;
    }
    if (!quiet) {
        frame(7, 10, 17, 69, "Installation complete");
        write_at(10, 14, "Open MaxView was installed in:", ATTR_ACTIVE);
        write_at(12, 14, destination, ATTR_ACTIVE);
        write_at(15, 14, "Press any key to finish.", ATTR_ACTIVE);
        getch();
        restore_screen();
    }
    printf("Open MaxView installed in %s\n", destination);
    return 0;
}

