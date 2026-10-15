/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MAXBACKEND_H
#define MAXBACKEND_H

#define ODQ_MAX_ABI_1_0          0x0100
#define ODQ_MAX_CAP_STATUS       0x0001
#define ODQ_QPI_VERSION_7_3      0x0703

typedef struct odq_max_backend_info {
    unsigned abi_version;
    unsigned capabilities;
    unsigned current_context;
    unsigned active_contexts;
    unsigned context_limit;
    unsigned qpi_version;
    unsigned qpi_context;
} odq_max_backend_info;

/* Returns nonzero only after discovery, signature and status validation. */
int odq_max_backend_query(odq_max_backend_info *information);

#endif
