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
#define MV_TASKS    16  /* task slots, MAXVIEW's included (DESQview's
                         * default common memory:  14 windows) */
#define LIST_ROWS   10
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
static unsigned char task_parent[MVK_MAXTASK]; /* APP_START's */
static unsigned tasks_open(void);
static int view_windows;        /* Alt comes back to the windows */

/* windows:  interior position and size per task, stacking order (the last
 * is the active one) */
typedef struct mv_window {
    unsigned char top, left, rows, cols;
    unsigned gpos, gsize;       /* the task's own window (D70Dh), 0:  none */
    unsigned char hidden;       /* Hide, Put Aside:  not on the screen */
    unsigned char aside;        /* Put Aside:  held until switched to */
    unsigned char frozen;       /* Freeze:  runs only with the keys */
    unsigned char scrolled;     /* Scroll:  the view at vtop, hoff */
    unsigned char vtop, hoff;
    unsigned char exclusive;    /* Tune:  not sharing the CPU in front */
    unsigned char colors;       /* Change Colors:  the program's 07h shown
                                 * in fg on bg (0:  its own colours) */
    unsigned char fg, bg;
} mv_window;
static unsigned tune_fg = 6, tune_bg = 2;      /* mvk_start(2)'s slices */
static mv_window win[MVK_MAXTASK];
static unsigned char zorder[MVK_MAXTASK];
static unsigned nwin;

static unsigned short far *video = (unsigned short far *)0xb8000000UL;

/* the windows view:  desk_rows of 80 columns (Video Options:  25, 43, 50
 * or 60 through MAXTEXT); a task's screen stays 80x25 */
#define DESK_MAX_ROWS 60
static unsigned desk_rows = SCREEN_ROWS, video_rows = SCREEN_ROWS;

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

/* MAXTEXT, Open 386MAX's text mode driver, through its public handle
 * IOCTL API (1.x, device MAXTEXT$):  the modes it offers, a switch */
#pragma pack(push, 1)
typedef struct mt_status {
    char signature[4];                  /* MXT1 */
    unsigned short version, size, flags;
    unsigned char bios_mode, page;
    unsigned short columns, rows, font_height;
    unsigned short resident_segment, resident_bytes, modes;
} mt_status;
typedef struct mt_control {
    char signature[4];                  /* MXTC */
    unsigned short command, columns, rows;
    unsigned short scratch_segment, scratch_paragraphs, result;
} mt_control;
#pragma pack(pop)
#define MT_SCRATCH_PARAS 0x1a00         /* 104 KiB for one switch */
static int mt_handle = -1;
static unsigned mt_modes;               /* 80x25 1, 80x43 2, 80x50 4, 80x60 8 */
static const unsigned mt_rows[4] = { 25, 43, 50, 60 };

static int mt_query(mt_status *st)
{
    union REGS r;
    struct SREGS sr;

    segread(&sr);
    r.x.ax = 0x4402;
    r.x.bx = (unsigned)mt_handle;
    r.x.cx = sizeof *st;
    r.x.dx = (unsigned)st;
    intdosx(&r, &r, &sr);
    return !r.x.cflag && r.x.ax == sizeof *st &&
           memcmp(st->signature, "MXT1", 4) == 0 &&
           st->version >> 8 == 1 && st->version >= 0x0101 &&
           st->size == sizeof *st;
}

static void mt_open(void)
{
    union REGS r;
    mt_status st;
    int h;

    if (_dos_open("MAXTEXT$", 2, &h) != 0)
        return;
    r.x.ax = 0x4400;                    /* a device */
    r.x.bx = (unsigned)h;
    intdos(&r, &r);
    mt_handle = h;
    if (r.x.cflag || !(r.x.dx & 0x80) || !mt_query(&st)) {
        _dos_close(h);
        mt_handle = -1;
        return;
    }
    mt_modes = st.modes & 15;
}

/* 80 x rows through MAXTEXT, in a critical section (no task switch while
 * it changes the hardware); 0 or its result (-1:  no MAXTEXT, memory) */
static int mt_set(unsigned rows)
{
    union REGS r;
    struct SREGS sr;
    mt_control c;
    mt_status st;
    unsigned seg, i, err;

    for (i = 0; i < 4 && mt_rows[i] != rows; ++i)
        ;
    if (mt_handle < 0 || i == 4 || !(mt_modes & 1u << i))
        return -1;
    if (_dos_allocmem(MT_SCRATCH_PARAS, &seg) != 0)
        return -1;
    memset(&c, 0, sizeof c);
    memcpy(c.signature, "MXTC", 4);
    c.command = 1;
    c.columns = SCREEN_COLS;
    c.rows = rows;
    c.scratch_segment = seg;
    c.scratch_paragraphs = MT_SCRATCH_PARAS;
    r.x.ax = 0x101b;                    /* BEGINC */
    int86(0x15, &r, &r);
    segread(&sr);
    r.x.ax = 0x4403;
    r.x.bx = (unsigned)mt_handle;
    r.x.cx = sizeof c;
    r.x.dx = (unsigned)&c;
    intdosx(&r, &r, &sr);
    err = r.x.cflag || r.x.ax != sizeof c;
    r.x.ax = 0x101c;                    /* ENDC */
    int86(0x15, &r, &r);
    _dos_freemem(seg);
    if (err)
        return c.result != 0 ? (int)c.result : -1;
    if (c.result != 0)
        return (int)c.result;
    if (!mt_query(&st) || st.rows != rows || st.columns != SCREEN_COLS)
        return -1;
    return 0;
}

/* the display's text rows (the BIOS's) */
static unsigned bios_rows(void)
{
    return *(unsigned char far *)MK_FP(0x40, 0x84) + 1u;
}

/* the windows view in rows (from the display as it is); 0 or MAXTEXT's
 * result */
static int desk_set(unsigned rows)
{
    int rc = 0;

    if (bios_rows() != rows)
        rc = mt_set(rows);
    desk_rows = bios_rows();
    if (desk_rows > DESK_MAX_ROWS || desk_rows < SCREEN_ROWS)
        desk_rows = SCREEN_ROWS;
    return rc;
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
    sprintf(line, "DESQview-compatible API: %s  version %u.%02u",
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
    win[t].gpos = win[t].gsize = 0;
    win[t].hidden = win[t].aside = win[t].frozen = win[t].scrolled = 0;
    win[t].exclusive = win[t].colors = 0;
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
    int rc = mvhost_init(MV_TASKS);

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

/* tasks that ended, or one a task started (APP_START, in front as in
 * DESQview):  status, 1 */
static int poll_tasks(char *status)
{
    static char title[ODQ_TITLE_LEN + 1];
    unsigned t, from;
    int n, shown;

    n = mvhost_appstart(&from, title, &shown);
    if (n > 0) {
        strcpy(task_title[n], title);
        task_live[n] = 1;
        task_parent[n] = (unsigned char)from;
        win_add(n);
        view_windows = 1;
        sprintf(status, "%.40s runs as task %d; Alt returns.", title, n);
        if (shown)
            mvk_setfg(n);
        return 1;
    }
    for (t = 1; t < MVK_MAXTASK; ++t)
        if (task_live[t] && mvk_state(t) != MVK_READY) {
            unsigned p = task_parent[t];

            task_live[t] = 0;
            task_parent[t] = 0;
            win_remove(t);
            sprintf(status, "%.40s ended, code %u.", task_title[t],
                    mvk_exit(t) & 0xff);
            /* the one that started it in front again */
            if (p != 0 && p < MVK_MAXTASK && task_live[p] && mvk_fg() == 0)
                mvk_setfg(p);
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
    int t;

    t = mvhost_launch(program->directory, program->command, 0);
    if (t == -MVE_DIR) {
        sprintf(status, "Cannot change to %.52s", program->directory);
        return -1;
    }
    if (t < 0) {
        sprintf(status, "%.30s: %.40s.", program->title, mvhost_error(-t));
        return -1;
    }
    strcpy(task_title[t], program->title);
    mvhost_title(t, program->title);
    task_live[t] = 1;
    win_add(t);
    view_windows = 1;
    sprintf(status, "%.40s runs as task %d; Alt returns.", program->title, t);
    mvk_setfg(t);
    return 0;
}

static void show_tasks(char *status)
{
    unsigned list[MVK_MAXTASK], n, i, t, sel = 0, top = 0;
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
        if (sel < top)
            top = sel;
        if (sel >= top + LIST_ROWS)
            top = sel - LIST_ROWS + 1;
        frame(4, 10, 19, 69, "Tasks");
        if (n == 0)
            write_at(8, 14, "No programs are running.", ATTR_ACTIVE);
        /* IDs as DESQview's:  1-9, then A, B, ...; Ctrl+Alt only 1-9 */
        for (i = top; i < n && i < top + LIST_ROWS; ++i) {
            char hot[12] = "";

            t = list[i];
            if (t < 10)
                sprintf(hot, "Ctrl+Alt+%u", t);
            sprintf(line, " %c  %-38s %-10s ",
                    t < 10 ? '0' + t : 'A' + t - 10, task_title[t], hot);
            write_at(6 + i - top, 13, line, i == sel ? ATTR_QUICK : ATTR_ACTIVE);
        }
        if (top > 0)
            write_at(5, 66, "\x18", ATTR_ACTIVE);
        if (top + LIST_ROWS < n)
            write_at(16, 66, "\x19", ATTR_ACTIVE);
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

static unsigned short scr[DESK_MAX_ROWS * SCREEN_COLS];
static unsigned short cells[SCREEN_ROWS * SCREEN_COLS];

static void sput(unsigned row, unsigned col, unsigned char ch,
                 unsigned char attr)
{
    if (row < desk_rows && col < SCREEN_COLS)
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

static void dv_menu_draw(void);

/* Change Colors:  a colour (nibble) of the program as its window shows it,
 * black and grey (and their bright ones) the window's colours */
static unsigned win_color(const mv_window *w, unsigned n)
{
    switch (n) {
    case 0:  return w->bg;
    case 8:  return w->bg | 8;
    case 7:  return w->fg;
    case 15: return w->fg | 8;
    }
    return n;
}

/* the front window:  the last one shown in zorder, 0:  none */
static unsigned front(void)
{
    unsigned i;

    for (i = nwin; i-- > 0;)
        if (!win[zorder[i]].hidden)
            return zorder[i];
    return 0;
}

/* The windows on a black desk (each showing its program's own colours,
 * framed in Open 386MAX's), a message (status_line) on the bottom row;
 * MAXVIEW's menu over them while it has the keys (mode 0); mode 1, 2:
 * moving, resizing the front window */
static void compose(int mode)
{
    unsigned i, r, c, t, cur, vrow, vtop, hoff, gpos, gsize;
    unsigned focus = mvk_focused();
    unsigned crow = 0, ccol = 0;
    int cursor = 0;
    char line[SCREEN_COLS + 1];

    for (i = 0; i < desk_rows * SCREEN_COLS; ++i)
        scr[i] = 0x0720;
    for (i = 0; i < nwin; ++i) {
        mv_window *w;
        int active = zorder[i] == front();
        unsigned char fa = active ? ATTR_ACTIVE : ATTR_DATA;
        unsigned char h = active ? 205 : 196, v = active ? 186 : 179;

        t = zorder[i];
        w = &win[t];
        if (w->hidden)
            continue;
        cur = mvk_peek(t, cells);
        if (cur == 0xffff)
            continue;
        vrow = cur >> 8;
        hoff = 0;
        if (mvhost_owngeom(t, &gpos, &gsize)) {
            /* its own window sized (and placed):  the window that size
             * and there, as DESQview's, showing it */
            if (gpos != w->gpos || gsize != w->gsize) {
                w->gpos = gpos;
                w->gsize = gsize;
                w->rows = (unsigned char)(gsize >> 8);
                w->cols = (unsigned char)gsize;
                if (w->rows > SCREEN_ROWS)
                    w->rows = SCREEN_ROWS;
                if (w->rows > desk_rows - 4)
                    w->rows = (unsigned char)(desk_rows - 4);
                if (w->cols > SCREEN_COLS - 2)
                    w->cols = SCREEN_COLS - 2;
                w->top = (unsigned char)(gpos >> 8);
                w->left = (unsigned char)gpos;
                if (w->top < 2)
                    w->top = 2;
                if (w->top + w->rows > desk_rows - 2)
                    w->top = (unsigned char)(desk_rows - 2 - w->rows);
                if (w->left < 1)
                    w->left = 1;
                if (w->left + w->cols > SCREEN_COLS - 1)
                    w->left = (unsigned char)(SCREEN_COLS - 1 - w->cols);
            }
            vtop = gpos >> 8;
            hoff = gpos & 0xff;
            if (vtop + w->rows > SCREEN_ROWS)
                vtop = SCREEN_ROWS - w->rows;
            if (hoff + w->cols > SCREEN_COLS)
                hoff = SCREEN_COLS - w->cols;
        } else {
            /* the part of the 80x25 screen with the cursor row */
            vtop = vrow >= w->rows ? vrow - w->rows + 1 : 0;
            if (vtop + w->rows > SCREEN_ROWS)
                vtop = SCREEN_ROWS - w->rows;
        }
        if (w->scrolled) {              /* Scroll:  the view kept there */
            if (w->vtop + w->rows > SCREEN_ROWS)
                w->vtop = (unsigned char)(SCREEN_ROWS - w->rows);
            if (w->hoff + w->cols > SCREEN_COLS)
                w->hoff = (unsigned char)(SCREEN_COLS - w->cols);
            vtop = w->vtop;
            hoff = w->hoff;
        }
        sput(w->top - 1, w->left - 1, active ? 201 : 218, fa);
        sput(w->top - 1, w->left + w->cols, active ? 187 : 191, fa);
        sput(w->top + w->rows, w->left - 1, active ? 200 : 192, fa);
        sput(w->top + w->rows, w->left + w->cols, active ? 188 : 217, fa);
        for (c = 0; c < w->cols; ++c) {
            sput(w->top - 1, w->left + c, h, fa);
            sput(w->top + w->rows, w->left + c, h, fa);
        }
        /* the title as DESQview's:  "1==DOS" */
        sprintf(line, "%c%c%c%.30s", t < 10 ? '0' + t : 'A' + t - 10, h, h,
                task_title[t]);
        for (c = 3; line[c]; ++c)       /* blanks as the frame:  "DOS=(128K)" */
            if (line[c] == ' ')
                line[c] = (char)h;
        swrite(w->top - 1, w->left, line, fa);
        for (r = 0; r < w->rows; ++r) {
            sput(w->top + r, w->left - 1, v, fa);
            sput(w->top + r, w->left + w->cols, v, fa);
            for (c = 0; c < w->cols; ++c) {
                unsigned short cell =
                    cells[(vtop + r) * SCREEN_COLS + hoff + c];

                if (w->colors)
                    cell = (unsigned short)(win_color(w, cell >> 12) << 12 |
                                            win_color(w, cell >> 8 & 15) << 8 |
                                            (cell & 0xff));
                scr[(w->top + r) * SCREEN_COLS + w->left + c] = cell;
            }
        }
        if (t == focus && (cur & 0xff) >= hoff &&
            (cur & 0xff) < hoff + w->cols && vrow >= vtop &&
            vrow < vtop + w->rows) {
            crow = w->top + vrow - vtop;
            ccol = w->left + (cur & 0xff) - hoff;
            cursor = 1;
        }
    }
    if (status_line[0] != '\0')
        swrite(desk_rows - 1, 0, status_line, 0x70);
    if (mode >= 1 && mode <= 5) {
        static const char *const hint[] = {
            " Move:  arrows, Enter done ", " Resize:  arrows, Enter done ",
            " Scroll:  arrows, Enter done ", " Position:  1-9 ",
            " Change Colors:  Left/Right text, Up/Down background, Enter done, Esc back "
        };

        swrite(desk_rows - 1, 0, hint[mode - 1], 0x70);
    } else if (focus == 0)
        dv_menu_draw();
    _fmemcpy(video, scr, desk_rows * SCREEN_COLS * sizeof scr[0]);
    set_cursor(crow, ccol, cursor);
}

/* MAXVIEW's menu:  its items cover DESQview 2.80's menus (at the top right,
 * about their size); the look is Open 386MAX's (QUILIB/MENU.C):  a single frame
 * black on grey with the title in it and a shadow, the bar reversed and
 * bright, an item's trigger letter red, items not available yet dark grey;
 * the key also at the right. */
#define MENU_ATTR      0x70     /* FG_BLACK | BG_GRAY */
#define MENU_BAR       0x0f     /* REVATT, FG_BRIGHT */
#define MENU_TRIGGER   0x74     /* FG_RED on the background */
#define MENU_BAR_TRIG  0x0c
#define MENU_DISABLED  0x78     /* FG_DKGRAY | BG_GRAY */
enum { DV_ITEM, DV_LINE, DV_TEXT, DV_BLANK };
typedef struct dv_item {
    unsigned char kind;
    const char *label;
    const char *key;            /* "" or NULL:  not available */
    int act;
} dv_item;

#define DV_MAX 24
static dv_item dv_items[DV_MAX];
static unsigned dv_count, dv_sel, dv_width;
static const char *dv_title;
static char dv_keys[DV_MAX][4];  /* keys made up at run time */
static char dv_labels[DV_MAX][ODQ_TITLE_LEN + 1];

static int dv_usable(unsigned i)
{
    return dv_items[i].kind == DV_ITEM && dv_items[i].key != NULL &&
           dv_items[i].key[0] != '\0';
}

static void dv_menu_draw(void)
{
    unsigned left, right, r, c, i, bottom;
    unsigned char a;

    if (dv_title == NULL)
        return;
    right = SCREEN_COLS - 3;            /* (the shadow beside it) */
    left = right - dv_width - 1;
    bottom = dv_count + 1;
    for (r = 0; r <= bottom; ++r)
        for (c = left; c <= right; ++c)
            sput(r, c, ' ', MENU_ATTR);
    for (c = left + 1; c < right; ++c) {
        sput(0, c, 0xc4, MENU_ATTR);
        sput(bottom, c, 0xc4, MENU_ATTR);
    }
    for (r = 1; r < bottom; ++r) {
        sput(r, left, 0xb3, MENU_ATTR);
        sput(r, right, 0xb3, MENU_ATTR);
    }
    sput(0, left, 0xda, MENU_ATTR);
    sput(0, right, 0xbf, MENU_ATTR);
    sput(bottom, left, 0xc0, MENU_ATTR);
    sput(bottom, right, 0xd9, MENU_ATTR);
    sput(0, left + 2, ' ', MENU_ATTR);
    swrite(0, left + 3, dv_title, MENU_ATTR);
    sput(0, left + 3 + strlen(dv_title), ' ', MENU_ATTR);
    for (r = 1; r <= bottom + 1 && r < desk_rows; ++r)    /* the shadow */
        for (c = right + 1; c <= right + 2; ++c)
            sput(r, c, (unsigned char)scr[r * SCREEN_COLS + c], 0x08);
    if (bottom + 1 < desk_rows)
        for (c = left + 2; c <= right; ++c)
            sput(bottom + 1, c, (unsigned char)scr[(bottom + 1) * SCREEN_COLS + c],
                 0x08);
    for (i = 0; i < dv_count; ++i) {
        const dv_item *it = &dv_items[i];
        int bar = i == dv_sel && dv_usable(i);
        const char *k = it->key;

        r = 1 + i;
        if (it->kind == DV_LINE) {
            for (c = left + 2; c < right - 1; ++c)
                sput(r, c, 0xc4, MENU_ATTR);
            continue;
        }
        if (it->kind == DV_TEXT) {
            swrite(r, left + 1 + (dv_width - strlen(it->label)) / 2, it->label,
                   MENU_ATTR);
            continue;
        }
        if (it->kind != DV_ITEM)
            continue;
        a = bar ? MENU_BAR : dv_usable(i) ? MENU_ATTR : MENU_DISABLED;
        for (c = left + 1; c < right; ++c)
            sput(r, c, ' ', a);
        swrite(r, left + 2, it->label, a);
        if (k != NULL && k[0] > ' ') {
            const char *p = NULL;

            swrite(r, right - 1 - strlen(k), k, a);
            if (k[1] == '\0') {         /* the trigger letter in its name */
                for (p = it->label; *p != '\0' && toupper(*p) != k[0]; ++p)
                    ;
                if (*p != '\0')
                    sput(r, left + 2 + (unsigned)(p - it->label),
                         (unsigned char)*p, bar ? MENU_BAR_TRIG : MENU_TRIGGER);
            }
        }
    }
}

static void dv_begin(const char *title, unsigned width)
{
    dv_title = title;
    dv_width = width;
    dv_count = 0;
    dv_sel = 0;
}

static void dv_add(unsigned char kind, const char *label, const char *key,
                   int act)
{
    if (dv_count < DV_MAX) {
        dv_items[dv_count].kind = kind;
        dv_items[dv_count].label = label;
        dv_items[dv_count].key = key;
        dv_items[dv_count].act = act;
        ++dv_count;
    }
}

/* the bar on the first available item; dir:  move it up (-1) or down */
static void dv_bar(int dir)
{
    unsigned i, n = dv_count;

    if (dir == 0) {
        for (i = 0; i < n && !dv_usable(i); ++i)
            ;
        dv_sel = i < n ? i : 0;
        return;
    }
    for (i = 1; i <= n; ++i) {
        unsigned j = (dv_sel + n + (dir < 0 ? -(int)i : (int)i)) % n;

        if (dv_usable(j)) {
            dv_sel = j;
            return;
        }
    }
}

/* the action of the item whose key is KEY (a letter, or "F1" for the
 * scan code 59), -1:  none */
static int dv_find(int key, int scan)
{
    unsigned i;

    for (i = 0; i < dv_count; ++i) {
        const char *k = dv_items[i].key;

        if (!dv_usable(i))
            continue;
        if (scan == 59 && strcmp(k, "F1") == 0)
            return dv_items[i].act;
        if (scan == 0 && k[1] == '\0' && toupper(key) == k[0])
            return dv_items[i].act;
    }
    return -1;
}

/* the menus (as DESQview 2.80's; what MaxView cannot do yet has no key) */
enum {
    DV_MAIN, DV_OPEN, DV_SWITCH, DV_CLOSE, DV_REARRANGE, DV_QUIT, DV_TUNE,
    DV_VIDEO
};
enum {
    A_OPEN = 1, A_SWITCH, A_CLOSE, A_REARRANGE, A_ZOOM, A_QUIT, A_MOVE,
    A_RESIZE, A_YES, A_NO, A_SCROLL, A_POSITION, A_FREEZE, A_HIDE, A_ASIDE,
    A_COLORS, A_TUNE, A_BACKGROUND, A_SHARE, A_FGTICKS, A_BGTICKS,
    A_VIDEO, A_PLACE = 50, A_ROWS = 60, A_PROGRAM = 100, A_WINDOW = 200
};

static void dv_build(unsigned menu, const odq_catalog *catalog)
{
    unsigned i, t, n;

    switch (menu) {
    case DV_OPEN:
        dv_begin("Open Window", 22);
        n = catalog->count < 17 ? catalog->count : 17;
        for (i = 0; i < n; ++i) {
            const odq_program *p = &catalog->programs[i];

            sprintf(dv_labels[i], "%.16s", p->title);
            dv_keys[i][0] = (char)toupper(p->hotkey);
            dv_keys[i][1] = '\0';
            dv_add(DV_ITEM, dv_labels[i], p->hotkey > ' ' ? dv_keys[i] : "",
                   A_PROGRAM + i);
        }
        /* without a hotkey:  Enter on it */
        for (i = 0; i < n; ++i)
            if (dv_keys[i][0] <= ' ')
                dv_items[i].key = " ";
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_ITEM, "Add a Program", "", 0);
        dv_add(DV_ITEM, "Delete a Program", "", 0);
        dv_add(DV_ITEM, "Change a Program", "", 0);
        break;
    case DV_SWITCH:
        dv_begin("Switch Windows", 22);
        n = 0;
        for (t = 1; t < MVK_MAXTASK && n < 20; ++t)
            if (task_live[t]) {
                sprintf(dv_labels[n], "%.16s", task_title[t]);
                dv_keys[n][0] = (char)(t < 10 ? '0' + t : 'A' + t - 10);
                dv_keys[n][1] = '\0';
                dv_add(DV_ITEM, dv_labels[n], dv_keys[n], A_WINDOW + t);
                ++n;
            }
        break;
    case DV_CLOSE:
    case DV_QUIT:
        dv_begin(menu == DV_CLOSE ? "Close Window" : "Quit MaxView", 22);
        dv_add(DV_TEXT, "Are you sure ?", "", 0);
        dv_add(DV_BLANK, "", "", 0);
        dv_add(DV_ITEM, "Yes", "Y", A_YES);
        dv_add(DV_ITEM, "No", "N", A_NO);
        break;
    case DV_REARRANGE:
        dv_begin("Rearrange", 22);
        dv_add(DV_ITEM, "Move", "M", A_MOVE);
        dv_add(DV_ITEM, "Resize", "R", A_RESIZE);
        dv_add(DV_ITEM, "Scroll", "S", A_SCROLL);
        dv_add(DV_ITEM, "Position", "1-9", A_POSITION);
        dv_add(DV_LINE, "", "", 0);
        t = front();
        dv_add(DV_ITEM, t != 0 && win[t].frozen ? "Unfreeze" : "Freeze", "F",
               A_FREEZE);
        dv_add(DV_ITEM, "Hide", "H", A_HIDE);
        dv_add(DV_ITEM, "Put Aside", "P", A_ASIDE);
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_ITEM, "Change Colors", "C", A_COLORS);
        dv_add(DV_ITEM, "Video Options", "V", A_VIDEO);
        dv_add(DV_ITEM, "Tune Performance", "T", A_TUNE);
        break;
    case DV_VIDEO:                      /* what MAXTEXT offers */
        dv_begin("Video Options", 22);
        dv_add(DV_TEXT, mt_handle < 0 ? "(MAXTEXT not loaded)"
               : "Text rows (MAXTEXT)", "", 0);
        for (i = 0; i < 4; ++i) {
            sprintf(dv_labels[i], "80 x %u%s", mt_rows[i],
                    mt_rows[i] == desk_rows ? "  *" : "");
            dv_keys[i][0] = (char)('1' + i);
            dv_keys[i][1] = '\0';
            dv_add(DV_ITEM, dv_labels[i], mt_modes & 1u << i ? dv_keys[i] : "",
                   A_ROWS + i);
        }
        break;
    case DV_TUNE:                       /* a key or Enter changes the value */
        t = front();
        dv_begin("Tune Performance", 28);
        dv_add(DV_TEXT, "This Window", "", 0);
        sprintf(dv_labels[0], "Run in background   [%c]",
                win[t].frozen ? 'N' : 'Y');
        dv_add(DV_ITEM, dv_labels[0], "B", A_BACKGROUND);
        sprintf(dv_labels[1], "Share CPU in front  [%c]",
                win[t].exclusive ? 'N' : 'Y');
        dv_add(DV_ITEM, dv_labels[1], "S", A_SHARE);
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_TEXT, "System", "", 0);
        sprintf(dv_labels[2], "Foreground ticks  [%2u]", tune_fg);
        dv_add(DV_ITEM, dv_labels[2], "F", A_FGTICKS);
        sprintf(dv_labels[3], "Background ticks  [%2u]", tune_bg);
        dv_add(DV_ITEM, dv_labels[3], "K", A_BGTICKS);
        break;
    default:
        dv_begin("MaxView", 22);
        dv_add(DV_ITEM, "Open Window", "O", A_OPEN);
        dv_add(DV_ITEM, "Switch Windows", "S", A_SWITCH);
        dv_add(DV_ITEM, "Close Window", "C", A_CLOSE);
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_ITEM, "Rearrange", "R", A_REARRANGE);
        dv_add(DV_ITEM, "Zoom", "Z", A_ZOOM);
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_ITEM, "Mark", "", 0);
        dv_add(DV_ITEM, "Transfer", "", 0);
        dv_add(DV_ITEM, "Scissors", "", 0);
        dv_add(DV_LINE, "", "", 0);
        dv_add(DV_ITEM, "Help", "", 0);
        dv_add(DV_ITEM, "Quit MaxView", "Q", A_QUIT);
        break;
    }
}

/* Position 1-9:  the frame's top, left, bottom, right (DESQview 2.80's
 * places:  the halves, the middle, the quarters) */
static const unsigned char places[9][4] = {
    { 0, 0, 11, 79 }, { 13, 0, 24, 79 }, { 4, 15, 20, 64 },
    { 0, 0, 24, 39 }, { 0, 41, 24, 79 }, { 0, 0, 11, 39 },
    { 0, 41, 11, 79 }, { 13, 0, 24, 39 }, { 13, 41, 24, 79 }
};

/* a row of places on a desk of desk_rows (the halves meet in the middle) */
static unsigned place_row(unsigned r)
{
    unsigned half = desk_rows / 2;

    if (r == 11)
        return half - 1;
    if (r == 13)
        return half + 1;
    return r * (desk_rows - 1) / 24;
}

static void place(mv_window *w, unsigned n)
{
    const unsigned char *p = places[n];
    unsigned top = place_row(p[0]), bottom = place_row(p[2]);

    w->top = (unsigned char)(top + 1);
    w->left = (unsigned char)(p[1] + 1);
    w->rows = (unsigned char)(bottom - top - 1);
    if (w->rows > SCREEN_ROWS)          /* (a task's screen:  25 rows) */
        w->rows = SCREEN_ROWS;
    w->cols = (unsigned char)(p[3] - p[1] - 1);
}

/* Hide, Put Aside:  window t off the screen (put aside:  held), under the
 * others; the next one shown is the front */
static void win_hide(unsigned t, int aside)
{
    unsigned i;

    win[t].hidden = 1;
    if (aside) {
        win[t].aside = 1;
        mvk_freeze(t, 1);
    }
    for (i = 0; i < nwin; ++i)
        if (zorder[i] == t) {
            memmove(zorder + 1, zorder, i);
            zorder[0] = (unsigned char)t;
            break;
        }
}

/* the front window (the last of zorder) gets the keys; hidden, put aside:
 * shown again (running) */
static void to_window(unsigned t)
{
    unsigned i;

    win[t].hidden = 0;
    if (win[t].aside) {
        win[t].aside = 0;
        mvk_freeze(t, win[t].frozen);
    }

    for (i = 0; i < nwin; ++i)
        if (zorder[i] == t) {
            memmove(zorder + i, zorder + i + 1, nwin - i - 1);
            zorder[nwin - 1] = (unsigned char)t;
            break;
        }
    mvk_focus(t);
}

/* the windows of the running programs, MAXVIEW's menu over them while it
 * has the keys (Alt), as DESQview's.  Returns 0:  no windows (to the
 * launcher), 2:  quit confirmed */
static int windows_view(const odq_catalog *catalog, char *status)
{
    unsigned long last = 0, now;
    int key, scan, act, mode = 0;
    unsigned t, sel, menu = DV_MAIN, focus, last_focus = 0xffff;
    int fresh = 1;
    mv_window *w, saved;

    for (;;) {
        if (poll_tasks(status) && nwin == 0)
            return 0;
        if (nwin == 0)
            return 0;
        t = front();
        w = &win[t];
        focus = mvk_focused();
        if (focus == 0 && last_focus != 0) {    /* Alt:  the menu again */
            menu = DV_MAIN;
            fresh = 1;
        }
        last_focus = focus;
        sel = dv_sel;
        dv_build(menu, catalog);
        if (fresh) {
            dv_bar(0);
            fresh = 0;
        } else {
            dv_sel = sel < dv_count ? sel : 0;
            if (!dv_usable(dv_sel))
                dv_bar(0);
        }
        status_line = status;
        if (mvk_fg() == 0 && bios_rows() != desk_rows &&
            bios_rows() >= SCREEN_ROWS && bios_rows() <= DESK_MAX_ROWS)
            desk_set(video_rows);       /* (back from a program full screen) */
        now = *(unsigned long far *)MK_FP(0x40, 0x6c);
        if (now - last >= 2) {
            compose(mode);
            last = now;
        }
        if (focus != 0 || !kbhit()) {
            mvk_yield();
            continue;
        }
        key = getch();
        scan = 0;
        last = 0;
        status[0] = '\0';
        if (key == 0 || key == 0xe0) {
            scan = getch();
            if (mode == 1) {
                if (scan == 72 && w->top > 1) --w->top;
                if (scan == 80 && w->top + w->rows < desk_rows - 1) ++w->top;
                if (scan == 75 && w->left > 1) --w->left;
                if (scan == 77 && w->left + w->cols < SCREEN_COLS - 1) ++w->left;
            } else if (mode == 2) {
                if (scan == 72 && w->rows > 3) --w->rows;
                if (scan == 80 && w->top + w->rows < desk_rows - 1 &&
                    w->rows < SCREEN_ROWS) ++w->rows;
                if (scan == 75 && w->cols > 10) --w->cols;
                if (scan == 77 && w->left + w->cols < SCREEN_COLS - 1) ++w->cols;
            } else if (mode == 5) {     /* Change Colors */
                w->colors = 1;
                if (scan == 75) w->fg = (unsigned char)((w->fg + 15) & 15);
                if (scan == 77) w->fg = (unsigned char)((w->fg + 1) & 15);
                if (scan == 72) w->bg = (unsigned char)((w->bg + 7) & 7);
                if (scan == 80) w->bg = (unsigned char)((w->bg + 1) & 7);
                if (w->fg == 7 && w->bg == 0)
                    w->colors = 0;
            } else if (mode == 3) {     /* the view over its 80x25 screen */
                if (!w->scrolled) {
                    w->scrolled = 1;
                    w->vtop = w->hoff = 0;
                }
                if (scan == 72 && w->vtop > 0) --w->vtop;
                if (scan == 80 && w->vtop + w->rows < SCREEN_ROWS) ++w->vtop;
                if (scan == 75 && w->hoff > 0) --w->hoff;
                if (scan == 77 && w->hoff + w->cols < SCREEN_COLS) ++w->hoff;
            } else if (scan == 72)
                dv_bar(-1);
            else if (scan == 80)
                dv_bar(1);
            if (mode != 0 || scan != 59)
                continue;
        }
        if (mode == 4 && key >= '1' && key <= '9') {
            place(w, key - '1');
            w->scrolled = 0;
            key = 13;
        }
        if (mode == 5 && key == 27) {   /* Esc:  the colours as they were */
            w->colors = saved.colors;
            w->fg = saved.fg;
            w->bg = saved.bg;
        }
        if (mode != 0) {
            if (key == 13 || key == 27) {
                mode = 0;
                menu = DV_MAIN;
                to_window(t);
            }
            continue;
        }
        if (key == 27) {                /* Esc:  back (the main menu:  to
                                         * the window) */
            if (menu == DV_MAIN && t != 0)
                to_window(t);
            menu = DV_MAIN;
            fresh = 1;
            continue;
        }
        if (key == 13 && dv_usable(dv_sel))
            act = dv_items[dv_sel].act;
        else if (menu == DV_REARRANGE && key >= '1' && key <= '9' && scan == 0)
            act = A_PLACE + key - '1';
        else
            act = dv_find(key, scan);
        if (act <= 0)
            continue;
        if (t == 0 && act != A_OPEN && act != A_SWITCH && act != A_QUIT &&
            act < A_PROGRAM && menu != DV_QUIT) {
            strcpy(status, "No window in front.");
            continue;
        }
        fresh = 1;
        if (act >= A_WINDOW) {
            to_window(act - A_WINDOW);
            menu = DV_MAIN;
        } else if (act >= A_PROGRAM) {
            menu = DV_MAIN;
            launch_task(&catalog->programs[act - A_PROGRAM], status);
        } else
            switch (act) {
            case A_OPEN:
                menu = DV_OPEN;
                break;
            case A_SWITCH:
                menu = DV_SWITCH;
                break;
            case A_CLOSE:
                menu = DV_CLOSE;
                break;
            case A_REARRANGE:
                menu = DV_REARRANGE;
                break;
            case A_QUIT:
                menu = DV_QUIT;
                break;
            case A_ZOOM:
                mvk_setfg(t);
                while (mvk_fg() != 0 && mvk_state(t) == MVK_READY)
                    mvk_yield();
                menu = DV_MAIN;
                break;
            case A_MOVE:
                mode = 1;
                break;
            case A_RESIZE:
                mode = 2;
                break;
            case A_SCROLL:
                mode = 3;
                break;
            case A_COLORS:
                saved = *w;
                if (!w->colors) {
                    w->fg = 7;
                    w->bg = 0;
                }
                mode = 5;
                break;
            case A_TUNE:
                menu = DV_TUNE;
                break;
            case A_VIDEO:
                menu = DV_VIDEO;
                break;
            case A_BACKGROUND:
                w->frozen = (unsigned char)!w->frozen;
                mvk_freeze(t, w->frozen);
                fresh = 0;
                break;
            case A_SHARE:
                w->exclusive = (unsigned char)!w->exclusive;
                mvk_share(t, !w->exclusive);
                fresh = 0;
                break;
            case A_FGTICKS:
            case A_BGTICKS:             /* 1-15 and around */
                if (act == A_FGTICKS)
                    tune_fg = tune_fg % 15 + 1;
                else
                    tune_bg = tune_bg % 15 + 1;
                mvk_tune(tune_fg, tune_bg);
                fresh = 0;
                break;
            case A_POSITION:
                mode = 4;
                break;
            case A_FREEZE:
                w->frozen = (unsigned char)!w->frozen;
                mvk_freeze(t, w->frozen);
                menu = DV_MAIN;
                to_window(t);
                break;
            case A_HIDE:
            case A_ASIDE:                   /* the next window in front; none:
                                             * the menu stays */
                win_hide(t, act == A_ASIDE);
                menu = DV_MAIN;
                if (front() != 0)
                    to_window(front());
                break;
            case A_YES:
                if (menu == DV_QUIT)
                    return 2;
                mvk_kill(t);
                sprintf(status, "%.40s is being closed.", task_title[t]);
                menu = DV_MAIN;
                break;
            case A_NO:
                menu = DV_MAIN;
                break;
            default:
                if (act >= A_ROWS && act < A_ROWS + 4) {
                    int rc = desk_set(mt_rows[act - A_ROWS]);

                    if (rc == 0)
                        video_rows = desk_rows;
                    else
                        sprintf(status, "MAXTEXT:  80x%u not set (%d).",
                                mt_rows[act - A_ROWS], rc);
                    menu = DV_MAIN;
                } else if (act >= A_PLACE && act < A_PLACE + 9) {
                    place(w, act - A_PLACE);
                    w->scrolled = 0;
                    menu = DV_MAIN;
                    to_window(t);
                }
                break;
            }
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
    mt_open();
    start_multitasking(status);
    initialise_video();

    for (;;) {
        if (mv_on && view_windows && tasks_open() != 0) {
            int rc;

            desk_set(video_rows);
            rc = windows_view(&catalog, status);
            if (desk_rows != SCREEN_ROWS) { /* the launcher:  25 rows */
                desk_set(SCREEN_ROWS);
                desk_rows = SCREEN_ROWS;
            }
            if (rc == 2)
                break;
            view_windows = 0;
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

