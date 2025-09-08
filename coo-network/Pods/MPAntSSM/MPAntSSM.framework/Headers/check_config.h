/**
 * \file check_config.h
 *
 * \brief Consistency checks for configuration options
 */
/*
 *  Copyright (C) 2006-2018, ARM Limited, All Rights Reserved
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

/*
 * It is recommended to include this file from your config.h
 * in order to catch dependency issues early.
 */

#ifndef ANTSSM_CHECK_CONFIG_H
#define ANTSSM_CHECK_CONFIG_H

/*
 * We assume CHAR_BIT is 8 in many places. In practice, this is true on our
 * target platforms, so not an issue, but let's just be extra sure.
 */
#include <limits.h>
#if CHAR_BIT != 8
#error "antssm requires a platform with 8-bit chars"
#endif

#if defined(_WIN32)
#if !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_C is required on Windows"
#endif

/* Fix the config here. Not convenient to put an #ifdef _WIN32 in config.h as
 * it would confuse config.pl. */
#if !defined(ANTSSM_PLATFORM_SNPRINTF_ALT) && \
    !defined(ANTSSM_PLATFORM_SNPRINTF_MACRO)
#define ANTSSM_PLATFORM_SNPRINTF_ALT
#endif

#if !defined(ANTSSM_PLATFORM_VSNPRINTF_ALT) && \
    !defined(ANTSSM_PLATFORM_VSNPRINTF_MACRO)
#define ANTSSM_PLATFORM_VSNPRINTF_ALT
#endif
#endif /* _WIN32 */

#if defined(TARGET_LIKE_MBED) && defined(ANTSSM_TIMING_C)
#error "The TIMING module is not available for mbed OS - please use the timing functions provided by Mbed OS"
#endif

#if defined(ANTSSM_DEPRECATED_WARNING) && \
    !defined(__GNUC__) && !defined(__clang__)
#error "ANTSSM_DEPRECATED_WARNING only works with GCC and Clang"
#endif

#if defined(ANTSSM_HAVE_TIME_DATE) && !defined(ANTSSM_HAVE_TIME)
#error "ANTSSM_HAVE_TIME_DATE without ANTSSM_HAVE_TIME does not make sense"
#endif

#if defined(ANTSSM_AESNI_C) && !defined(ANTSSM_HAVE_ASM)
#error "ANTSSM_AESNI_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_CTR_DRBG_C) && !defined(ANTSSM_AES_C)
#error "ANTSSM_CTR_DRBG_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_DHM_C) && !defined(ANTSSM_MPI_C)
#error "ANTSSM_DHM_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_CMAC_C) && \
    !defined(ANTSSM_AES_C) && !defined(ANTSSM_DES_C)
#error "ANTSSM_CMAC_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_NIST_KW_C) && \
    (!defined(ANTSSM_AES_C) || !defined(ANTSSM_CIPHER_C))
#error "ANTSSM_NIST_KW_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECDH_C) && !defined(ANTSSM_ECP_C)
#error "ANTSSM_ECDH_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECDSA_C) && \
    (!defined(ANTSSM_ECP_C))
#error "ANTSSM_ECDSA_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECJPAKE_C) && \
    (!defined(ANTSSM_ECP_C) || !defined(ANTSSM_MD_C))
#error "ANTSSM_ECJPAKE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_RESTARTABLE) && \
    (defined(ANTSSM_USE_PSA_CRYPTO) || \
      defined(ANTSSM_ECDH_COMPUTE_SHARED_ALT) || \
      defined(ANTSSM_ECDH_GEN_PUBLIC_ALT) || \
      defined(ANTSSM_ECDSA_SIGN_ALT) || \
      defined(ANTSSM_ECDSA_VERIFY_ALT) || \
      defined(ANTSSM_ECDSA_GENKEY_ALT) || \
      defined(ANTSSM_ECP_INTERNAL_ALT) || \
      defined(ANTSSM_ECP_ALT))
#error "ANTSSM_ECP_RESTARTABLE defined, but it cannot coexist with an alternative or PSA-based ECP implementation"
#endif

#if defined(ANTSSM_ECP_RESTARTABLE) && \
    !defined(ANTSSM_ECDH_LEGACY_CONTEXT)
#error "ANTSSM_ECP_RESTARTABLE defined, but not ANTSSM_ECDH_LEGACY_CONTEXT"
#endif

#if defined(ANTSSM_ECDH_VARIANT_EVEREST_ENABLED) && \
    defined(ANTSSM_ECDH_LEGACY_CONTEXT)
#error "ANTSSM_ECDH_VARIANT_EVEREST_ENABLED defined, but ANTSSM_ECDH_LEGACY_CONTEXT not disabled"
#endif

#if defined(ANTSSM_ECDSA_DETERMINISTIC) && !defined(ANTSSM_HMAC_DRBG_C)
#error "ANTSSM_ECDSA_DETERMINISTIC defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_C) && (!defined(ANTSSM_MPI_C) || (\
    !defined(ANTSSM_ECP_DP_SECP192R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP224R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP256R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP384R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP521R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_BP256R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_BP384R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_BP512R1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP192K1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP224K1_ENABLED) && \
    !defined(ANTSSM_ECP_DP_SECP256K1_ENABLED)))
#error "ANTSSM_ECP_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PK_PARSE_C) && !defined(ANTSSM_ASN1_PARSE_C)
#error "ANTSSM_PK_PARSE_C defined, but not all prerequesites"
#endif

#if defined(ANTSSM_ENTROPY_C) && (!defined(ANTSSM_SHA512_C) && \
                                    !defined(ANTSSM_SHA256_C))
#error "ANTSSM_ENTROPY_C defined, but not all prerequisites"
#endif
#if defined(ANTSSM_ENTROPY_C) && defined(ANTSSM_SHA512_C) && \
    defined(ANTSSM_CTR_DRBG_ENTROPY_LEN) && (ANTSSM_CTR_DRBG_ENTROPY_LEN > 64)
#error "ANTSSM_CTR_DRBG_ENTROPY_LEN value too high"
#endif
#if defined(ANTSSM_ENTROPY_C) && \
    (!defined(ANTSSM_SHA512_C) || defined(ANTSSM_ENTROPY_FORCE_SHA256)) \
 && defined(ANTSSM_CTR_DRBG_ENTROPY_LEN) && (ANTSSM_CTR_DRBG_ENTROPY_LEN > 32)
#error "ANTSSM_CTR_DRBG_ENTROPY_LEN value too high"
#endif
#if defined(ANTSSM_ENTROPY_C) && \
    defined(ANTSSM_ENTROPY_FORCE_SHA256) && !defined(ANTSSM_SHA256_C)
#error "ANTSSM_ENTROPY_FORCE_SHA256 defined, but not all prerequisites"
#endif

#if defined(ANTSSM_TEST_NULL_ENTROPY) && \
    (!defined(ANTSSM_ENTROPY_C) || !defined(ANTSSM_NO_DEFAULT_ENTROPY_SOURCES))
#error "ANTSSM_TEST_NULL_ENTROPY defined, but not all prerequisites"
#endif
#if defined(ANTSSM_TEST_NULL_ENTROPY) && \
     (defined(ANTSSM_ENTROPY_NV_SEED) || defined(ANTSSM_ENTROPY_HARDWARE_ALT) || \
    defined(ANTSSM_HAVEGE_C))
#error "ANTSSM_TEST_NULL_ENTROPY defined, but entropy sources too"
#endif

#if defined(ANTSSM_GCM_C) && (\
        !defined(ANTSSM_AES_C) && !defined(ANTSSM_CAMELLIA_C) && !defined(ANTSSM_ARIA_C))
#error "ANTSSM_GCM_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_RANDOMIZE_JAC_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_RANDOMIZE_JAC_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_ADD_MIXED_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_ADD_MIXED_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_DOUBLE_JAC_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_DOUBLE_JAC_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_NORMALIZE_JAC_MANY_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_NORMALIZE_JAC_MANY_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_NORMALIZE_JAC_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_NORMALIZE_JAC_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_DOUBLE_ADD_MXZ_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_DOUBLE_ADD_MXZ_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_RANDOMIZE_MXZ_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_RANDOMIZE_MXZ_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ECP_NORMALIZE_MXZ_ALT) && !defined(ANTSSM_ECP_INTERNAL_ALT)
#error "ANTSSM_ECP_NORMALIZE_MXZ_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_HAVEGE_C) && !defined(ANTSSM_TIMING_C)
#error "ANTSSM_HAVEGE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_HKDF_C) && !defined(ANTSSM_MD_C)
#error "ANTSSM_HKDF_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_HMAC_DRBG_C) && !defined(ANTSSM_MD_C)
#error "ANTSSM_HMAC_DRBG_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_MEMORY_BUFFER_ALLOC_C) && \
    (!defined(ANTSSM_PLATFORM_C) || !defined(ANTSSM_PLATFORM_MEMORY))
#error "ANTSSM_MEMORY_BUFFER_ALLOC_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PADLOCK_C) && !defined(ANTSSM_HAVE_ASM)
#error "ANTSSM_PADLOCK_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PK_C) && \
    (!defined(ANTSSM_RSA_C) && !defined(ANTSSM_ECP_C))
#error "ANTSSM_PK_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PK_PARSE_C) && !defined(ANTSSM_PK_C)
#error "ANTSSM_PK_PARSE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PK_WRITE_C) && !defined(ANTSSM_PK_C)
#error "ANTSSM_PK_WRITE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_EXIT_ALT) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_EXIT_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_EXIT_MACRO) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_EXIT_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_EXIT_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_EXIT) || \
        defined(ANTSSM_PLATFORM_EXIT_ALT))
#error "ANTSSM_PLATFORM_EXIT_MACRO and ANTSSM_PLATFORM_STD_EXIT/ANTSSM_PLATFORM_EXIT_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_TIME_ALT) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_TIME_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_TIME_MACRO) && \
    (!defined(ANTSSM_PLATFORM_C) || \
        !defined(ANTSSM_HAVE_TIME))
#error "ANTSSM_PLATFORM_TIME_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_TIME_TYPE_MACRO) && \
    (!defined(ANTSSM_PLATFORM_C) || \
        !defined(ANTSSM_HAVE_TIME))
#error "ANTSSM_PLATFORM_TIME_TYPE_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_TIME_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_TIME) || \
        defined(ANTSSM_PLATFORM_TIME_ALT))
#error "ANTSSM_PLATFORM_TIME_MACRO and ANTSSM_PLATFORM_STD_TIME/ANTSSM_PLATFORM_TIME_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_TIME_TYPE_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_TIME) || \
        defined(ANTSSM_PLATFORM_TIME_ALT))
#error "ANTSSM_PLATFORM_TIME_TYPE_MACRO and ANTSSM_PLATFORM_STD_TIME/ANTSSM_PLATFORM_TIME_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_FPRINTF_ALT) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_FPRINTF_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_FPRINTF_MACRO) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_FPRINTF_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_FPRINTF_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_FPRINTF) || \
        defined(ANTSSM_PLATFORM_FPRINTF_ALT))
#error "ANTSSM_PLATFORM_FPRINTF_MACRO and ANTSSM_PLATFORM_STD_FPRINTF/ANTSSM_PLATFORM_FPRINTF_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_FREE_MACRO) && \
    (!defined(ANTSSM_PLATFORM_C) || !defined(ANTSSM_PLATFORM_MEMORY))
#error "ANTSSM_PLATFORM_FREE_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_FREE_MACRO) && \
    defined(ANTSSM_PLATFORM_STD_FREE)
#error "ANTSSM_PLATFORM_FREE_MACRO and ANTSSM_PLATFORM_STD_FREE cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_FREE_MACRO) && !defined(ANTSSM_PLATFORM_CALLOC_MACRO)
#error "ANTSSM_PLATFORM_CALLOC_MACRO must be defined if ANTSSM_PLATFORM_FREE_MACRO is"
#endif

#if defined(ANTSSM_PLATFORM_CALLOC_MACRO) && \
    (!defined(ANTSSM_PLATFORM_C) || !defined(ANTSSM_PLATFORM_MEMORY))
#error "ANTSSM_PLATFORM_CALLOC_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_CALLOC_MACRO) && \
    defined(ANTSSM_PLATFORM_STD_CALLOC)
#error "ANTSSM_PLATFORM_CALLOC_MACRO and ANTSSM_PLATFORM_STD_CALLOC cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_CALLOC_MACRO) && !defined(ANTSSM_PLATFORM_FREE_MACRO)
#error "ANTSSM_PLATFORM_FREE_MACRO must be defined if ANTSSM_PLATFORM_CALLOC_MACRO is"
#endif

#if defined(ANTSSM_PLATFORM_MEMORY) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_MEMORY defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_PRINTF_ALT) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_PRINTF_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_PRINTF_MACRO) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_PRINTF_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_PRINTF_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_PRINTF) || \
        defined(ANTSSM_PLATFORM_PRINTF_ALT))
#error "ANTSSM_PLATFORM_PRINTF_MACRO and ANTSSM_PLATFORM_STD_PRINTF/ANTSSM_PLATFORM_PRINTF_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_SNPRINTF_ALT) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_SNPRINTF_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_SNPRINTF_MACRO) && !defined(ANTSSM_PLATFORM_C)
#error "ANTSSM_PLATFORM_SNPRINTF_MACRO defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_SNPRINTF_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_SNPRINTF) || \
        defined(ANTSSM_PLATFORM_SNPRINTF_ALT))
#error "ANTSSM_PLATFORM_SNPRINTF_MACRO and ANTSSM_PLATFORM_STD_SNPRINTF/ANTSSM_PLATFORM_SNPRINTF_ALT cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_STD_MEM_HDR) && \
    !defined(ANTSSM_PLATFORM_NO_STD_FUNCTIONS)
#error "ANTSSM_PLATFORM_STD_MEM_HDR defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_CALLOC) && !defined(ANTSSM_PLATFORM_MEMORY)
#error "ANTSSM_PLATFORM_STD_CALLOC defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_CALLOC) && !defined(ANTSSM_PLATFORM_MEMORY)
#error "ANTSSM_PLATFORM_STD_CALLOC defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_FREE) && !defined(ANTSSM_PLATFORM_MEMORY)
#error "ANTSSM_PLATFORM_STD_FREE defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_EXIT) && \
    !defined(ANTSSM_PLATFORM_EXIT_ALT)
#error "ANTSSM_PLATFORM_STD_EXIT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_TIME) && \
    (!defined(ANTSSM_PLATFORM_TIME_ALT) || \
        !defined(ANTSSM_HAVE_TIME))
#error "ANTSSM_PLATFORM_STD_TIME defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_FPRINTF) && \
    !defined(ANTSSM_PLATFORM_FPRINTF_ALT)
#error "ANTSSM_PLATFORM_STD_FPRINTF defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_PRINTF) && \
    !defined(ANTSSM_PLATFORM_PRINTF_ALT)
#error "ANTSSM_PLATFORM_STD_PRINTF defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_SNPRINTF) && \
    !defined(ANTSSM_PLATFORM_SNPRINTF_ALT)
#error "ANTSSM_PLATFORM_STD_SNPRINTF defined, but not all prerequisites"
#endif

#if defined(ANTSSM_ENTROPY_NV_SEED) && \
    (!defined(ANTSSM_PLATFORM_C) || !defined(ANTSSM_ENTROPY_C))
#error "ANTSSM_ENTROPY_NV_SEED defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_NV_SEED_ALT) && \
    !defined(ANTSSM_ENTROPY_NV_SEED)
#error "ANTSSM_PLATFORM_NV_SEED_ALT defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_NV_SEED_READ) && \
    !defined(ANTSSM_PLATFORM_NV_SEED_ALT)
#error "ANTSSM_PLATFORM_STD_NV_SEED_READ defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_STD_NV_SEED_WRITE) && \
    !defined(ANTSSM_PLATFORM_NV_SEED_ALT)
#error "ANTSSM_PLATFORM_STD_NV_SEED_WRITE defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PLATFORM_NV_SEED_READ_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_NV_SEED_READ) || \
      defined(ANTSSM_PLATFORM_NV_SEED_ALT))
#error "ANTSSM_PLATFORM_NV_SEED_READ_MACRO and ANTSSM_PLATFORM_STD_NV_SEED_READ cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PLATFORM_NV_SEED_WRITE_MACRO) && \
    (defined(ANTSSM_PLATFORM_STD_NV_SEED_WRITE) || \
      defined(ANTSSM_PLATFORM_NV_SEED_ALT))
#error "ANTSSM_PLATFORM_NV_SEED_WRITE_MACRO and ANTSSM_PLATFORM_STD_NV_SEED_WRITE cannot be defined simultaneously"
#endif

#if defined(ANTSSM_PSA_CRYPTO_C) && \
    !(defined(ANTSSM_CTR_DRBG_C) && \
       defined(ANTSSM_ENTROPY_C))
#error "ANTSSM_PSA_CRYPTO_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PSA_CRYPTO_SPM) && !defined(ANTSSM_PSA_CRYPTO_C)
#error "ANTSSM_PSA_CRYPTO_SPM defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PSA_CRYPTO_SE_C) && \
    !(defined(ANTSSM_PSA_CRYPTO_C) && \
        defined(ANTSSM_PSA_CRYPTO_STORAGE_C))
#error "ANTSSM_PSA_CRYPTO_SE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PSA_CRYPTO_STORAGE_C) && \
    !defined(ANTSSM_PSA_CRYPTO_C)
#error "ANTSSM_PSA_CRYPTO_STORAGE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PSA_INJECT_ENTROPY) && \
    !(defined(ANTSSM_PSA_CRYPTO_STORAGE_C) && \
       defined(ANTSSM_ENTROPY_NV_SEED))
#error "ANTSSM_PSA_INJECT_ENTROPY defined, but not all prerequisites"
#endif

#if defined(ANTSSM_PSA_INJECT_ENTROPY) && \
    !defined(ANTSSM_NO_DEFAULT_ENTROPY_SOURCES)
#error "ANTSSM_PSA_INJECT_ENTROPY is not compatible with actual entropy sources"
#endif

#if defined(ANTSSM_PSA_ITS_FILE_C) && \
    !defined(ANTSSM_FS_IO)
#error "ANTSSM_PSA_ITS_FILE_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_RSA_C) && !defined(ANTSSM_MPI_C)
#error "ANTSSM_RSA_C defined, but not all prerequisites"
#endif

#if defined(ANTSSM_RSA_C) && (!defined(ANTSSM_PKCS1_V21) && \
    !defined(ANTSSM_PKCS1_V15))
#error "ANTSSM_RSA_C defined, but none of the PKCS1 versions enabled"
#endif

#if defined(ANTSSM_THREADING_PTHREAD)
#if !defined(ANTSSM_THREADING_C) || defined(ANTSSM_THREADING_IMPL)
#error "ANTSSM_THREADING_PTHREAD defined, but not all prerequisites"
#endif
#define ANTSSM_THREADING_IMPL
#endif

#if defined(ANTSSM_THREADING_ALT)
#if !defined(ANTSSM_THREADING_C) || defined(ANTSSM_THREADING_IMPL)
#error "ANTSSM_THREADING_ALT defined, but not all prerequisites"
#endif
#define ANTSSM_THREADING_IMPL
#endif

#if defined(ANTSSM_THREADING_C) && !defined(ANTSSM_THREADING_IMPL)
#error "ANTSSM_THREADING_C defined, single threading implementation required"
#endif
#undef ANTSSM_THREADING_IMPL

#if defined(ANTSSM_USE_PSA_CRYPTO) && !defined(ANTSSM_PSA_CRYPTO_C)
#error "ANTSSM_USE_PSA_CRYPTO defined, but not all prerequisites"
#endif

#if defined(ANTANTSSM_VERSION_FEATURES) && !defined(ANTSSM_VERSION_C)
#error "ANTANTSSM_VERSION_FEATURES defined, but not all prerequisites"
#endif

#if defined(ANTSSM_HAVE_INT32) && defined(ANTSSM_HAVE_INT64)
#error "ANTSSM_HAVE_INT32 and ANTSSM_HAVE_INT64 cannot be defined simultaneously"
#endif /* ANTSSM_HAVE_INT32 && ANTSSM_HAVE_INT64 */

#if (defined(ANTSSM_HAVE_INT32) || defined(ANTSSM_HAVE_INT64)) && \
    defined(ANTSSM_HAVE_ASM)
#error "ANTSSM_HAVE_INT32/ANTSSM_HAVE_INT64 and ANTSSM_HAVE_ASM cannot be defined simultaneously"
#endif /* (ANTSSM_HAVE_INT32 || ANTSSM_HAVE_INT64) && ANTSSM_HAVE_ASM */

/*
 * Avoid warning from -pedantic. This is a convenient place for this
 * workaround since this is included by every single file before the
 * #if defined(ANTSSM_xxx_C) that results in empty translation units.
 */
typedef int mpaas_antssm_iso_c_forbids_empty_translation_units;

#endif /* ANTSSM_CHECK_CONFIG_H */
