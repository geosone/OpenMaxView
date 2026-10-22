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
#include "mvhost.h"
#include "mvkern.h"
#include "mvprocess.h"
#include "odqapi.h"
#include "scheduler.h"
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

/* Multitasking (kernel/mvkern.asm on Open 386MAX or QEMM):  each program
 * a task of its own, full screen; we are task 0, Alt alone comes back.
 * Without QPI programs run one at a time in the foreground. */
static int mv_on;
static char task_title[MVK_MAXTASK][ODQ_TITLE_LEN + 1];
static unsigned char task_live[MVK_MAXTASK];
static unsigned tasks_open(void);
static int view_windows;        /* Alt comes back to the windows */

/* windows:  interior position and size per task, stacking order (the last
 * is the active one) */
typedef struct mv_window {
    unsigned char top, left, rows, cols;
} mv_window;
static mv_window win[MVK_MAXTASK];
static unsigned char zorder[MVK_MAXTASK];
static unsigned nwin;

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

static void show_diagnostics(const mv_scheduler *scheduler)
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
        if (backend.qpi_version != 0) {
            sprintf(line, "QPI %u.%u, active page table %08lX",
                    backend.qpi_version >> 8,
                    backend.qpi_version & 0xff,
                    backend.qpi_context);
            write_at(15, 12, line, ATTR_ACTIVE);
        }
    } else {
        write_at(13, 12, "Open 386MAX MaxView backend: not detected",
                 ATTR_ACTIVE);
    }
    if (mv_on)
        sprintf(line, "Multitasking: %u program(s), %lu switches",
                tasks_open(), mvk_switches());
    else
        sprintf(line, "Task ledger: %u runnable; foreground execution",
                mv_scheduler_runnable(scheduler));
    write_at(16, 12, line, ATTR_ACTIVE);
    write_at(18, 12, "Press any key to return.", ATTR_ACTIVE);
    getch();
}

static void show_program_info(const odq_program *program)
{
    char line[70];
    const odq_process_profile *profile;
    mv_process_descriptor descriptor;

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
    mv_process_build(program, &descriptor);
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
    sprintf(line, "Resource contract %03X; pending %03X",
            descriptor.requested, mv_process_pending(&descriptor));
    write_at(19, 9, line, ATTR_ACTIVE);
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
    if (mv_on) {
        write_at(14, 16, "T             Running programs", ATTR_ACTIVE);
        write_at(15, 16, "Alt (alone)   Back here from a program", ATTR_ACTIVE);
        write_at(16, 16, "W             Windows of the programs", ATTR_ACTIVE);
    }
    write_at(17, 16, "Press any key to return.", ATTR_ACTIVE);
    getch();
}

static int confirm_exit(void)
{
    int key;
    char line[40];

    frame(8, 17, 15, 62, "Leave Open MaxView");
    if (tasks_open() != 0) {
        sprintf(line, "Close %u running program(s) and", tasks_open());
        write_at(10, 21, line, ATTR_ACTIVE);
        write_at(11, 21, "exit to DOS?", ATTR_ACTIVE);
    } else
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
    static odq_catalog refreshed;
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

static unsigned tasks_open(void)
{
    unsigned t, n = 0;

    for (t = 1; t < MVK_MAXTASK; ++t)
        if (task_live[t])
            ++n;
    return n;
}

static void win_add(unsigned t)
{
    unsigned k = nwin % 5;

    win[t].top = (unsigned char)(2 + 3 * k);
    win[t].left = (unsigned char)(2 + 6 * k);
    win[t].rows = 10;
    win[t].cols = 50;
    zorder[nwin++] = (unsigned char)t;
}

static void win_remove(unsigned t)
{
    unsigned i, j = 0;

    for (i = 0; i < nwin; ++i)
        if (zorder[i] != t)
            zorder[j++] = zorder[i];
    nwin = j;
}

static void start_multitasking(char *status)
{
    int rc = mvhost_init();

    if (rc == 0)
        rc = mvk_start(2);
    if (rc != 0) {
        mvk_stop();
        sprintf(status, "One program at a time: %.40s.", mvhost_error(rc));
        return;
    }
    mvk_dvkey(1);
    mv_on = 1;
}

/* ask the tasks to end, wait for them (5 s at most), stop the core */
static void stop_multitasking(void)
{
    unsigned long start = *(unsigned long far *)MK_FP(0x40, 0x6c);
    unsigned t;

    for (t = 1; t < MVK_MAXTASK; ++t)
        if (task_live[t])
            mvk_kill(t);
    while (*(unsigned long far *)MK_FP(0x40, 0x6c) - start < 91) {
        for (t = 1; t < MVK_MAXTASK; ++t)
            if (task_live[t] && mvk_state(t) == MVK_READY)
                break;
        if (t == MVK_MAXTASK)
            break;
        mvk_yield();
    }
    mvk_stop();
    mv_on = 0;
}

/* tasks that ended:  status, 1 */
static int poll_tasks(char *status)
{
    unsigned t;

    for (t = 1; t < MVK_MAXTASK; ++t)
        if (task_live[t] && mvk_state(t) != MVK_READY) {
            task_live[t] = 0;
            win_remove(t);
            sprintf(status, "%.40s ended, code %u.", task_title[t],
                    mvk_exit(t) & 0xff);
            return 1;
        }
    return 0;
}

/* a key; -1:  a task ended (redraw) */
static int wait_key(char *status)
{
    while (!kbhit()) {
        if (!mv_on)
            continue;
        if (poll_tasks(status))
            return -1;
        mvk_yield();
    }
    return getch();
}

static int launch_task(const odq_program *program, char *status)
{
    static char tail[ODQ_COMMAND_LEN + 8];
    const char *shell = getenv("COMSPEC");
    int t;

    if (shell == NULL)
        shell = "C:\\COMMAND.COM";
    /* the current directory is not per task yet:  it stays changed */
    if (program->directory[0] != '\0' && chdir(program->directory) != 0) {
        sprintf(status, "Cannot change to %.52s", program->directory);
        return -1;
    }
    sprintf(tail, " /C %.120s", program->command);
    t = mvk_create(shell, tail);
    if (t < 0) {
        sprintf(status, "%.30s: %.40s.", program->title, mvhost_error(-t));
        return -1;
    }
    strcpy(task_title[t], program->title);
    task_live[t] = 1;
    win_add(t);
    view_windows = 1;
    sprintf(status, "%.40s runs as task %d; Alt returns.", program->title, t);
    mvk_setfg(t);
    return 0;
}

static void show_tasks(char *status)
{
    unsigned list[MVK_MAXTASK], n, i, t, sel = 0;
    int key;
    char line[60];

    for (;;) {
        poll_tasks(status);
        n = 0;
        for (t = 1; t < MVK_MAXTASK; ++t)
            if (task_live[t])
                list[n++] = t;
        if (n != 0 && sel >= n)
            sel = n - 1;
        frame(4, 10, 19, 69, "Tasks");
        if (n == 0)
            write_at(8, 14, "No programs are running.", ATTR_ACTIVE);
        for (i = 0; i < n; ++i) {
            sprintf(line, " %u  %-38s Ctrl+Alt+%u ", list[i],
                    task_title[list[i]], list[i]);
            write_at(6 + i, 13, line, i == sel ? ATTR_QUICK : ATTR_ACTIVE);
        }
        write_at(17, 14, "Enter: switch to  C: close  Esc: back",
                 ATTR_ACTIVE);
        key = wait_key(status);
        if (key == -1)
            continue;
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (key == 72 && sel > 0)
                --sel;
            else if (key == 80 && sel + 1 < n)
                ++sel;
            continue;
        }
        key = toupper(key);
        if (key == 27)
            return;
        if (n == 0)
            continue;
        if (key == 13) {
            mvk_setfg(list[sel]);
            return;
        }
        if (key == 'C') {
            mvk_kill(list[sel]);
            sprintf(status, "%.40s is being closed.", task_title[list[sel]]);
        }
    }
}

static unsigned short scr[SCREEN_ROWS * SCREEN_COLS];
static unsigned short cells[SCREEN_ROWS * SCREEN_COLS];

static void sput(unsigned row, unsigned col, unsigned char ch,
                 unsigned char attr)
{
    if (row < SCREEN_ROWS && col < SCREEN_COLS)
        scr[row * SCREEN_COLS + col] = (unsigned short)(attr << 8 | ch);
}

static void swrite(unsigned row, unsigned col, const char *text,
                   unsigned char attr)
{
    while (*text != '\0')
        sput(row, col++, (unsigned char)*text++, attr);
}

static void set_cursor(unsigned row, unsigned col, int on)
{
    union REGS r;

    r.h.ah = 0x01;
    r.x.cx = on ? 0x0607 : 0x2000;
    int86(0x10, &r, &r);
    r.h.ah = 0x02;
    r.h.bh = 0;
    r.h.dh = (unsigned char)row;
    r.h.dl = (unsigned char)col;
    int86(0x10, &r, &r);
}

/* all windows onto the display; mode:  0 normal, 1 move, 2 size */
static const char *status_line = "";

static void compose(int mode)
{
    static const char *help[3] = {
        " Tab next  Enter type  Z full  M move  S size  C close  O open  Q quit ",
        " Move: arrows, Enter done ",
        " Size: arrows, Enter done "
    };
    unsigned i, r, c, t, cur, vrow, vtop;
    unsigned focus = mvk_focused();
    unsigned crow = 0, ccol = 0;
    int cursor = 0;
    char line[SCREEN_COLS + 1];

    for (i = 0; i < SCREEN_ROWS * SCREEN_COLS; ++i)
        scr[i] = ATTR_BACKGROUND << 8 | 219;
    for (c = 0; c < SCREEN_COLS; ++c) {
        sput(0, c, ' ', ATTR_MENU);
        sput(SCREEN_ROWS - 1, c, ' ', ATTR_MENU);
    }
    swrite(0, 1, "Open MaxView windows", ATTR_MENU);
    if (focus != 0) {
        sprintf(line, "Typing into %.40s; Alt returns", task_title[focus]);
        swrite(0, 24, line, ATTR_MENU_TRIGGER);
    } else
        swrite(0, 24, status_line, ATTR_MENU);
    swrite(SCREEN_ROWS - 1, 1, help[mode], ATTR_MENU);
    for (i = 0; i < nwin; ++i) {
        const mv_window *w;
        int active = i + 1 == nwin;
        unsigned char fa = active ? ATTR_ACTIVE : ATTR_DATA;
        unsigned char h = active ? 205 : 196, v = active ? 186 : 179;

        t = zorder[i];
        w = &win[t];
        cur = mvk_peek(t, cells);
        if (cur == 0xffff)
            continue;
        /* the part of the 80x25 screen with the cursor row */
        vrow = cur >> 8;
        vtop = vrow >= w->rows ? vrow - w->rows + 1 : 0;
        if (vtop + w->rows > SCREEN_ROWS)
            vtop = SCREEN_ROWS - w->rows;
        sput(w->top - 1, w->left - 1, active ? 201 : 218, fa);
        sput(w->top - 1, w->left + w->cols, active ? 187 : 191, fa);
        sput(w->top + w->rows, w->left - 1, active ? 200 : 192, fa);
        sput(w->top + w->rows, w->left + w->cols, active ? 188 : 217, fa);
        for (c = 0; c < w->cols; ++c) {
            sput(w->top - 1, w->left + c, h, fa);
            sput(w->top + w->rows, w->left + c, h, fa);
        }
        sprintf(line, " %u %.30s ", t, task_title[t]);
        swrite(w->top - 1, w->left + 1, line, fa);
        for (r = 0; r < w->rows; ++r) {
            sput(w->top + r, w->left - 1, v, fa);
            sput(w->top + r, w->left + w->cols, v, fa);
            for (c = 0; c < w->cols; ++c)
                scr[(w->top + r) * SCREEN_COLS + w->left + c] =
                    cells[(vtop + r) * SCREEN_COLS + c];
        }
        if (t == focus && (cur & 0xff) < w->cols) {
            crow = w->top + vrow - vtop;
            ccol = w->left + (cur & 0xff);
            cursor = 1;
        }
    }
    _fmemcpy(video, scr, sizeof scr);
    set_cursor(crow, ccol, cursor);
}

/* the windows of the running programs.  Returns 0:  to the launcher,
 * 1:  quit asked */
static int windows_view(char *status)
{
    unsigned long last = 0, now;
    int key, mode = 0;
    unsigned t;
    mv_window *w;

    for (;;) {
        if (poll_tasks(status) && nwin == 0)
            return 0;
        if (nwin == 0)
            return 0;
        t = zorder[nwin - 1];
        w = &win[t];
        status_line = status;
        now = *(unsigned long far *)MK_FP(0x40, 0x6c);
        if (now - last >= 2) {
            compose(mode);
            last = now;
        }
        if (mvk_focused() != 0 || !kbhit()) {
            mvk_yield();
            continue;
        }
        key = getch();
        last = 0;
        if (key == 0 || key == 0xe0) {
            key = getch();
            if (mode == 1) {
                if (key == 72 && w->top > 2) --w->top;
                if (key == 80 && w->top + w->rows < SCREEN_ROWS - 2) ++w->top;
                if (key == 75 && w->left > 1) --w->left;
                if (key == 77 && w->left + w->cols < SCREEN_COLS - 1) ++w->left;
            } else if (mode == 2) {
                if (key == 72 && w->rows > 3) --w->rows;
                if (key == 80 && w->top + w->rows < SCREEN_ROWS - 2) ++w->rows;
                if (key == 75 && w->cols > 10) --w->cols;
                if (key == 77 && w->left + w->cols < SCREEN_COLS - 1) ++w->cols;
            }
            continue;
        }
        if (mode != 0) {
            if (key == 13 || key == 27)
                mode = 0;
            continue;
        }
        key = toupper(key);
        if (key == 9 && nwin > 1) {     /* the bottom one to the top */
            unsigned char first = zorder[0];
            memmove(zorder, zorder + 1, nwin - 1);
            zorder[nwin - 1] = first;
        } else if (key == 13)
            mvk_focus(t);
        else if (key == 'Z') {
            mvk_setfg(t);
            while (mvk_fg() != 0 && mvk_state(t) == MVK_READY)
                mvk_yield();
        } else if (key == 'M')
            mode = 1;
        else if (key == 'S')
            mode = 2;
        else if (key == 'C') {
            mvk_kill(t);
            sprintf(status, "%.40s is being closed.", task_title[t]);
        } else if (key == 'O') {
            view_windows = 0;
            return 0;
        } else if (key == 'Q' || key == 27)
            return 1;
    }
}

static int launch(const odq_program *program, char *status,
                  mv_scheduler *scheduler)
{
    char old_directory[ODQ_DIR_LEN + 1];
    int result;
    unsigned child;
    mv_process_descriptor descriptor;

    if (getcwd(old_directory, sizeof(old_directory)) == NULL)
        old_directory[0] = '\0';
    if (program->directory[0] != '\0' && chdir(program->directory) != 0) {
        sprintf(status, "Cannot change to %.52s", program->directory);
        return -1;
    }
    if (!mv_process_build(program, &descriptor)) {
        strcpy(status, "Invalid process profile.");
        if (old_directory[0] != '\0')
            chdir(old_directory);
        return -1;
    }
    if (!mv_scheduler_create(scheduler, &child)) {
        strcpy(status, "Task table is full.");
        if (old_directory[0] != '\0')
            chdir(old_directory);
        return -1;
    }
    if (!mv_process_bind(&descriptor, scheduler, child)) {
        mv_scheduler_terminate(scheduler, child);
        strcpy(status, "Cannot bind process profile.");
        if (old_directory[0] != '\0')
            chdir(old_directory);
        return -1;
    }
    if (!mv_scheduler_dispatch(scheduler, NULL) ||
        mv_scheduler_current(scheduler) != child) {
        mv_process_unbind(&descriptor, child);
        mv_scheduler_terminate(scheduler, child);
        strcpy(status, "Cannot dispatch child task.");
        if (old_directory[0] != '\0')
            chdir(old_directory);
        return -1;
    }
    reset_resident_state();
    prepare_child_screen();
    result = system(program->command);
    reset_resident_state();
    mv_process_unbind(&descriptor, child);
    mv_scheduler_terminate(scheduler, child);
    mv_scheduler_dispatch(scheduler, NULL);
    if (old_directory[0] != '\0')
        chdir(old_directory);
    initialise_video();
    sprintf(status, "%.42s returned code %d", program->title, result);
    return result;
}

int main(void)
{
    static odq_catalog catalog;
    odq_settings settings;
    mv_scheduler scheduler;
    unsigned selected = 0, error_line = 0;
    unsigned desktop_task;
    int result, key;
    char status[76];

    mv_scheduler_init(&scheduler);
    if (!mv_scheduler_create(&scheduler, &desktop_task) ||
        !mv_scheduler_dispatch(&scheduler, NULL)) {
        fputs("Open MaxView cannot initialise its task table.\n", stderr);
        return 1;
    }

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
    start_multitasking(status);
    initialise_video();

    for (;;) {
        if (mv_on && view_windows && tasks_open() != 0) {
            if (windows_view(status) == 0)
                continue;
            if (confirm_exit())
                break;
            continue;
        }
        view_windows = 0;
        initialise_video();
        show_desktop(&catalog, selected, status, &settings);
        key = wait_key(status);
        if (key == -1)
            continue;
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
            if ((!settings.confirm_exit && tasks_open() == 0) ||
                confirm_exit())
                break;
            continue;
        }
        if (key == 'T' && mv_on) {
            show_tasks(status);
            continue;
        }
        if (key == 'W' && mv_on && tasks_open() != 0) {
            view_windows = 1;
            continue;
        }
        if (key == 'D') {
            show_diagnostics(&scheduler);
            continue;
        }
        if (key == 13 && catalog.count != 0 && mv_on) {
            launch_task(&catalog.programs[selected], status);
            continue;
        }
        if (key == 13 && catalog.count != 0) {
            launch(&catalog.programs[selected], status, &scheduler);
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
                    if (mv_on) {
                        launch_task(&catalog.programs[selected], status);
                        break;
                    }
                    launch(&catalog.programs[selected], status, &scheduler);
                    reload_settings(&settings);
                    apply_resident_services(&settings, status);
                    reload_catalog_after_child(&catalog, &selected, &settings);
                    break;
                }
        }
    }
    if (mv_on)
        stop_multitasking();
    prepare_child_screen();
    return 0;
}

