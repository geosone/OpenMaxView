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
    unsigned long qpi_context;
} odq_max_backend_info;

typedef struct odq_max_qpi_context {
    unsigned long page_table;
} odq_max_qpi_context;

typedef struct odq_max_qpi_page {
    unsigned long frame;
} odq_max_qpi_page;

typedef struct odq_max_qpi_mapping {
    unsigned linear_page;
    unsigned original_frame;
    unsigned mapped_frame;
    unsigned installed;
} odq_max_qpi_mapping;

/* Returns nonzero only after discovery, signature and status validation. */
int odq_max_backend_query(odq_max_backend_info *information);

/* Require a successful root query. Clone allocation does not activate it. */
int odq_max_context_clone(odq_max_qpi_context *context);
int odq_max_context_release(odq_max_qpi_context *context);
int odq_max_context_activate(const odq_max_qpi_context *context);
int odq_max_context_restore(void);

/* One private data page may be owned alongside the page-table clone. */
int odq_max_page_allocate(odq_max_qpi_page *page);
int odq_max_page_release(odq_max_qpi_page *page);

/* Mapping calls operate only in the active clone owned by this wrapper. */
int odq_max_mapping_query(odq_max_qpi_mapping *mapping);
int odq_max_mapping_install(odq_max_qpi_mapping *mapping);
int odq_max_mapping_restore(odq_max_qpi_mapping *mapping);

#endif
