/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef MEMQUERY_H
#define MEMQUERY_H

int odq_xms_query(unsigned *total_free_kb, unsigned *largest_free_kb);

#ifdef __WATCOMC__
#pragma aux odq_xms_query parm [ax] [dx] value [ax] modify [bx cx dx]
#endif

#endif
