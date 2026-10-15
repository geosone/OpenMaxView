/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef ODQ_API_H
#define ODQ_API_H

/* Documented DESQview-compatible calls. */
#define ODQ_DV_VERSION          0x0280
#define ODQ_DVC_PAUSE           0x1000
#define ODQ_DVC_GET_MEMORY_TV   0x1001
#define ODQ_DVC_PUT_MEMORY_TV   0x1002
#define ODQ_DVC_IS_OBJECT       0x1016
#define ODQ_DVC_BEGIN_CRITICAL  0x101b
#define ODQ_DVC_END_CRITICAL    0x101c
#define ODQ_DVC_GET_VERSION     0x1022
#define ODQ_DVC_COMMON_STATUS   0xde04
#define ODQ_DVC_APP_NUMBER      0xde07
#define ODQ_DVC_API_LEVEL       0xde0b
#define ODQ_DVC_GET_MEMORY      0xde0c
#define ODQ_DVC_PUT_MEMORY      0xde0d
#define ODQ_DVC_PUSH_KEY        0xde10
#define ODQ_DVC_JUSTIFY         0xde11
#define ODQ_DVC_C_STYLE         0xde12
#define ODQ_DVC_GET_CRITICAL    0xde13
#define ODQ_DVC_OBJECT_TYPE     0xde14
#define ODQ_DVC_SET_ERROR       0xde15
#define ODQ_DVC_GET_ERROR       0xde16
#define ODQ_DVC_GET_COMMON      0xde19
#define ODQ_DVC_PUT_COMMON      0xde1a
#define ODQ_DVC_ENTER_CRITICAL  0xde1c
#define ODQ_DVC_SCREEN_INFO     0xde1e
#define ODQ_DVC_DOS_USER        0xde1f
#define ODQ_DVC_GET_FOREGROUND  0xde26
#define ODQ_DVC_OBJECT_NEXT     0xde2b
#define ODQ_DVC_WINDOW_INFO     0xde2c
#define ODQ_DVC_VIDEO_NOTIFY    0xde2f
#define ODQ_DVC_DVX_VERSION     0xde30

/* Open MaxView-private INT 2Fh service.  "OD" is returned in BX. */
#define ODQ_MUX_STATUS          0xd700
#define ODQ_MUX_INFO            0xd701
#define ODQ_MUX_RESET           0xd702
#define ODQ_MUX_TASK_INFO       0xd703
#define ODQ_MUX_CAPS2           0xd704
#define ODQ_MUX_SIGNATURE       0x4f44
#define ODQ_MUX_VERSION         0x000a

#define ODQ_CAP_PRESENCE        0x0001
#define ODQ_CAP_PAUSE           0x0002
#define ODQ_CAP_CRITICAL        0x0004
#define ODQ_CAP_VIDEO_BUFFER    0x0008
#define ODQ_CAP_PUSH_KEY        0x0010
#define ODQ_CAP_APP_NUMBER      0x0020
#define ODQ_CAP_API_LEVEL       0x0040
#define ODQ_CAP_TASK_MODES      0x0080
#define ODQ_CAP_ERROR_MODE      0x0100
#define ODQ_CAP_ENTER_CRITICAL  0x0200
#define ODQ_CAP_SCREEN_INFO     0x0400
#define ODQ_CAP_VIDEO_NOTIFY    0x0800
#define ODQ_CAP_DVX_VERSION     0x1000
#define ODQ_CAP_SYSTEM_MEMORY   0x2000
#define ODQ_CAP_COMMON_MEMORY   0x4000
#define ODQ_CAP_MEMORY_STATUS   0x8000
#define ODQ_CAPABILITIES        0xffff

#define ODQ_CAP2_IS_OBJECT      0x0001
#define ODQ_CAP2_OBJECT_TYPE    0x0002
#define ODQ_CAP2_FOREGROUND     0x0004
#define ODQ_CAP2_GET_VERSION    0x0008
#define ODQ_CAP2_DOS_USER       0x0010
#define ODQ_CAP2_OBJECT_NEXT    0x0020
#define ODQ_CAP2_WINDOW_INFO    0x0040
#define ODQ_CAPABILITIES2       0x007f

#define ODQ_OBJECT_WINDOW_TASK  0x08
#define ODQ_WININFO_VERSION     0x0100
#define ODQ_WININFO_SIZE        11
#define ODQ_WININFO_TASK        0x01
#define ODQ_WININFO_PROCESS     0x0001
#define ODQ_WININFO_FOREGROUND_ONLY 0x01

#define ODQ_MEMORY_SLOT_SIZE    256
#define ODQ_SYSTEM_SLOT_COUNT   8
#define ODQ_COMMON_SLOT_COUNT   4

#define ODQ_TASK_JUSTIFY        0x0001
#define ODQ_TASK_C_STYLE        0x0002

#endif

