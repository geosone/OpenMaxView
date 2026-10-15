/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "autodetect.h"

static void fail(const char *message)
{
    fprintf(stderr, "FAIL: %s\n", message);
    exit(1);
}

int main(void)
{
    FILE *stream;
    mva_rules rules;
    odq_catalog catalog;
    unsigned line = 0;

    stream = fopen("build/test-auto.dat", "wt");
    if (stream == NULL) fail("cannot create rule fixture");
    fputs("# detection rules\n", stream);
    fputs("EDIT.COM|Text editor|EDIT.COM|128|640\n", stream);
    fputs("QBASIC.EXE|BASIC|QBASIC.EXE /NOHI|256|640\n", stream);
    fclose(stream);
    if (mva_rules_load("build/test-auto.dat", &rules, &line) != MVA_OK ||
        rules.count != 2)
        fail("valid rules rejected");

    memset(&catalog, 0, sizeof(catalog));
    catalog.count = 1;
    catalog.programs[0].hotkey = 'T';
    strcpy(catalog.programs[0].title, "Existing");
    strcpy(catalog.programs[0].command, "C:\\DOS\\MEM.EXE /C");
    if (!mva_catalog_has_file(&catalog, "mem.exe"))
        fail("configured executable not recognised");
    if (mva_catalog_add(&catalog, &rules.rules[0], "C:\\DOS") != MVA_OK)
        fail("detected program not added");
    if (catalog.count != 2 || catalog.programs[1].hotkey != 'E' ||
        strcmp(catalog.programs[1].directory, "C:\\DOS") != 0)
        fail("added program fields are wrong");
    if (mva_catalog_add(&catalog, &rules.rules[0], "C:\\TOOLS") !=
        MVA_DUPLICATE)
        fail("duplicate executable was added");

    stream = fopen("build/test-auto.dat", "wt");
    if (stream == NULL) fail("cannot rewrite rule fixture");
    fputs("TOOL.EXE|Tool|TOOL.EXE|700|640\n", stream);
    fclose(stream);
    if (mva_rules_load("build/test-auto.dat", &rules, &line) != MVA_SYNTAX ||
        line != 1)
        fail("invalid memory range accepted");

    stream = fopen("build/test-auto.dat", "wt");
    if (stream == NULL) fail("cannot rewrite duplicate fixture");
    fputs("TOOL.EXE|Tool|TOOL.EXE|64|640\n", stream);
    fputs("tool.exe|Other|tool.exe|64|640\n", stream);
    fclose(stream);
    if (mva_rules_load("build/test-auto.dat", &rules, &line) !=
        MVA_DUPLICATE || line != 2)
        fail("duplicate rule accepted");

    puts("automatic detection tests passed");
    return 0;
}
