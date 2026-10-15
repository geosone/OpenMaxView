/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <conio.h>
#include <ctype.h>
#include <direct.h>
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "catalog.h"
#include "maxbackend.h"
#include "odqapi.h"
#include "settings.h"

#define SCREEN_COLS 80
#define SCREEN_ROWS 25
/* Open 386MAX QUILIB colour roles (QUILIB/COLORS.C). */
#define ATTR_BACKGROUND   0x08  /* FG_DKGRAY | BG_BLACK */
#define ATTR_DATA         0x1f  /* FG_WHITE  | BG_BLUE  */
#define ATTR_DATA_HIGH    0x1e  /* FG_YELLOW | BG_BLUE  */
#define ATTR_QUICK        0x70  /* FG_BLACK   | BG_GRAY  */
#define ATTR_QUICK_HIGH   0x71  /* FG_BLUE    | BG_GRAY  */
#define ATTR_MENU         0x70
#define ATTR_MENU_TRIGGER 0x74  /* FG_RED     | BG_GRAY  */
#define ATTR_ACTIVE       0x3f  /* FG_WHITE   | BG_CYAN  */
#define ATTR_TRIGGER      0x34  /* FG_RED     | BG_CYAN  */
#define ATTR_SHADOW       0x08
#define MAXVANSI_MUX_QUERY     0xd710
#define MAXVANSI_MUX_SIGNATURE 0x4e41

static unsigned short far *video = (unsigned short far *)0xb8000000UL;

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
        for (position = top + 1; position <= bottom + 1 && position < SCREEN_ROWS;
             ++position)
            put_cell(position, right + 1,
                     (unsigned char)(video[position * SCREEN_COLS + right + 1] & 0xff),
                     ATTR_SHADOW);
    }
    if (bottom + 1 < SCREEN_ROWS) {
        for (position = left + 2; position <= right + 1 && position < SCREEN_COLS;
             ++position)
            put_cell(bottom + 1, position,
                     (unsigned char)(video[(bottom + 1) * SCREEN_COLS + position] & 0xff),
                     ATTR_SHADOW);
    }
}

static void draw_button(unsigned row, unsigned col, unsigned width,
                        const char *label, unsigned hot)
{
    unsigned text_col = col + (width - strlen(label)) / 2;
    fill(row, col, row, col + width - 1, ' ', ATTR_QUICK);
    write_at(row, text_col, label, ATTR_QUICK_HIGH);
    if (hot < strlen(label))
        put_cell(row, text_col + hot, (unsigned char)label[hot], 0x7f);
    shadow(row, col, row, col + width - 1);
}

static void write_wrapped(unsigned row, unsigned col, unsigned width,
                          unsigned lines, const char *text,
                          unsigned char attr)
{
    unsigned line = 0, used = 0;
    while (*text != '\0' && line < lines) {
        if (*text == ' ' && used == width) {
            ++text;
            ++line;
            used = 0;
        } else {
            put_cell(row + line, col + used, (unsigned char)*text++, attr);
            if (++used == width) {
                ++line;
                used = 0;
            }
        }
    }
}

static void frame(unsigned top, unsigned left, unsigned bottom, unsigned right,
                  const char *title)
{
    unsigned col;
    fill(top, left, bottom, right, ' ', ATTR_ACTIVE);
    put_cell(top, left, 201, ATTR_ACTIVE);
    put_cell(top, right, 187, ATTR_ACTIVE);
    put_cell(bottom, left, 200, ATTR_ACTIVE);
    put_cell(bottom, right, 188, ATTR_ACTIVE);
    for (col = left + 1; col < right; ++col) {
        put_cell(top, col, 205, ATTR_ACTIVE);
        put_cell(bottom, col, 205, ATTR_ACTIVE);
    }
    for (col = top + 1; col < bottom; ++col) {
        put_cell(col, left, 186, ATTR_ACTIVE);
        put_cell(col, right, 186, ATTR_ACTIVE);
    }
    if (title != NULL) {
        write_at(top, left + 2, " ", ATTR_ACTIVE);
        write_at(top, left + 3, title, ATTR_ACTIVE);
        write_at(top, left + 3 + strlen(title), " ", ATTR_ACTIVE);
    }
    shadow(top, left, bottom, right);
}

static int odq_resident(void)
{
    union REGS inregs, outregs;
    inregs.x.ax = ODQ_MUX_STATUS;
    inregs.x.bx = 0;
    int86(0x2f, &inregs, &outregs);
    return outregs.x.bx == ODQ_MUX_SIGNATURE;
}

static int ansi_resident(void)
{
    union REGS inregs, outregs;
    inregs.x.ax = MAXVANSI_MUX_QUERY;
    inregs.x.bx = 0;
    int86(0x2f, &inregs, &outregs);
    return outregs.x.bx == MAXVANSI_MUX_SIGNATURE;
}

static void reset_resident_state(void)
{
    union REGS inregs, outregs;
    inregs.x.ax = ODQ_MUX_RESET;
    int86(0x2f, &inregs, &outregs);
}

static int desqview_api_present(unsigned *version)
{
    union REGS inregs, outregs;
    inregs.x.ax = 0x2b01;
    inregs.x.cx = 0x4445;
    inregs.x.dx = 0x5351;
    int86(0x21, &inregs, &outregs);
    *version = outregs.x.bx;
    return outregs.h.al != 0xff;
}

static int vcpi_present(unsigned *version)
{
    union REGS inregs, outregs;
    inregs.x.ax = 0xde00;
    int86(0x67, &inregs, &outregs);
    *version = outregs.x.bx;
    return outregs.h.ah == 0;
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

static void prepare_child_screen(void)
{
    union REGS inregs, outregs;

    fill(0, 0, SCREEN_ROWS - 1, SCREEN_COLS - 1, ' ', 0x07);
    inregs.h.ah = 0x01;
    inregs.x.cx = 0x0607;
    int86(0x10, &inregs, &outregs);
    inregs.h.ah = 0x02;
    inregs.h.bh = 0;
    inregs.h.dh = 0;
    inregs.h.dl = 0;
    int86(0x10, &inregs, &outregs);
}

static void show_desktop(const odq_catalog *catalog, unsigned selected,
                         const char *status, const odq_settings *settings)
{
    unsigned row, index, first, slot;
    char memory[24];

    /* Same two-pane geometry and palette as Open 386MAX's QUILIB UI. */
    fill(0, 0, SCREEN_ROWS - 1, SCREEN_COLS - 1, 219, ATTR_BACKGROUND);
    fill(0, 0, 0, 37, ' ', ATTR_MENU);
    write_at(0, 1, "Program", ATTR_MENU);
    put_cell(0, 1, 'P', ATTR_MENU_TRIGGER);
    write_at(0, 10, "Tasks", ATTR_MENU);
    put_cell(0, 10, 'T', ATTR_MENU_TRIGGER);
    write_at(0, 18, "Info", ATTR_MENU);
    put_cell(0, 18, 'I', ATTR_MENU_TRIGGER);
    write_at(0, 25, "Help", ATTR_MENU);
    put_cell(0, 25, 'H', ATTR_MENU_TRIGGER);
    fill(0, 60, 0, 79, ' ', ATTR_DATA);
    write_at(0, 62, "Open MaxView 0.8", ATTR_DATA);
    shadow(0, 60, 0, 79);

    fill(2, 1, 21, 52, ' ', ATTR_DATA);
    shadow(2, 1, 21, 52);
    fill(2, 56, 21, 76, ' ', ATTR_QUICK);
    shadow(2, 56, 21, 76);
    write_at(3, 21, "Open Program", ATTR_DATA_HIGH);
    write_at(3, 62, "Quick Help", ATTR_QUICK_HIGH);
    if (settings->quick_help) {
        write_at(5, 58, "Select with arrows", ATTR_QUICK);
        write_at(6, 58, "or a red hotkey.", ATTR_QUICK);
        write_at(8, 58, "Enter starts the", ATTR_QUICK);
        write_at(9, 58, "selected program.", ATTR_QUICK);
    }
    if (catalog->count == 0) {
        write_at(6, 5, "No programs configured.", ATTR_DATA);
    } else {
        first = selected >= 14 ? selected - 13 : 0;
        for (index = first; index < catalog->count && index < first + 14;
             ++index) {
            unsigned char attr = index == selected ? ATTR_ACTIVE : ATTR_DATA;
            slot = index - first;
            row = 5 + slot;
            fill(row, 3, row, 50, ' ', attr);
            put_cell(row, 5, catalog->programs[index].hotkey,
                     index == selected ? ATTR_TRIGGER : ATTR_DATA_HIGH);
            write_at(row, 6, ") ", attr);
            write_at(row, 8, catalog->programs[index].title, attr);
            if (settings->show_memory && catalog->programs[index].max_kb != 0) {
                sprintf(memory, "%uK", catalog->programs[index].max_kb);
                write_at(row, 45, memory, attr);
            }
        }
        write_at(12, 58, "Selected:", ATTR_QUICK_HIGH);
        write_wrapped(13, 58, 17, 2, catalog->programs[selected].title,
                      ATTR_QUICK);
    }
    write_at(16, 58, "Status:", ATTR_QUICK_HIGH);
    write_wrapped(17, 58, 17, 3, status, ATTR_QUICK);

    draw_button(24, 1, 12, "Exit Esc", 5);
    draw_button(24, 15, 11, "Help F1", 5);
    draw_button(24, 28, 11, "Info F2", 5);
}

static void show_diagnostics(void)
{
    unsigned dv_version = 0, vcpi_version = 0;
    int api = desqview_api_present(&dv_version);
    int vcpi = vcpi_present(&vcpi_version);
    odq_max_backend_info backend;
    int backend_present = odq_max_backend_query(&backend);
    char line[70];

    frame(3, 8, 19, 71, "Diagnostics");
    sprintf(line, "Open MaxView resident API: %s", odq_resident() ? "installed" : "not installed");
    write_at(6, 12, line, ATTR_ACTIVE);
    sprintf(line, "DESQview-compatible API: %s  version %u.%02X",
            api ? "present" : "absent", dv_version >> 8, dv_version & 0xff);
    write_at(8, 12, line, ATTR_ACTIVE);
    sprintf(line, "VCPI provider: %s%s",
            vcpi ? "present, version " : "absent",
            vcpi ? "(Open 386MAX/QEMM compatible)" : "");
    write_at(10, 12, line, ATTR_ACTIVE);
    if (vcpi) {
        sprintf(line, "VCPI numeric version: %u.%02X", vcpi_version >> 8,
                vcpi_version & 0xff);
        write_at(11, 12, line, ATTR_ACTIVE);
    }
    if (backend_present) {
        sprintf(line, "Open 386MAX backend ABI %u.%u, caps %04X",
                backend.abi_version >> 8, backend.abi_version & 0xff,
                backend.capabilities);
        write_at(13, 12, line, ATTR_ACTIVE);
        sprintf(line, "Backend contexts: %u active, limit %u",
                backend.active_contexts, backend.context_limit);
        write_at(14, 12, line, ATTR_ACTIVE);
    } else {
        write_at(13, 12, "Open 386MAX MaxView backend: not detected",
                 ATTR_ACTIVE);
    }
    write_at(16, 12, "0.8 mode: configurable foreground environment",
             ATTR_ACTIVE);
    write_at(18, 12, "Press any key to return.", ATTR_ACTIVE);
    getch();
}

static void show_program_info(const odq_program *program)
{
    char line[70];
    const odq_process_profile *profile;

    frame(2, 5, 22, 74, "Program Information");
    if (program == NULL) {
        write_at(11, 18, "No program is selected.", ATTR_ACTIVE);
        write_at(20, 18, "Press any key to return.", ATTR_ACTIVE);
        getch();
        return;
    }
    write_at(4, 9, "Title:", ATTR_DATA_HIGH);
    write_wrapped(4, 17, 53, 1, program->title, ATTR_ACTIVE);
    write_at(6, 9, "Command:", ATTR_DATA_HIGH);
    write_wrapped(6, 18, 52, 2, program->command, ATTR_ACTIVE);
    write_at(9, 9, "Directory:", ATTR_DATA_HIGH);
    write_wrapped(9, 20, 50, 1,
                  program->directory[0] ? program->directory : "(current)",
                  ATTR_ACTIVE);
    sprintf(line, "Conventional memory: %u KB minimum, %u KB maximum",
            program->min_kb, program->max_kb);
    write_at(11, 9, line, ATTR_ACTIVE);

    profile = &program->profile;
    if (profile->version == 0) {
        write_at(13, 9, "Process profile: none (six-field catalogue entry)",
                 ATTR_ACTIVE);
    } else {
        sprintf(line, "Profile %u, DVP source %u, system %u KB, script %u B",
                profile->version, profile->source_version,
                profile->system_kb, profile->script_bytes);
        write_at(13, 9, line, ATTR_ACTIVE);
        sprintf(line, "Idle polls %u, EMS max %u KB, extra system %u",
                profile->idle_polls, profile->max_ems_kb,
                profile->extra_system);
        write_at(14, 9, line, ATTR_ACTIVE);
        sprintf(line, "Video %ux%u, text/graphics pages %u/%u",
                profile->columns, profile->rows, profile->text_pages,
                profile->graphics_pages);
        write_at(15, 9, line, ATTR_ACTIVE);
        sprintf(line, "Serial mask %02X, protection %02X, flags %02X/%02X/%02X/%02X",
                profile->serial_ports, profile->protection, profile->flags1,
                profile->flags2, profile->flags3, profile->flags4);
        write_at(16, 9, line, ATTR_ACTIVE);
        write_at(18, 9, "Profile retained; backend enforcement is pending.",
                 ATTR_DATA_HIGH);
    }
    write_at(20, 9, "Press any key to return.", ATTR_ACTIVE);
    getch();
}

static void show_help(void)
{
    frame(4, 12, 18, 67, "Open MaxView Help");
    write_at(7, 16, "Up/Down       Select a program", ATTR_ACTIVE);
    write_at(9, 16, "Enter/hotkey  Start a program", ATTR_ACTIVE);
    write_at(11, 16, "F2            Program information", ATTR_ACTIVE);
    write_at(12, 16, "D             System diagnostics", ATTR_ACTIVE);
    write_at(13, 16, "Esc or Q      Exit Open MaxView", ATTR_ACTIVE);
    write_at(16, 16, "Press any key to return.", ATTR_ACTIVE);
    getch();
}

static int confirm_exit(void)
{
    int key;
    frame(8, 17, 15, 62, "Leave Open MaxView");
    write_at(10, 21, "Exit to DOS?", ATTR_ACTIVE);
    write_at(12, 21, "Press Y to exit or N to continue.", ATTR_ACTIVE);
    do {
        key = toupper(getch());
    } while (key != 'Y' && key != 'N' && key != 27);
    return key == 'Y';
}

static void reload_settings(odq_settings *settings)
{
    if (odq_settings_load("MAXVSET.INI", settings, NULL) != ODQ_SETTINGS_OK)
        odq_settings_defaults(settings);
}

static void apply_resident_services(const odq_settings *settings, char *status)
{
    if (settings->auto_tsr && !odq_resident()) {
        system("MAXVTSR.COM >NUL");
        if (odq_resident())
            strcpy(status, "Resident compatibility API installed.");
    }
    if (settings->auto_ansi && !ansi_resident()) {
        system("MAXVANSI.COM >NUL");
        if (ansi_resident())
            strcpy(status, "ANSI console service installed.");
    }
}

static void reload_catalog_after_child(odq_catalog *catalog,
                                       unsigned *selected,
                                       const odq_settings *settings)
{
    odq_catalog refreshed;
    unsigned error_line;

    if (!settings->reload_catalog)
        return;
    if (odq_catalog_load("MAXVIEW.CFG", &refreshed, &error_line) !=
        ODQ_CATALOG_OK)
        return;
    *catalog = refreshed;
    if (catalog->count == 0)
        *selected = 0;
    else if (*selected >= catalog->count)
        *selected = catalog->count - 1;
}

static int launch(const odq_program *program, char *status)
{
    char old_directory[ODQ_DIR_LEN + 1];
    int result;

    if (getcwd(old_directory, sizeof(old_directory)) == NULL)
        old_directory[0] = '\0';
    if (program->directory[0] != '\0' && chdir(program->directory) != 0) {
        sprintf(status, "Cannot change to %.52s", program->directory);
        return -1;
    }
    reset_resident_state();
    prepare_child_screen();
    result = system(program->command);
    reset_resident_state();
    if (old_directory[0] != '\0')
        chdir(old_directory);
    initialise_video();
    sprintf(status, "%.42s returned code %d", program->title, result);
    return result;
}

int main(void)
{
    odq_catalog catalog;
    odq_settings settings;
    unsigned selected = 0, error_line = 0;
    int result, key;
    char status[76];

    result = odq_catalog_load("MAXVIEW.CFG", &catalog, &error_line);
    if (result == ODQ_CATALOG_IO) {
        catalog.count = 0;
        strcpy(status, "MAXVIEW.CFG was not found.");
    } else if (result != ODQ_CATALOG_OK) {
        catalog.count = 0;
        sprintf(status, "Catalogue error on line %u.", error_line);
    } else {
        sprintf(status, "%u program(s) loaded.", catalog.count);
    }

    reload_settings(&settings);

    apply_resident_services(&settings, status);
    initialise_video();

    for (;;) {
        show_desktop(&catalog, selected, status, &settings);
        key = getch();
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 59)
                show_help();
            else if (key == 60)
                show_program_info(catalog.count != 0 ?
                                  &catalog.programs[selected] : NULL);
            else if (key == 72 && selected > 0)
                --selected;
            else if (key == 80 && selected + 1 < catalog.count)
                ++selected;
            continue;
        }
        key = toupper(key);
        if (key == 'Q' || key == 27) {
            if (!settings.confirm_exit || confirm_exit())
                break;
            continue;
        }
        if (key == 'D') {
            show_diagnostics();
            continue;
        }
        if (key == 13 && catalog.count != 0) {
            launch(&catalog.programs[selected], status);
            reload_settings(&settings);
            apply_resident_services(&settings, status);
            reload_catalog_after_child(&catalog, &selected, &settings);
            continue;
        }
        if (settings.hotkey_launch && catalog.count != 0) {
            unsigned index;
            for (index = 0; index < catalog.count; ++index)
                if (catalog.programs[index].hotkey == key) {
                    selected = index;
                    launch(&catalog.programs[selected], status);
                    reload_settings(&settings);
                    apply_resident_services(&settings, status);
                    reload_catalog_after_child(&catalog, &selected, &settings);
                    break;
                }
        }
    }
    prepare_child_screen();
    return 0;
}

