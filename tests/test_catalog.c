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
    fclose(stream);

    if (odq_catalog_load("build/test.cfg", &catalog, &line) != ODQ_CATALOG_OK)
        fail("valid catalogue rejected");
    if (catalog.count != 2)
        fail("wrong entry count");
    if (catalog.programs[1].hotkey != 'X')
        fail("hotkey was not normalised");
    if (strcmp(catalog.programs[1].directory, "C:\\EXAMPLE") != 0)
        fail("directory parsed incorrectly");
    if (catalog.programs[0].min_kb != 128 || catalog.programs[0].max_kb != 640)
        fail("memory limits parsed incorrectly");

    stream = fopen("build/test.cfg", "wt");
    if (stream == NULL)
        fail("cannot rewrite fixture");
    fputs("B|Broken|RUN||700|640\n", stream);
    fclose(stream);
    if (odq_catalog_load("build/test.cfg", &catalog, &line) != ODQ_CATALOG_SYNTAX ||
        line != 1)
        fail("invalid memory range accepted");

    puts("catalog tests passed");
    return 0;
}

