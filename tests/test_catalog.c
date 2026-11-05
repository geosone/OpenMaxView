/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "catalog.h"

static void fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    exit(1);
}

int main(void)
{
    odq_catalog catalog;
    unsigned line = 0;
    FILE *stream = fopen("build/test.cfg", "wt");

    if (stream == NULL)
        fail("cannot create fixture");
    fputs("# comment\n", stream);
    fputs("D | DOS shell | COMMAND.COM | | 128 | 640\n", stream);
    fputs("x|Example|EXAMPLE.EXE|C:\\EXAMPLE|64|256\n", stream);
    fputs("p|Profile|PROFILE.EXE||128|640|1|2|4|1000|7|2048|8|25|80|2|1|3|154|18|52|86|120\n",
          stream);
    fclose(stream);

    if (odq_catalog_load("build/test.cfg", &catalog, &line) != ODQ_CATALOG_OK)
        fail("valid catalogue rejected");
    if (catalog.count != 3)
        fail("wrong entry count");
    if (catalog.programs[1].hotkey != 'X')
        fail("hotkey was not normalised");
    if (strcmp(catalog.programs[1].directory, "C:\\EXAMPLE") != 0)
        fail("directory parsed incorrectly");
    if (catalog.programs[0].min_kb != 128 || catalog.programs[0].max_kb != 640)
        fail("memory limits parsed incorrectly");
    if (catalog.programs[2].profile.version != ODQ_PROFILE_VERSION ||
        catalog.programs[2].profile.source_version != 2 ||
        catalog.programs[2].profile.script_bytes != 1000 ||
        catalog.programs[2].profile.serial_ports != 3 ||
        catalog.programs[2].profile.protection != 154 ||
        catalog.programs[2].profile.flags4 != 120)
        fail("versioned process profile parsed incorrectly");

    if (odq_catalog_save("build/test-saved.cfg", &catalog) != ODQ_CATALOG_OK)
        fail("valid catalogue could not be saved");
    memset(&catalog, 0, sizeof(catalog));
    if (odq_catalog_load("build/test-saved.cfg", &catalog, &line) !=
        ODQ_CATALOG_OK || catalog.count != 3 ||
        strcmp(catalog.programs[1].title, "Example") != 0 ||
        catalog.programs[2].profile.max_ems_kb != 2048)
        fail("saved catalogue did not round-trip");
    strcpy(catalog.programs[1].title, "Changed");
    if (odq_catalog_save("build/test-saved.cfg", &catalog) != ODQ_CATALOG_OK)
        fail("catalogue replacement failed");
    if (odq_catalog_load("build/test-saved.BAK", &catalog, &line) !=
        ODQ_CATALOG_OK || strcmp(catalog.programs[1].title, "Example") != 0)
        fail("catalogue backup was not retained");

    stream = fopen("build/test.cfg", "wt");
    if (stream == NULL)
        fail("cannot rewrite fixture");
    fputs("B|Broken|RUN||700|640\n", stream);
    fclose(stream);
    if (odq_catalog_load("build/test.cfg", &catalog, &line) != ODQ_CATALOG_SYNTAX ||
        line != 1)
        fail("invalid memory range accepted");

    stream = fopen("build/test.cfg", "wt");
    if (stream == NULL)
        fail("cannot rewrite profile fixture");
    fputs("P|Bad profile|BAD.EXE||128|640|2|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0|0\n",
          stream);
    fclose(stream);
    if (odq_catalog_load("build/test.cfg", &catalog, &line) !=
            ODQ_CATALOG_SYNTAX || line != 1)
        fail("unsupported profile version accepted");

    memset(&catalog, 0, sizeof(catalog));
    catalog.count = 1;
    catalog.programs[0].hotkey = 'X';
    strcpy(catalog.programs[0].title, "Invalid|Title");
    strcpy(catalog.programs[0].command, "RUN.EXE");
    if (odq_catalog_save("build/test-invalid.cfg", &catalog) !=
        ODQ_CATALOG_SYNTAX)
        fail("unsafe catalogue field was saved");

    memset(&catalog, 0, sizeof(catalog));
    catalog.count = 2;
    catalog.programs[0].hotkey = 'D';
    strcpy(catalog.programs[0].title, "First");
    strcpy(catalog.programs[0].command, "ONE.EXE");
    catalog.programs[1] = catalog.programs[0];
    strcpy(catalog.programs[1].title, "Second");
    if (odq_catalog_save("build/test-duplicate.cfg", &catalog) !=
        ODQ_CATALOG_SYNTAX)
        fail("duplicate hotkey was saved");

    /* Can be swapped out, as DESQview 2.80 writes it in a DVP 2.x:  blank
     * flags4 bit 6, Y flags1 bit 0 (the shipped DVPs:  16Fh 01h, 18Bh C3h) */
    memset(&catalog.programs[0].profile, 0, sizeof(odq_process_profile));
    if (!odq_program_swappable(&catalog.programs[0]))
        fail("a program without a profile not swappable");
    catalog.programs[0].profile.version = ODQ_PROFILE_VERSION;
    catalog.programs[0].profile.source_version = 2;
    if (odq_program_swappable(&catalog.programs[0]))
        fail("Can be swapped out N swappable");
    catalog.programs[0].profile.flags4 = 0xcf;
    if (!odq_program_swappable(&catalog.programs[0]))
        fail("Can be swapped out blank not swappable");
    catalog.programs[0].profile.flags4 = 0x8f;
    catalog.programs[0].profile.flags1 = 0xe1;
    if (!odq_program_swappable(&catalog.programs[0]))
        fail("Can be swapped out Y not swappable");
    catalog.programs[0].profile.flags1 = 0;
    catalog.programs[0].profile.source_version = 1;
    if (!odq_program_swappable(&catalog.programs[0]))
        fail("a DVP 1.x profile not swappable");
    /* Share EGA when foreground/zoomed:  flags4 bit 0 (DESQview 2.80:  Y
     * 18Bh CFh, N CEh) */
    catalog.programs[0].profile.source_version = 2;
    catalog.programs[0].profile.flags4 = 0xce;
    if (odq_program_share_ega(&catalog.programs[0]))
        fail("Share EGA N sharing");
    catalog.programs[0].profile.flags4 = 0xcf;
    if (!odq_program_share_ega(&catalog.programs[0]))
        fail("Share EGA Y not sharing");
    catalog.programs[0].profile.version = 0;
    if (!odq_program_share_ega(&catalog.programs[0]))
        fail("a program without a profile not sharing EGA");
    /* Runs in background, Share CPU, Allow Close Window (DESQview 2.80,
     * shipped:  16Fh E1h, 184h 28h, 18Bh CFh; bg Y:  16Fh A1h, 184h 20h;
     * bg N:  184h 20h; Share CPU N:  18Bh CDh; Allow Close N:  184h 38h) */
    if (!odq_program_background(&catalog.programs[0]) ||
        !odq_program_share_cpu(&catalog.programs[0]) ||
        !odq_program_closable(&catalog.programs[0]))
        fail("a program without a profile restricted");
    catalog.programs[0].profile.version = ODQ_PROFILE_VERSION;
    catalog.programs[0].profile.flags1 = 0xe1;
    catalog.programs[0].profile.flags3 = 0x28;
    catalog.programs[0].profile.flags4 = 0xcf;
    if (!odq_program_background(&catalog.programs[0]) ||
        !odq_program_share_cpu(&catalog.programs[0]) ||
        !odq_program_closable(&catalog.programs[0]))
        fail("the shipped settings restricted");
    catalog.programs[0].profile.flags3 = 0x20;
    if (odq_program_background(&catalog.programs[0]))
        fail("Runs in background N runs");
    catalog.programs[0].profile.flags1 = 0xa1;
    if (!odq_program_background(&catalog.programs[0]))
        fail("Runs in background Y held");
    catalog.programs[0].profile.flags4 = 0xcd;
    if (odq_program_share_cpu(&catalog.programs[0]))
        fail("Share CPU N sharing");
    catalog.programs[0].profile.flags3 = 0x38;
    if (odq_program_closable(&catalog.programs[0]))
        fail("Allow Close Window N closable");

    puts("catalog tests passed");
    return 0;
}

