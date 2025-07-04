/**
 * \file cipher.h
 *
 * \brief This file contains an abstraction interface for use with the cipher
 * primitives provided by the library. It provides a common interface to all of
 * the available cipher operations.
 *
 * \author Adriaan de Jong <dejong@fox-it.com>
 */
/*
 *  Copyright (C) 2006-2018, Arm Limited (or its affiliates), All Rights Reserved
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
 *  This file is part of Mbed TLS (https://tls.mbed.org)
 */

#ifndef ANTSSM_CIPHER_H
#define ANTSSM_CIPHER_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>

#if defined(ANTSSM_GCM_C) || defined(ANTSSM_CCM_C) || defined(ANTSSM_CHACHAPOLY_C)
#define ANTSSM_CIPHER_MODE_AEAD
#endif

#if defined(ANTSSM_CIPHER_MODE_CBC)
#define ANTSSM_CIPHER_MODE_WITH_PADDING
#endif

#if defined(ANTSSM_ARC4_C) || defined(ANTSSM_CIPHER_NULL_CIPHER) || \
    defined(ANTSSM_CHACHA20_C)
#define ANTSSM_CIPHER_MODE_STREAM
#endif

#if (defined(__ARMCC_VERSION) || defined(_MSC_VER)) && \
    !defined(inline) && !defined(__cplusplus)
#define inline __inline
#endif

#define ANTSSM_ERR_CIPHER_FEATURE_UNAVAILABLE  -0x6080  /**< The selected feature is not available. */
#define ANTSSM_ERR_CIPHER_BAD_INPUT_DATA       -0x6100  /**< Bad input parameters. */
#define ANTSSM_ERR_CIPHER_ALLOC_FAILED         -0x6180  /**< Failed to allocate memory. */
#define ANTSSM_ERR_CIPHER_INVALID_PADDING      -0x6200  /**< Input data contains invalid padding and is rejected. */
#define ANTSSM_ERR_CIPHER_FULL_BLOCK_EXPECTED  -0x6280  /**< Decryption of block requires a full block. */
#define ANTSSM_ERR_CIPHER_AUTH_FAILED          -0x6300  /**< Authentication failed (for AEAD modes). */
#define ANTSSM_ERR_CIPHER_INVALID_CONTEXT      -0x6380  /**< The context is invalid. For example, because it was freed. */

/* ANTSSM_ERR_CIPHER_HW_ACCEL_FAILED is deprecated and should not be used. */
#define ANTSSM_ERR_CIPHER_HW_ACCEL_FAILED      -0x6400  /**< Cipher hardware accelerator failed. */

#define ANTSSM_CIPHER_VARIABLE_IV_LEN     0x01    /**< Cipher accepts IVs of variable length. */
#define ANTSSM_CIPHER_VARIABLE_KEY_LEN    0x02    /**< Cipher accepts keys of variable length. */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief     Supported cipher types.
 *
 * \warning   RC4 and DES are considered weak ciphers and their use
 *            constitutes a security risk. Arm recommends considering stronger
 *            ciphers instead.
 */
typedef enum {
    ANTSSM_CIPHER_ID_NONE = 0,  /**< Placeholder to mark the end of cipher ID lists. */
    ANTSSM_CIPHER_ID_NULL,      /**< The identity cipher, treated as a stream cipher. */
    ANTSSM_CIPHER_ID_AES,       /**< The AES cipher. */
    ANTSSM_CIPHER_ID_DES,       /**< The DES cipher. */
    ANTSSM_CIPHER_ID_3DES,      /**< The Triple DES cipher. */
    ANTSSM_CIPHER_ID_CAMELLIA,  /**< The Camellia cipher. */
    ANTSSM_CIPHER_ID_BLOWFISH,  /**< The Blowfish cipher. */
    ANTSSM_CIPHER_ID_ARC4,      /**< The RC4 cipher. */
    ANTSSM_CIPHER_ID_ARIA,      /**< The Aria cipher. */
    ANTSSM_CIPHER_ID_CHACHA20,  /**< The ChaCha20 cipher. */
    ANTSSM_CIPHER_ID_SM4,       /**< The SM4 cipher. */
} mpaas_antssm_cipher_id_t;

/**
 * \brief     Supported {cipher type, cipher mode} pairs.
 *
 * \warning   RC4 and DES are considered weak ciphers and their use
 *            constitutes a security risk. Arm recommends considering stronger
 *            ciphers instead.
 */
typedef enum {
    ANTSSM_CIPHER_NONE = 0,             /**< Placeholder to mark the end of cipher-pair lists. */
    ANTSSM_CIPHER_NULL,                 /**< The identity stream cipher. */
    ANTSSM_CIPHER_AES_128_ECB,          /**< AES cipher with 128-bit ECB mode. */
    ANTSSM_CIPHER_AES_192_ECB,          /**< AES cipher with 192-bit ECB mode. */
    ANTSSM_CIPHER_AES_256_ECB,          /**< AES cipher with 256-bit ECB mode. */
    ANTSSM_CIPHER_AES_128_CBC,          /**< AES cipher with 128-bit CBC mode. */
    ANTSSM_CIPHER_AES_192_CBC,          /**< AES cipher with 192-bit CBC mode. */
    ANTSSM_CIPHER_AES_256_CBC,          /**< AES cipher with 256-bit CBC mode. */
    ANTSSM_CIPHER_AES_128_CFB128,       /**< AES cipher with 128-bit CFB128 mode. */
    ANTSSM_CIPHER_AES_192_CFB128,       /**< AES cipher with 192-bit CFB128 mode. */
    ANTSSM_CIPHER_AES_256_CFB128,       /**< AES cipher with 256-bit CFB128 mode. */
    ANTSSM_CIPHER_AES_128_CTR,          /**< AES cipher with 128-bit CTR mode. */
    ANTSSM_CIPHER_AES_192_CTR,          /**< AES cipher with 192-bit CTR mode. */
    ANTSSM_CIPHER_AES_256_CTR,          /**< AES cipher with 256-bit CTR mode. */
    ANTSSM_CIPHER_AES_128_GCM,          /**< AES cipher with 128-bit GCM mode. */
    ANTSSM_CIPHER_AES_192_GCM,          /**< AES cipher with 192-bit GCM mode. */
    ANTSSM_CIPHER_AES_256_GCM,          /**< AES cipher with 256-bit GCM mode. */
    ANTSSM_CIPHER_CAMELLIA_128_ECB,     /**< Camellia cipher with 128-bit ECB mode. */
    ANTSSM_CIPHER_CAMELLIA_192_ECB,     /**< Camellia cipher with 192-bit ECB mode. */
    ANTSSM_CIPHER_CAMELLIA_256_ECB,     /**< Camellia cipher with 256-bit ECB mode. */
    ANTSSM_CIPHER_CAMELLIA_128_CBC,     /**< Camellia cipher with 128-bit CBC mode. */
    ANTSSM_CIPHER_CAMELLIA_192_CBC,     /**< Camellia cipher with 192-bit CBC mode. */
    ANTSSM_CIPHER_CAMELLIA_256_CBC,     /**< Camellia cipher with 256-bit CBC mode. */
    ANTSSM_CIPHER_CAMELLIA_128_CFB128,  /**< Camellia cipher with 128-bit CFB128 mode. */
    ANTSSM_CIPHER_CAMELLIA_192_CFB128,  /**< Camellia cipher with 192-bit CFB128 mode. */
    ANTSSM_CIPHER_CAMELLIA_256_CFB128,  /**< Camellia cipher with 256-bit CFB128 mode. */
    ANTSSM_CIPHER_CAMELLIA_128_CTR,     /**< Camellia cipher with 128-bit CTR mode. */
    ANTSSM_CIPHER_CAMELLIA_192_CTR,     /**< Camellia cipher with 192-bit CTR mode. */
    ANTSSM_CIPHER_CAMELLIA_256_CTR,     /**< Camellia cipher with 256-bit CTR mode. */
    ANTSSM_CIPHER_CAMELLIA_128_GCM,     /**< Camellia cipher with 128-bit GCM mode. */
    ANTSSM_CIPHER_CAMELLIA_192_GCM,     /**< Camellia cipher with 192-bit GCM mode. */
    ANTSSM_CIPHER_CAMELLIA_256_GCM,     /**< Camellia cipher with 256-bit GCM mode. */
    ANTSSM_CIPHER_DES_ECB,              /**< DES cipher with ECB mode. */
    ANTSSM_CIPHER_DES_CBC,              /**< DES cipher with CBC mode. */
    ANTSSM_CIPHER_DES_EDE_ECB,          /**< DES cipher with EDE ECB mode. */
    ANTSSM_CIPHER_DES_EDE_CBC,          /**< DES cipher with EDE CBC mode. */
    ANTSSM_CIPHER_DES_EDE3_ECB,         /**< DES cipher with EDE3 ECB mode. */
    ANTSSM_CIPHER_DES_EDE3_CBC,         /**< DES cipher with EDE3 CBC mode. */
    ANTSSM_CIPHER_BLOWFISH_ECB,         /**< Blowfish cipher with ECB mode. */
    ANTSSM_CIPHER_BLOWFISH_CBC,         /**< Blowfish cipher with CBC mode. */
    ANTSSM_CIPHER_BLOWFISH_CFB64,       /**< Blowfish cipher with CFB64 mode. */
    ANTSSM_CIPHER_BLOWFISH_CTR,         /**< Blowfish cipher with CTR mode. */
    ANTSSM_CIPHER_ARC4_128,             /**< RC4 cipher with 128-bit mode. */
    ANTSSM_CIPHER_AES_128_CCM,          /**< AES cipher with 128-bit CCM mode. */
    ANTSSM_CIPHER_AES_192_CCM,          /**< AES cipher with 192-bit CCM mode. */
    ANTSSM_CIPHER_AES_256_CCM,          /**< AES cipher with 256-bit CCM mode. */
    ANTSSM_CIPHER_CAMELLIA_128_CCM,     /**< Camellia cipher with 128-bit CCM mode. */
    ANTSSM_CIPHER_CAMELLIA_192_CCM,     /**< Camellia cipher with 192-bit CCM mode. */
    ANTSSM_CIPHER_CAMELLIA_256_CCM,     /**< Camellia cipher with 256-bit CCM mode. */
    ANTSSM_CIPHER_ARIA_128_ECB,         /**< Aria cipher with 128-bit key and ECB mode. */
    ANTSSM_CIPHER_ARIA_192_ECB,         /**< Aria cipher with 192-bit key and ECB mode. */
    ANTSSM_CIPHER_ARIA_256_ECB,         /**< Aria cipher with 256-bit key and ECB mode. */
    ANTSSM_CIPHER_ARIA_128_CBC,         /**< Aria cipher with 128-bit key and CBC mode. */
    ANTSSM_CIPHER_ARIA_192_CBC,         /**< Aria cipher with 192-bit key and CBC mode. */
    ANTSSM_CIPHER_ARIA_256_CBC,         /**< Aria cipher with 256-bit key and CBC mode. */
    ANTSSM_CIPHER_ARIA_128_CFB128,      /**< Aria cipher with 128-bit key and CFB-128 mode. */
    ANTSSM_CIPHER_ARIA_192_CFB128,      /**< Aria cipher with 192-bit key and CFB-128 mode. */
    ANTSSM_CIPHER_ARIA_256_CFB128,      /**< Aria cipher with 256-bit key and CFB-128 mode. */
    ANTSSM_CIPHER_ARIA_128_CTR,         /**< Aria cipher with 128-bit key and CTR mode. */
    ANTSSM_CIPHER_ARIA_192_CTR,         /**< Aria cipher with 192-bit key and CTR mode. */
    ANTSSM_CIPHER_ARIA_256_CTR,         /**< Aria cipher with 256-bit key and CTR mode. */
    ANTSSM_CIPHER_ARIA_128_GCM,         /**< Aria cipher with 128-bit key and GCM mode. */
    ANTSSM_CIPHER_ARIA_192_GCM,         /**< Aria cipher with 192-bit key and GCM mode. */
    ANTSSM_CIPHER_ARIA_256_GCM,         /**< Aria cipher with 256-bit key and GCM mode. */
    ANTSSM_CIPHER_ARIA_128_CCM,         /**< Aria cipher with 128-bit key and CCM mode. */
    ANTSSM_CIPHER_ARIA_192_CCM,         /**< Aria cipher with 192-bit key and CCM mode. */
    ANTSSM_CIPHER_ARIA_256_CCM,         /**< Aria cipher with 256-bit key and CCM mode. */
    ANTSSM_CIPHER_AES_128_OFB,          /**< AES 128-bit cipher in OFB mode. */
    ANTSSM_CIPHER_AES_192_OFB,          /**< AES 192-bit cipher in OFB mode. */
    ANTSSM_CIPHER_AES_256_OFB,          /**< AES 256-bit cipher in OFB mode. */
    ANTSSM_CIPHER_AES_128_XTS,          /**< AES 128-bit cipher in XTS block mode. */
    ANTSSM_CIPHER_AES_256_XTS,          /**< AES 256-bit cipher in XTS block mode. */
    ANTSSM_CIPHER_CHACHA20,             /**< ChaCha20 stream cipher. */
    ANTSSM_CIPHER_CHACHA20_POLY1305,    /**< ChaCha20-Poly1305 AEAD cipher. */
    ANTSSM_CIPHER_AES_128_KW,           /**< AES cipher with 128-bit NIST KW mode. */
    ANTSSM_CIPHER_AES_192_KW,           /**< AES cipher with 192-bit NIST KW mode. */
    ANTSSM_CIPHER_AES_256_KW,           /**< AES cipher with 256-bit NIST KW mode. */
    ANTSSM_CIPHER_AES_128_KWP,          /**< AES cipher with 128-bit NIST KWP mode. */
    ANTSSM_CIPHER_AES_192_KWP,          /**< AES cipher with 192-bit NIST KWP mode. */
    ANTSSM_CIPHER_AES_256_KWP,          /**< AES cipher with 256-bit NIST KWP mode. */
    ANTSSM_CIPHER_SM4_ECB,
    ANTSSM_CIPHER_SM4_CBC,
    ANTSSM_CIPHER_SM4_XTS,
} mpaas_antssm_cipher_type_t;

/** Supported cipher modes. */
typedef enum {
    ANTSSM_MODE_NONE = 0,               /**< None.                        */
    ANTSSM_MODE_ECB,                    /**< The ECB cipher mode.         */
    ANTSSM_MODE_CBC,                    /**< The CBC cipher mode.         */
    ANTSSM_MODE_CFB,                    /**< The CFB cipher mode.         */
    ANTSSM_MODE_OFB,                    /**< The OFB cipher mode.         */
    ANTSSM_MODE_CTR,                    /**< The CTR cipher mode.         */
    ANTSSM_MODE_GCM,                    /**< The GCM cipher mode.         */
    ANTSSM_MODE_STREAM,                 /**< The stream cipher mode.      */
    ANTSSM_MODE_CCM,                    /**< The CCM cipher mode.         */
    ANTSSM_MODE_XTS,                    /**< The XTS cipher mode.         */
    ANTSSM_MODE_CHACHAPOLY,             /**< The ChaCha-Poly cipher mode. */
    ANTSSM_MODE_KW,                     /**< The SP800-38F KW mode */
    ANTSSM_MODE_KWP,                    /**< The SP800-38F KWP mode */
} mpaas_antssm_cipher_mode_t;

/** Supported cipher padding types. */
typedef enum {
    ANTSSM_PADDING_PKCS7 = 0,     /**< PKCS7 padding (default).        */
    ANTSSM_PADDING_ONE_AND_ZEROS, /**< ISO/IEC 7816-4 padding.         */
    ANTSSM_PADDING_ZEROS_AND_LEN, /**< ANSI X.923 padding.             */
    ANTSSM_PADDING_ZEROS,         /**< Zero padding (not reversible). */
    ANTSSM_PADDING_NONE,          /**< Never pad (full blocks only).   */
} mpaas_antssm_cipher_padding_t;

/** Type of operation. */
typedef enum {
    ANTSSM_OPERATION_NONE = -1,
    ANTSSM_DECRYPT = 0,
    ANTSSM_ENCRYPT,
} mpaas_antssm_operation_t;

enum {
    /** Undefined key length. */
            ANTSSM_KEY_LENGTH_NONE = 0,
    /** Key length, in bits (including parity), for DES keys. */
            ANTSSM_KEY_LENGTH_DES = 64,
    /** Key length in bits, including parity, for DES in two-key EDE. */
            ANTSSM_KEY_LENGTH_DES_EDE = 128,
    /** Key length in bits, including parity, for DES in three-key EDE. */
            ANTSSM_KEY_LENGTH_DES_EDE3 = 192,
};

/** Maximum length of any IV, in Bytes. */
#define ANTSSM_MAX_IV_LENGTH      16
/** Maximum block size of any cipher, in Bytes. */
#define ANTSSM_MAX_BLOCK_LENGTH   16

/**
 * Base cipher information (opaque struct).
 */
typedef struct mpaas_antssm_cipher_base_t mpaas_antssm_cipher_base_t;

/**
 * CMAC context (opaque struct).
 */
typedef struct mpaas_antssm_cmac_context_t mpaas_antssm_cmac_context_t;

/**
 * Cipher information. Allows calling cipher functions
 * in a generic way.
 */
typedef struct mpaas_antssm_cipher_info_t {
    /** Full cipher identifier. For example,
     * ANTSSM_CIPHER_AES_256_CBC.
     */
    mpaas_antssm_cipher_type_t type;

    /** The cipher mode. For example, ANTSSM_MODE_CBC. */
    mpaas_antssm_cipher_mode_t mode;

    /** The cipher key length, in bits. This is the
     * default length for variable sized ciphers.
     * Includes parity bits for ciphers like DES.
     */
    unsigned int key_bitlen;

    /** Name of the cipher. */
    const char *name;

    /** IV or nonce size, in Bytes.
     * For ciphers that accept variable IV sizes,
     * this is the recommended size.
     */
    unsigned int iv_size;

    /** Bitflag comprised of ANTSSM_CIPHER_VARIABLE_IV_LEN and
     *  ANTSSM_CIPHER_VARIABLE_KEY_LEN indicating whether the
     *  cipher supports variable IV or variable key sizes, respectively.
     */
    int flags;

    /** The block size, in Bytes. */
    unsigned int block_size;

    /** Struct for base cipher information and functions. */
    const mpaas_antssm_cipher_base_t *base;

} mpaas_antssm_cipher_info_t;

/**
 * Generic cipher context.
 */
typedef struct mpaas_antssm_cipher_context_t {
    /** Information about the associated cipher. */
    const mpaas_antssm_cipher_info_t *cipher_info;

    /** Key length to use. */
    int key_bitlen;

    /** Operation that the key of the context has been
     * initialized for.
     */
    mpaas_antssm_operation_t operation;

#if defined(ANTSSM_CIPHER_MODE_WITH_PADDING)

    /** Padding functions to use, if relevant for
     * the specific cipher mode.
     */
    void (*add_padding)(unsigned char *output, size_t olen, size_t data_len);

    int (*get_padding)(unsigned char *input, size_t ilen, size_t *data_len);

#endif

    /** Buffer for input that has not been processed yet. */
    unsigned char unprocessed_data[ANTSSM_MAX_BLOCK_LENGTH];

    /** Number of Bytes that have not been processed yet. */
    size_t unprocessed_len;

    /** Current IV or NONCE_COUNTER for CTR-mode, data unit (or sector) number
     * for XTS-mode. */
    unsigned char iv[ANTSSM_MAX_IV_LENGTH];

    /** IV size in Bytes, for ciphers with variable-length IVs. */
    size_t iv_size;

    /** The cipher-specific context. */
    void *cipher_ctx;

#if defined(ANTSSM_CMAC_C)
    /** CMAC-specific context. */
    mpaas_antssm_cmac_context_t *cmac_ctx;
#endif

#if defined(ANTSSM_USE_PSA_CRYPTO)
    /** Indicates whether the cipher operations should be performed
     *  by Mbed TLS' own crypto library or an external implementation
     *  of the PSA Crypto API.
     *  This is unset if the cipher context was established through
     *  mpaas_antssm_cipher_setup(), and set if it was established through
     *  mpaas_antssm_cipher_setup_psa().
     */
    unsigned char psa_enabled;
#endif /* ANTSSM_USE_PSA_CRYPTO */

} mpaas_antssm_cipher_context_t;

/**
 * \brief This function retrieves the list of ciphers supported
 *        by the generic cipher module.
 *
 *        For any cipher identifier in the returned list, you can
 *        obtain the corresponding generic cipher information structure
 *        via mpaas_antssm_cipher_info_from_type(), which can then be used
 *        to prepare a cipher context via mpaas_antssm_cipher_setup().
 *
 *
 * \return      A statically-allocated array of cipher identifiers
 *              of type cipher_type_t. The last entry is zero.
 */
const int *mpaas_antssm_cipher_list(void);

/**
 * \brief               This function retrieves the cipher-information
 *                      structure associated with the given cipher name.
 *
 * \param cipher_name   Name of the cipher to search for. This must not be
 *                      \c NULL.
 *
 * \return              The cipher information structure associated with the
 *                      given \p cipher_name.
 * \return              \c NULL if the associated cipher information is not found.
 */
const mpaas_antssm_cipher_info_t *mpaas_antssm_cipher_info_from_string(const char *cipher_name);

/**
 * \brief               This function retrieves the cipher-information
 *                      structure associated with the given cipher type.
 *
 * \param cipher_type   Type of the cipher to search for.
 *
 * \return              The cipher information structure associated with the
 *                      given \p cipher_type.
 * \return              \c NULL if the associated cipher information is not found.
 */
const mpaas_antssm_cipher_info_t *mpaas_antssm_cipher_info_from_type(const mpaas_antssm_cipher_type_t cipher_type);

/**
 * \brief               This function retrieves the cipher-information
 *                      structure associated with the given cipher ID,
 *                      key size and mode.
 *
 * \param cipher_id     The ID of the cipher to search for. For example,
 *                      #ANTSSM_CIPHER_ID_AES.
 * \param key_bitlen    The length of the key in bits.
 * \param mode          The cipher mode. For example, #ANTSSM_MODE_CBC.
 *
 * \return              The cipher information structure associated with the
 *                      given \p cipher_id.
 * \return              \c NULL if the associated cipher information is not found.
 */
const mpaas_antssm_cipher_info_t *mpaas_antssm_cipher_info_from_values(const mpaas_antssm_cipher_id_t cipher_id,
                                                           int key_bitlen,
                                                           const mpaas_antssm_cipher_mode_t mode);

/**
 * \brief               This function initializes a \p cipher_context as NONE.
 *
 * \param ctx           The context to be initialized. This must not be \c NULL.
 */
void mpaas_antssm_cipher_init(mpaas_antssm_cipher_context_t *ctx);

/**
 * \brief               This function frees and clears the cipher-specific
 *                      context of \p ctx. Freeing \p ctx itself remains the
 *                      responsibility of the caller.
 *
 * \param ctx           The context to be freed. If this is \c NULL, the
 *                      function has no effect, otherwise this must point to an
 *                      initialized context.
 */
void mpaas_antssm_cipher_free(mpaas_antssm_cipher_context_t *ctx);


/**
 * \brief               This function initializes a cipher context for
 *                      use with the given cipher primitive.
 *
 * \param ctx           The context to initialize. This must be initialized.
 * \param cipher_info   The cipher to use.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_ALLOC_FAILED if allocation of the
 *                      cipher-specific context fails.
 *
 * \internal Currently, the function also clears the structure.
 * In future versions, the caller will be required to call
 * mpaas_antssm_cipher_init() on the structure first.
 */
int mpaas_antssm_cipher_setup(mpaas_antssm_cipher_context_t *ctx,
                        const mpaas_antssm_cipher_info_t *cipher_info);

#if defined(ANTSSM_USE_PSA_CRYPTO)
/**
 * \brief               This function initializes a cipher context for
 *                      PSA-based use with the given cipher primitive.
 *
 * \note                See #ANTSSM_USE_PSA_CRYPTO for information on PSA.
 *
 * \param ctx           The context to initialize. May not be \c NULL.
 * \param cipher_info   The cipher to use.
 * \param taglen        For AEAD ciphers, the length in bytes of the
 *                      authentication tag to use. Subsequent uses of
 *                      mpaas_antssm_cipher_auth_encrypt() or
 *                      mpaas_antssm_cipher_auth_decrypt() must provide
 *                      the same tag length.
 *                      For non-AEAD ciphers, the value must be \c 0.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_ALLOC_FAILED if allocation of the
 *                      cipher-specific context fails.
 */
int mpaas_antssm_cipher_setup_psa( mpaas_antssm_cipher_context_t *ctx,
                              const mpaas_antssm_cipher_info_t *cipher_info,
                              size_t taglen );
#endif /* ANTSSM_USE_PSA_CRYPTO */

/**
 * \brief        This function returns the block size of the given cipher.
 *
 * \param ctx    The context of the cipher. This must be initialized.
 *
 * \return       The block size of the underlying cipher.
 * \return       \c 0 if \p ctx has not been initialized.
 */
static inline unsigned int mpaas_antssm_cipher_get_block_size(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return 0;
    }
    if (ctx->cipher_info == NULL)
        return 0;

    return ctx->cipher_info->block_size;
}

/**
 * \brief        This function returns the mode of operation for
 *               the cipher. For example, ANTSSM_MODE_CBC.
 *
 * \param ctx    The context of the cipher. This must be initialized.
 *
 * \return       The mode of operation.
 * \return       #ANTSSM_MODE_NONE if \p ctx has not been initialized.
 */
static inline mpaas_antssm_cipher_mode_t mpaas_antssm_cipher_get_cipher_mode(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return ANTSSM_MODE_NONE;
    }
    if (ctx->cipher_info == NULL)
        return ANTSSM_MODE_NONE;

    return ctx->cipher_info->mode;
}

/**
 * \brief       This function returns the size of the IV or nonce
 *              of the cipher, in Bytes.
 *
 * \param ctx   The context of the cipher. This must be initialized.
 *
 * \return      The recommended IV size if no IV has been set.
 * \return      \c 0 for ciphers not using an IV or a nonce.
 * \return      The actual size if an IV has been set.
 */
static inline int mpaas_antssm_cipher_get_iv_size(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return 0;
    }
    if (ctx->cipher_info == NULL)
        return 0;

    if (ctx->iv_size != 0)
        return (int) ctx->iv_size;

    return (int) ctx->cipher_info->iv_size;
}

/**
 * \brief               This function returns the type of the given cipher.
 *
 * \param ctx           The context of the cipher. This must be initialized.
 *
 * \return              The type of the cipher.
 * \return              #ANTSSM_CIPHER_NONE if \p ctx has not been initialized.
 */
static inline mpaas_antssm_cipher_type_t mpaas_antssm_cipher_get_type(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return ANTSSM_CIPHER_NONE;
    }
    if (ctx->cipher_info == NULL)
        return ANTSSM_CIPHER_NONE;

    return ctx->cipher_info->type;
}

/**
 * \brief               This function returns the name of the given cipher
 *                      as a string.
 *
 * \param ctx           The context of the cipher. This must be initialized.
 *
 * \return              The name of the cipher.
 * \return              NULL if \p ctx has not been not initialized.
 */
static inline const char *mpaas_antssm_cipher_get_name(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return 0;
    }
    if (ctx->cipher_info == NULL)
        return 0;

    return ctx->cipher_info->name;
}

/**
 * \brief               This function returns the key length of the cipher.
 *
 * \param ctx           The context of the cipher. This must be initialized.
 *
 * \return              The key length of the cipher in bits.
 * \return              #ANTSSM_KEY_LENGTH_NONE if ctx \p has not been
 *                      initialized.
 */
static inline int mpaas_antssm_cipher_get_key_bitlen(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return ANTSSM_KEY_LENGTH_NONE;
    }
    if (ctx->cipher_info == NULL)
        return ANTSSM_KEY_LENGTH_NONE;

    return (int) ctx->cipher_info->key_bitlen;
}

/**
 * \brief          This function returns the operation of the given cipher.
 *
 * \param ctx      The context of the cipher. This must be initialized.
 *
 * \return         The type of operation: #ANTSSM_ENCRYPT or #ANTSSM_DECRYPT.
 * \return         #ANTSSM_OPERATION_NONE if \p ctx has not been initialized.
 */
static inline mpaas_antssm_operation_t mpaas_antssm_cipher_get_operation(
        const mpaas_antssm_cipher_context_t *ctx)
{
    if (ctx == NULL) {
        return ANTSSM_OPERATION_NONE;
    }
    if (ctx->cipher_info == NULL)
        return ANTSSM_OPERATION_NONE;

    return ctx->operation;
}

/**
 * \brief               This function sets the key to use with the given context.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      bound to a cipher information structure.
 * \param key           The key to use. This must be a readable buffer of at
 *                      least \p key_bitlen Bits.
 * \param key_bitlen    The key length to use, in Bits.
 * \param operation     The operation that the key will be used for:
 *                      #ANTSSM_ENCRYPT or #ANTSSM_DECRYPT.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_setkey(mpaas_antssm_cipher_context_t *ctx,
                         const unsigned char *key,
                         int key_bitlen,
                         const mpaas_antssm_operation_t operation);

#if defined(ANTSSM_CIPHER_MODE_WITH_PADDING)

/**
 * \brief               This function sets the padding mode, for cipher modes
 *                      that use padding.
 *
 *                      The default passing mode is PKCS7 padding.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      bound to a cipher information structure.
 * \param mode          The padding mode.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_FEATURE_UNAVAILABLE
 *                      if the selected padding mode is not supported.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA if the cipher mode
 *                      does not support padding.
 */
int mpaas_antssm_cipher_set_padding_mode(mpaas_antssm_cipher_context_t *ctx,
                                   mpaas_antssm_cipher_padding_t mode);

#endif /* ANTSSM_CIPHER_MODE_WITH_PADDING */

/**
 * \brief           This function sets the initialization vector (IV)
 *                  or nonce.
 *
 * \note            Some ciphers do not use IVs nor nonce. For these
 *                  ciphers, this function has no effect.
 *
 * \param ctx       The generic cipher context. This must be initialized and
 *                  bound to a cipher information structure.
 * \param iv        The IV to use, or NONCE_COUNTER for CTR-mode ciphers. This
 *                  must be a readable buffer of at least \p iv_len Bytes.
 * \param iv_len    The IV length for ciphers with variable-size IV.
 *                  This parameter is discarded by ciphers with fixed-size IV.
 *
 * \return          \c 0 on success.
 * \return          #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                  parameter-verification failure.
 */
int mpaas_antssm_cipher_set_iv(mpaas_antssm_cipher_context_t *ctx,
                         const unsigned char *iv,
                         size_t iv_len);

/**
 * \brief         This function resets the cipher state.
 *
 * \param ctx     The generic cipher context. This must be initialized.
 *
 * \return        \c 0 on success.
 * \return        #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                parameter-verification failure.
 */
int mpaas_antssm_cipher_reset(mpaas_antssm_cipher_context_t *ctx);

#if defined(ANTSSM_GCM_C) || defined(ANTSSM_CHACHAPOLY_C)
/**
 * \brief               This function adds additional data for AEAD ciphers.
 *                      Currently supported with GCM and ChaCha20+Poly1305.
 *                      This must be called exactly once, after
 *                      mpaas_antssm_cipher_reset().
 *
 * \param ctx           The generic cipher context. This must be initialized.
 * \param ad            The additional data to use. This must be a readable
 *                      buffer of at least \p ad_len Bytes.
 * \param ad_len        The length of \p ad in Bytes.
 *
 * \return              \c 0 on success.
 * \return              A specific error code on failure.
 */
int mpaas_antssm_cipher_update_ad( mpaas_antssm_cipher_context_t *ctx,
                      const unsigned char *ad, size_t ad_len );
#endif /* ANTSSM_GCM_C || ANTSSM_CHACHAPOLY_C */

/**
 * \brief               The generic cipher update function. It encrypts or
 *                      decrypts using the given cipher context. Writes as
 *                      many block-sized blocks of data as possible to output.
 *                      Any data that cannot be written immediately is either
 *                      added to the next block, or flushed when
 *                      mpaas_antssm_cipher_finish() is called.
 *                      Exception: For ANTSSM_MODE_ECB, expects a single block
 *                      in size. For example, 16 Bytes for AES.
 *
 * \note                If the underlying cipher is used in GCM mode, all calls
 *                      to this function, except for the last one before
 *                      mpaas_antssm_cipher_finish(), must have \p ilen as a
 *                      multiple of the block size of the cipher.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      bound to a key.
 * \param input         The buffer holding the input data. This must be a
 *                      readable buffer of at least \p ilen Bytes.
 * \param ilen          The length of the input data.
 * \param output        The buffer for the output data. This must be able to
 *                      hold at least `ilen + block_size`. This must not be the
 *                      same buffer as \p input.
 * \param olen          The length of the output data, to be updated with the
 *                      actual number of Bytes written. This must not be
 *                      \c NULL.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_FEATURE_UNAVAILABLE on an
 *                      unsupported mode for a cipher.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_update(mpaas_antssm_cipher_context_t *ctx,
                         const unsigned char *input,
                         size_t ilen, unsigned char *output,
                         size_t *olen);

/**
 * \brief               The generic cipher finalization function. If data still
 *                      needs to be flushed from an incomplete block, the data
 *                      contained in it is padded to the size of
 *                      the last block, and written to the \p output buffer.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      bound to a key.
 * \param output        The buffer to write data to. This needs to be a writable
 *                      buffer of at least \p block_size Bytes.
 * \param olen          The length of the data written to the \p output buffer.
 *                      This may not be \c NULL.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_FULL_BLOCK_EXPECTED on decryption
 *                      expecting a full block but not receiving one.
 * \return              #ANTSSM_ERR_CIPHER_INVALID_PADDING on invalid padding
 *                      while decrypting.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_finish(mpaas_antssm_cipher_context_t *ctx,
                         unsigned char *output, size_t *olen);

#if defined(ANTSSM_GCM_C) || defined(ANTSSM_CHACHAPOLY_C)
/**
 * \brief               This function writes a tag for AEAD ciphers.
 *                      Currently supported with GCM and ChaCha20+Poly1305.
 *                      This must be called after mpaas_antssm_cipher_finish().
 *
 * \param ctx           The generic cipher context. This must be initialized,
 *                      bound to a key, and have just completed a cipher
 *                      operation through mpaas_antssm_cipher_finish() the tag for
 *                      which should be written.
 * \param tag           The buffer to write the tag to. This must be a writable
 *                      buffer of at least \p tag_len Bytes.
 * \param tag_len       The length of the tag to write.
 *
 * \return              \c 0 on success.
 * \return              A specific error code on failure.
 */
int mpaas_antssm_cipher_write_tag( mpaas_antssm_cipher_context_t *ctx,
                      unsigned char *tag, size_t tag_len );

/**
 * \brief               This function checks the tag for AEAD ciphers.
 *                      Currently supported with GCM and ChaCha20+Poly1305.
 *                      This must be called after mpaas_antssm_cipher_finish().
 *
 * \param ctx           The generic cipher context. This must be initialized.
 * \param tag           The buffer holding the tag. This must be a readable
 *                      buffer of at least \p tag_len Bytes.
 * \param tag_len       The length of the tag to check.
 *
 * \return              \c 0 on success.
 * \return              A specific error code on failure.
 */
int mpaas_antssm_cipher_check_tag( mpaas_antssm_cipher_context_t *ctx,
                      const unsigned char *tag, size_t tag_len );
#endif /* ANTSSM_GCM_C || ANTSSM_CHACHAPOLY_C */

/**
 * \brief               The generic all-in-one encryption/decryption function,
 *                      for all ciphers except AEAD constructs.
 *
 * \param ctx           The generic cipher context. This must be initialized.
 * \param iv            The IV to use, or NONCE_COUNTER for CTR-mode ciphers.
 *                      This must be a readable buffer of at least \p iv_len
 *                      Bytes.
 * \param iv_len        The IV length for ciphers with variable-size IV.
 *                      This parameter is discarded by ciphers with fixed-size
 *                      IV.
 * \param input         The buffer holding the input data. This must be a
 *                      readable buffer of at least \p ilen Bytes.
 * \param ilen          The length of the input data in Bytes.
 * \param output        The buffer for the output data. This must be able to
 *                      hold at least `ilen + block_size`. This must not be the
 *                      same buffer as \p input.
 * \param olen          The length of the output data, to be updated with the
 *                      actual number of Bytes written. This must not be
 *                      \c NULL.
 *
 * \note                Some ciphers do not use IVs nor nonce. For these
 *                      ciphers, use \p iv = NULL and \p iv_len = 0.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_FULL_BLOCK_EXPECTED on decryption
 *                      expecting a full block but not receiving one.
 * \return              #ANTSSM_ERR_CIPHER_INVALID_PADDING on invalid padding
 *                      while decrypting.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_crypt(mpaas_antssm_cipher_context_t *ctx,
                        const unsigned char *iv, size_t iv_len,
                        const unsigned char *input, size_t ilen,
                        unsigned char *output, size_t *olen);

#if defined(ANTSSM_CIPHER_MODE_AEAD)
/**
 * \brief               The generic autenticated encryption (AEAD) function.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      bound to a key.
 * \param iv            The IV to use, or NONCE_COUNTER for CTR-mode ciphers.
 *                      This must be a readable buffer of at least \p iv_len
 *                      Bytes.
 * \param iv_len        The IV length for ciphers with variable-size IV.
 *                      This parameter is discarded by ciphers with fixed-size IV.
 * \param ad            The additional data to authenticate. This must be a
 *                      readable buffer of at least \p ad_len Bytes.
 * \param ad_len        The length of \p ad.
 * \param input         The buffer holding the input data. This must be a
 *                      readable buffer of at least \p ilen Bytes.
 * \param ilen          The length of the input data.
 * \param output        The buffer for the output data. This must be able to
 *                      hold at least \p ilen Bytes.
 * \param olen          The length of the output data, to be updated with the
 *                      actual number of Bytes written. This must not be
 *                      \c NULL.
 * \param tag           The buffer for the authentication tag. This must be a
 *                      writable buffer of at least \p tag_len Bytes.
 * \param tag_len       The desired length of the authentication tag.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_auth_encrypt( mpaas_antssm_cipher_context_t *ctx,
                         const unsigned char *iv, size_t iv_len,
                         const unsigned char *ad, size_t ad_len,
                         const unsigned char *input, size_t ilen,
                         unsigned char *output, size_t *olen,
                         unsigned char *tag, size_t tag_len );

/**
 * \brief               The generic autenticated decryption (AEAD) function.
 *
 * \note                If the data is not authentic, then the output buffer
 *                      is zeroed out to prevent the unauthentic plaintext being
 *                      used, making this interface safer.
 *
 * \param ctx           The generic cipher context. This must be initialized and
 *                      and bound to a key.
 * \param iv            The IV to use, or NONCE_COUNTER for CTR-mode ciphers.
 *                      This must be a readable buffer of at least \p iv_len
 *                      Bytes.
 * \param iv_len        The IV length for ciphers with variable-size IV.
 *                      This parameter is discarded by ciphers with fixed-size IV.
 * \param ad            The additional data to be authenticated. This must be a
 *                      readable buffer of at least \p ad_len Bytes.
 * \param ad_len        The length of \p ad.
 * \param input         The buffer holding the input data. This must be a
 *                      readable buffer of at least \p ilen Bytes.
 * \param ilen          The length of the input data.
 * \param output        The buffer for the output data.
 *                      This must be able to hold at least \p ilen Bytes.
 * \param olen          The length of the output data, to be updated with the
 *                      actual number of Bytes written. This must not be
 *                      \c NULL.
 * \param tag           The buffer holding the authentication tag. This must be
 *                      a readable buffer of at least \p tag_len Bytes.
 * \param tag_len       The length of the authentication tag.
 *
 * \return              \c 0 on success.
 * \return              #ANTSSM_ERR_CIPHER_BAD_INPUT_DATA on
 *                      parameter-verification failure.
 * \return              #ANTSSM_ERR_CIPHER_AUTH_FAILED if data is not authentic.
 * \return              A cipher-specific error code on failure.
 */
int mpaas_antssm_cipher_auth_decrypt( mpaas_antssm_cipher_context_t *ctx,
                         const unsigned char *iv, size_t iv_len,
                         const unsigned char *ad, size_t ad_len,
                         const unsigned char *input, size_t ilen,
                         unsigned char *output, size_t *olen,
                         const unsigned char *tag, size_t tag_len );
#endif /* ANTSSM_CIPHER_MODE_AEAD */

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_CIPHER_H */
