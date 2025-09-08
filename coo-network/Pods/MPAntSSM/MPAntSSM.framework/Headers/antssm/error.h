/**
 * \file error.h
 *
 * \brief Error to string translation
 *
 *  Copyright (C) 2006-2015, ARM Limited, All Rights Reserved
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Licensed under the Apache License, Version 2.0 (the "License"); you may
 *  not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 *  This file is part of mbed TLS (https://tls.mbed.org)
 */
#ifndef ANTSSM_ERROR_H
#define ANTSSM_ERROR_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>

/**
 * Error code layout.
 *
 * Currently we try to keep all error codes within the negative space of 16
 * bits signed integers to support all platforms (-0x0001 - -0x7FFF). In
 * addition we'd like to give two layers of information on the error if
 * possible.
 *
 * For that purpose the error codes are segmented in the following manner:
 *
 * 16 bit error code bit-segmentation
 *
 * 1 bit  - Unused (sign bit)
 * 3 bits - High level module ID
 * 5 bits - Module-dependent error code
 * 7 bits - Low level module errors
 *
 * For historical reasons, low-level error codes are divided in even and odd,
 * even codes were assigned first, and -1 is reserved for other errors.
 *
 * Low-level module errors (0x0002-0x007E, 0x0003-0x007F)
 *
 * Module   Nr  Codes assigned
 * MPI       7  0x0002-0x0010
 * GCM       2  0x0012-0x0014
 * BLOWFISH  2  0x0016-0x0018
 * THREADING 3  0x001A-0x001E
 * AES       2  0x0020-0x0022
 * CAMELLIA  2  0x0024-0x0026
 * XTEA      1  0x0028-0x0028
 * BASE64    2  0x002A-0x002C
 * OID       1  0x002E-0x002E   0x000B-0x000B
 * PADLOCK   1  0x0030-0x0030
 * DES       1  0x0032-0x0032
 * CTR_DBRG  4  0x0034-0x003A
 * ENTROPY   3  0x003C-0x0040   0x003D-0x003F
 * NET      11  0x0042-0x0052   0x0043-0x0045
 * ASN1      7  0x0060-0x006C
 * PBKDF2    1  0x007C-0x007C
 * HMAC_DRBG 4  0x0003-0x0009
 * CCM       2                  0x000D-0x000F
 * SM3          0x0011-0x0013
 *
 * High-level module nr (3 bits - 0x0...-0x7...)
 * Name      ID  Nr of Errors
 * PEM       1   9
 * PKCS#12   1   4 (Started from top)
 * X509      2   20
 * PKCS5     2   4 (Started from top)
 * DHM       3   9
 * PK        3   14 (Started from top)
 * RSA       4   9
 * ECP       4   8 (Started from top)
 * MD        5   4
 * CIPHER    6   6
 * SSL       6   17 (Started from top)
 * SSL       7   31
 * SM2       8
 *
 * Module dependent error code (5 bits 0x.00.-0x.F8.)
 */

#define mpaas_AK_OK 0
#define mpaas_AK_ERR -1

/**
 * \brief 错误码形式为 -0XAABBCCCC
 * AA 表明接口标准
 * BB 表明模块编码
 * CCCC 表明模块内错误码
 */
enum {
    ANTSSM_ERROR_DEFINE = -0x1F000000,

    ANTSSM_ERROR_FUNCTION_NOT_SUPPORTED = -0x1F010001,
    ANTSSM_ERROR_FEATURE_NOT_SUPPORTED = -0x1F010002,
    ANTSSM_ERROR_MD_ALGORITHM_NOT_SUPPORTED = -0x1F010003,
    ANTSSM_ERROR_PK_ALGORITHM_NOT_SUPPORTED = -0x1F010004,

    ANTSSM_ERROR_CORRUPTION_DETECTED = -0x1F020001,
    ANTSSM_ERROR_FUNCTION_TURN_OFF = -0x1F020003,
    ANTSSM_ERROR_ARGUMENTS_NULL = -0x1F020004,
    ANTSSM_ERROR_ARGUMENTS_BAD = -0x1F020005,
    ANTSSM_ERROR_DATA_LEN_RANGE = -0x1F020006,
    ANTSSM_ERROR_FILE_OPEN_FAILED = -0x1F020007,
    ANTSSM_ERROR_FILE_READ_FAILED = -0x1F020008,
    ANTSSM_ERROR_FILE_WRITE_FAILED = -0x1F020009,
    ANTSSM_ERROR_FILE_CLOSE_FAILED = -0x1F02000A,
    ANTSSM_ERROR_FILE_REMOVE_FAILED = -0x1F02000B,
    ANTSSM_ERROR_ATTR_LEN_RANGE = -0x1F02000C,
    ANTSSM_ERROR_GEN_RN_FAILED = -0x1F02000D,
    ANTSSM_ERROR_BUFFER_TOO_SMALL = -0x1F02000E,
    ANTSSM_ERROR_CALLOC_FAILED = -0x1F02000F,
    ANTSSM_ERROR_KEY_CHECK_FAILED = -0x1F020010,
    ANTSSM_ERROR_STATUS_BAD = -0x1F020011,
    ANTSSM_ERROR_VERSION_NO_FEATURE_AVAIABLE = -0x1F020012,
    ANTSSM_ERROR_VERSION_NOT_SUPPORTED_FEATURE = -0x1F020013,
    ANTSSM_ERROR_WHITE_BOX_PARSE_FAILED = -0x1F020014,
    ANTSSM_ERROR_ALGORITHM_CHECK_FAILED = 0x1F020015,
    ANTSSM_ERROR_MK_DIR_FAILED = 0x1F020016,
};

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief Translate a mbed TLS error code into a string representation,
 *        Result is truncated if necessary and always includes a terminating
 *        null byte.
 *
 * \param errnum    error code
 * \param buffer    buffer to place representation in
 * \param buflen    length of the buffer
 */
void mpaas_antssm_strerror(int errnum, char *buffer, size_t buflen);

#ifdef __cplusplus
}
#endif

#endif /* error.h */
