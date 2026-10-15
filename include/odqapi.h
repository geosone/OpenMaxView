/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef ODQ_API_H
#define ODQ_API_H

/* Documented DESQview-compatible calls. */
#define ODQ_DV_VERSION          0x0280
#define ODQ_DVC_PAUSE           0x1000
#define ODQ_DVC_BEGIN_CRITICAL  0x101b
#define ODQ_DVC_END_CRITICAL    0x101c

/* Open MaxView-private INT 2Fh service.  "OD" is returned in BX. */
#define ODQ_MUX_STATUS          0xd700
#define ODQ_MUX_SIGNATURE       0x4f44
#define ODQ_MUX_VERSION         0x0001

#endif

