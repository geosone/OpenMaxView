/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXVAUTO_AUTODETECT_H
#define MAXVAUTO_AUTODETECT_H

#include "catalog.h"

#define MVA_MAX_RULES     48
#define MVA_FILENAME_LEN  12

typedef struct mva_rule {
    char filename[MVA_FILENAME_LEN + 1];
    char title[ODQ_TITLE_LEN + 1];
    char command[ODQ_COMMAND_LEN + 1];
    unsigned min_kb;
    unsigned max_kb;
} mva_rule;

typedef struct mva_rules {
    mva_rule rules[MVA_MAX_RULES];
    unsigned count;
} mva_rules;

enum mva_result {
    MVA_OK = 0,
    MVA_IO = -1,
    MVA_SYNTAX = -2,
    MVA_FULL = -3,
    MVA_DUPLICATE = -4
};

int mva_rules_load(const char *path, mva_rules *rules, unsigned *error_line);
int mva_catalog_has_file(const odq_catalog *catalog, const char *filename);
int mva_catalog_add(odq_catalog *catalog, const mva_rule *rule,
                    const char *directory);

#endif
