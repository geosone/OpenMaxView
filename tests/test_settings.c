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
    if (!settings.auto_tsr || !settings.confirm_exit ||
        !settings.reload_catalog || !settings.show_memory ||
        !settings.hotkey_launch || !settings.quick_help)
        fail("defaults are incorrect");

    write_text("build/test-settings.ini",
               "# test\nAUTO_TSR=no\nCONFIRM_EXIT=0\n"
               "RELOAD_CATALOG=yes\nSHOW_MEMORY=no\n"
               "HOTKEY_LAUNCH=yes\nQUICK_HELP=no\n");
    if (odq_settings_load("build/test-settings.ini", &settings, &line) !=
        ODQ_SETTINGS_OK)
        fail("valid settings rejected");
    if (settings.auto_tsr || settings.confirm_exit || settings.show_memory ||
        settings.quick_help || !settings.reload_catalog ||
        !settings.hotkey_launch)
        fail("valid settings parsed incorrectly");

    if (odq_settings_save("build/test-settings.ini", &settings) !=
        ODQ_SETTINGS_OK)
        fail("settings save failed");
    if (odq_settings_load("build/test-settings.ini", &loaded, &line) !=
        ODQ_SETTINGS_OK || memcmp(&settings, &loaded, sizeof(settings)) != 0)
        fail("settings did not round-trip");
    if (odq_settings_load("build/test-settings.BAK", &loaded, &line) !=
        ODQ_SETTINGS_OK || loaded.auto_tsr != 0 || loaded.quick_help != 0)
        fail("settings backup was not retained");

    write_text("build/test-settings-bad.ini",
               "AUTO_TSR=no\nUNKNOWN=yes\n");
    memset(&loaded, 0, sizeof(loaded));
    if (odq_settings_load("build/test-settings-bad.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 2)
        fail("unknown setting accepted");
    if (!loaded.auto_tsr || !loaded.confirm_exit || !loaded.quick_help)
        fail("partial invalid settings escaped instead of defaults");

    write_text("build/test-settings-bool.ini", "AUTO_TSR=maybe\n");
    if (odq_settings_load("build/test-settings-bool.ini", &loaded, &line) !=
        ODQ_SETTINGS_SYNTAX || line != 1)
        fail("invalid boolean accepted");

    puts("settings tests passed");
    return 0;
}
