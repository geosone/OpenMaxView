/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "settings.h"

static void fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    exit(1);
}

static void write_text(const char *path, const char *text)
{
    FILE *stream = fopen(path, "wt");
    if (stream == NULL)
        fail("cannot create settings fixture");
    fputs(text, stream);
    fclose(stream);
}

int main(void)
{
    odq_settings settings, loaded;
    unsigned line = 0;

    odq_settings_defaults(&settings);
    if (!settings.auto_tsr || !settings.auto_ansi || !settings.confirm_exit ||
        !settings.reload_catalog || !settings.show_memory ||
        !settings.hotkey_launch || !settings.quick_help ||
        settings.modem_port != 1 || strcmp(settings.dial, "ATDT") != 0 ||
        strcmp(settings.hangup, "ATZ") != 0 || settings.access[0][0] != '\0')
        fail("defaults are incorrect");
    if (settings.fg_ticks != 6 || settings.bg_ticks != 2 ||
        !settings.swapping || settings.swap_dir[0] != '\0' ||
        !settings.learn || settings.dial_baud != 0 ||
        settings.window[2][0] != 5 || settings.window[2][1] != 16 ||
        settings.window[2][2] != 15 || settings.window[2][3] != 48 ||
        settings.window[8][0] != 14 || settings.window[8][3] != 37)
        fail("Setup defaults are incorrect");

    write_text("build/test-settings.ini",
               "# test\nAUTO_TSR=no\nAUTO_ANSI=0\nCONFIRM_EXIT=0\n"
               "RELOAD_CATALOG=yes\nSHOW_MEMORY=no\n"
               "HOTKEY_LAUNCH=yes\nQUICK_HELP=no\n"
               "MODEM_PORT=2\nDIAL=ATDP\nACCESS1=9,\nACCESS3=0w\n");
    if (odq_settings_load("build/test-settings.ini", &settings, &line) !=
        ODQ_SETTINGS_OK)
        fail("valid settings rejected");
    if (settings.auto_tsr || settings.auto_ansi || settings.confirm_exit ||
        settings.show_memory ||
        settings.quick_help || !settings.reload_catalog ||
        !settings.hotkey_launch || settings.modem_port != 2 ||
        strcmp(settings.dial, "ATDP") != 0 ||
        strcmp(settings.hangup, "ATZ") != 0 ||
        strcmp(settings.access[0], "9,") != 0 ||
        settings.access[1][0] != '\0' || strcmp(settings.access[2], "0w") != 0)
        fail("valid settings parsed incorrectly");

    write_text("build/test-settings-setup.ini",
               "FOREGROUND=9\nBACKGROUND=1\nSWAPPING=no\n"
               "SWAP_DIR=D:\\SWAP\nLEARN=no\nDIAL_BAUD=4\n"
               "window4=3, 7, 12, 40\n");
    if (odq_settings_load("build/test-settings-setup.ini", &loaded, &line) !=
        ODQ_SETTINGS_OK || loaded.fg_ticks != 9 || loaded.bg_ticks != 1 ||
        loaded.swapping || strcmp(loaded.swap_dir, "D:\\SWAP") != 0 ||
        loaded.learn || loaded.dial_baud != 4 || loaded.window[3][0] != 3 ||
        loaded.window[3][1] != 7 || loaded.window[3][2] != 12 ||
        loaded.window[3][3] != 40 || loaded.window[4][1] != 42)
        fail("Setup settings parsed incorrectly");
    write_text("build/test-settings-setup.ini", "FOREGROUND=16\n");
    if (odq_settings_load("build/test-settings-setup.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX)
        fail("16 foreground ticks accepted");
    write_text("build/test-settings-setup.ini", "WINDOW1=1,1,10\n");
    if (odq_settings_load("build/test-settings-setup.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX)
        fail("a window position of three numbers accepted");
    write_text("build/test-settings-setup.ini", "WINDOW0=1,1,10,10\n");
    if (odq_settings_load("build/test-settings-setup.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX)
        fail("window 0 accepted");
    settings.fg_ticks = 3;
    settings.swapping = 0;
    strcpy(settings.swap_dir, "C:\\TMP");
    settings.window[0][3] = 60;

    if (odq_settings_save("build/test-settings.ini", &settings) !=
        ODQ_SETTINGS_OK)
        fail("settings save failed");
    if (odq_settings_load("build/test-settings.ini", &loaded, &line) !=
        ODQ_SETTINGS_OK || memcmp(&settings, &loaded, sizeof(settings)) != 0)
        fail("settings did not round-trip");
    if (odq_settings_load("build/test-settings.BAK", &loaded, &line) !=
        ODQ_SETTINGS_OK || loaded.auto_tsr != 0 || loaded.auto_ansi != 0 ||
        loaded.quick_help != 0)
        fail("settings backup was not retained");

    write_text("build/test-settings-bad.ini",
               "AUTO_TSR=no\nUNKNOWN=yes\n");
    memset(&loaded, 0, sizeof(loaded));
    if (odq_settings_load("build/test-settings-bad.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 2)
        fail("unknown setting accepted");
    if (!loaded.auto_tsr || !loaded.auto_ansi || !loaded.confirm_exit ||
        !loaded.quick_help)
        fail("partial invalid settings escaped instead of defaults");

    write_text("build/test-settings-bool.ini", "AUTO_TSR=maybe\n");
    if (odq_settings_load("build/test-settings-bool.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 1)
        fail("invalid boolean accepted");

    write_text("build/test-settings-port.ini", "MODEM_PORT=5\n");
    if (odq_settings_load("build/test-settings-port.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 1)
        fail("invalid modem port accepted");
    write_text("build/test-settings-long.ini",
               "DIAL=ATDT0123456789ABCDEF\n");
    if (odq_settings_load("build/test-settings-long.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 1)
        fail("too long dial command accepted");

    puts("settings tests passed");
    return 0;
}
