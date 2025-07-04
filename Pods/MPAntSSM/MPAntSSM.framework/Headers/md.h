/**
 * \file md.h
 *
 * \brief Generic message digest wrapper
 *
 * \author Adriaan de Jong <dejong@fox-it.com>
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
#ifndef ANTSSM_MD_H
#define ANTSSM_MD_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>

#include "log.h"

#define ANTSSM_ERR_MD_FEATURE_UNAVAILABLE                -0x5080  /**< The selected feature is not available. */
#define ANTSSM_ERR_MD_BAD_INPUT_DATA                     -0x5100  /**< Bad input parameters to function. */
#define ANTSSM_ERR_MD_ALLOC_FAILED                       -0x5180  /**< Failed to allocate memory. */
#define ANTSSM_ERR_MD_FILE_IO_ERROR                      -0x5200  /**< Opening or reading of file failed. */

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    ANTSSM_MD_NONE = 0,
    ANTSSM_MD_MD2,
    ANTSSM_MD_MD4,
    ANTSSM_MD_MD5,
    ANTSSM_MD_SHA1,
    ANTSSM_MD_SHA224,
    ANTSSM_MD_SHA256,
    ANTSSM_MD_SHA384,
    ANTSSM_MD_SHA512,
    ANTSSM_MD_RIPEMD160,
    ANTSSM_MD_SM3,
    ANTSSM_MD_NAKED,
} mpaas_antssm_md_type_t;

#if defined(ANTSSM_SHA512_C)
#define ANTSSM_MD_MAX_SIZE         64  /* longest known is SHA512 */
#else
#define ANTSSM_MD_MAX_SIZE         32  /* longest known is SHA256 or less */
#endif

/**
 * Opaque struct defined in md_internal.h
 */
typedef struct mpaas_antssm_md_info_t mpaas_antssm_md_info_t;

/**
 * Generic message digest context.
 */
typedef struct {
    /** Information about the associated message digest */
    const mpaas_antssm_md_info_t *md_info;

    /** Digest-specific context */
    void *md_ctx;

    /** HMAC part of the context */
    void *hmac_ctx;
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_md_context_t;

/**
 * \brief Returns the list of digests supported by the generic digest module.
 *
 * \return          a statically allocated array of digests, the last entry
 *                  is 0.
 */
const int *mpaas_antssm_md_list(void);

/**
 * \brief           Returns the message digest information associated with the
 *                  given digest name.
 *
 * \param md_name   Name of the digest to search for.
 *
 * \return          The message digest information associated with md_name or
 *                  NULL if not found.
 */
const mpaas_antssm_md_info_t *mpaas_antssm_md_info_from_string(const char *md_name);

/**
 * \brief           Returns the message digest information associated with the
 *                  given digest type.
 *
 * \param md_type   type of digest to search for.
 *
 * \return          The message digest information associated with md_type or
 *                  NULL if not found.
 */
 API_EXPORT
const mpaas_antssm_md_info_t *mpaas_antssm_md_info_from_type(mpaas_antssm_md_type_t md_type);

/**
 * \brief           Initialize a md_context (as NONE)
 *                  This should always be called first.
 *                  Prepares the context for mpaas_antssm_md_setup() or mpaas_antssm_md_free().
 */
void mpaas_antssm_md_init(mpaas_antssm_md_context_t *ctx);

/**
 * \brief           Free and clear the internal structures of ctx.
 *                  Can be called at any time after mpaas_antssm_md_init().
 *                  Mandatory once mpaas_antssm_md_setup() has been called.
 */
void mpaas_antssm_md_free(mpaas_antssm_md_context_t *ctx);

/**
 * \brief           Select MD to use and allocate internal structures.
 *                  Should be called after mpaas_antssm_md_init() or mpaas_antssm_md_free().
 *                  Makes it necessary to call mpaas_antssm_md_free() later.
 *
 * \param ctx       Context to set up.
 * \param md_info   Message digest to use.
 * \param hmac      0 to save some memory if HMAC will not be used,
 *                  non-zero is HMAC is going to be used with this context.
 *
 * \returns         \c 0 on success,
 *                  \c ANTSSM_ERR_MD_BAD_INPUT_DATA on parameter failure,
 *                  \c ANTSSM_ERR_MD_ALLOC_FAILED memory allocation failure.
 */
int mpaas_antssm_md_setup(mpaas_antssm_md_context_t *ctx, const mpaas_antssm_md_info_t *md_info, int hmac);

/**
 * \brief           Clone the state of an MD context
 *
 * \note            The two contexts must have been setup to the same type
 *                  (cloning from SHA-256 to SHA-512 make no sense).
 *
 * \warning         Only clones the MD state, not the HMAC state! (for now)
 *
 * \param dst       The destination context
 * \param src       The context to be cloned
 *
 * \return          \c 0 on success,
 *                  \c ANTSSM_ERR_MD_BAD_INPUT_DATA on parameter failure.
 */
int mpaas_antssm_md_clone(mpaas_antssm_md_context_t *dst,
                    const mpaas_antssm_md_context_t *src);

/**
 * \brief           Returns the size of the message digest output.
 *
 * \param md_info   message digest info
 *
 * \return          size of the message digest output in bytes.
 */
size_t mpaas_antssm_md_get_size(const mpaas_antssm_md_info_t *md_info);

/**
 * \brief           Returns the type of the message digest output.
 *
 * \param md_info   message digest info
 *
 * \return          type of the message digest output.
 */
mpaas_antssm_md_type_t mpaas_antssm_md_get_type(const mpaas_antssm_md_info_t *md_info);

/**
 * \brief           Returns the name of the message digest output.
 *
 * \param md_info   message digest info
 *
 * \return          name of the message digest output.
 */
const char *mpaas_antssm_md_get_name(const mpaas_antssm_md_info_t *md_info);

/**
 * \brief           Prepare the context to digest a new message.
 *                  Generally called after mpaas_antssm_md_setup() or mpaas_antssm_md_finish().
 *                  Followed by mpaas_antssm_md_update().
 *
 * \param ctx       generic message digest context.
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_starts(mpaas_antssm_md_context_t *ctx);

/**
 * \brief           Generic message digest process buffer
 *                  Called between mpaas_antssm_md_starts() and mpaas_antssm_md_finish().
 *                  May be called repeatedly.
 *
 * \param ctx       Generic message digest context
 * \param input     buffer holding the  datal
 * \param ilen      length of the input data
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_update(mpaas_antssm_md_context_t *ctx, const unsigned char *input, size_t ilen);

/**
 * \brief           Generic message digest final digest
 *                  Called after mpaas_antssm_md_update().
 *                  Usually followed by mpaas_antssm_md_free() or mpaas_antssm_md_starts().
 *
 * \param ctx       Generic message digest context
 * \param output    Generic message digest checksum result
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_finish(mpaas_antssm_md_context_t *ctx, unsigned char *output);

/**
 * \brief          Output = message_digest( input buffer )
 *
 * \param md_info  message digest info
 * \param input    buffer holding the  data
 * \param ilen     length of the input data
 * \param output   Generic message digest checksum result
 *
 * \returns        0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                 verification fails.
 */
int mpaas_antssm_md(const mpaas_antssm_md_info_t *md_info, const unsigned char *input, size_t ilen,
              unsigned char *output);

#if defined(ANTSSM_FS_IO)

/**
 * \brief          Output = message_digest( file contents )
 *
 * \param md_info  message digest info
 * \param path     input file name
 * \param output   generic message digest checksum result
 *
 * \return         0 if successful,
 *                 ANTSSM_ERR_MD_FILE_IO_ERROR if file input failed,
 *                 ANTSSM_ERR_MD_BAD_INPUT_DATA if md_info was NULL.
 */
int mpaas_antssm_md_file(const mpaas_antssm_md_info_t *md_info, const char *path,
                   unsigned char *output);

#endif /* ANTSSM_FS_IO */

/**
 * \brief           Set HMAC key and prepare to authenticate a new message.
 *                  Usually called after mpaas_antssm_md_setup() or mpaas_antssm_md_hmac_finish().
 *
 * \param ctx       HMAC context
 * \param key       HMAC secret key
 * \param keylen    length of the HMAC key in bytes
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_hmac_starts(mpaas_antssm_md_context_t *ctx, const unsigned char *key,
                          size_t keylen);

/**
 * \brief           Generic HMAC process buffer.
 *                  Called between mpaas_antssm_md_hmac_starts() or mpaas_antssm_md_hmac_reset()
 *                  and mpaas_antssm_md_hmac_finish().
 *                  May be called repeatedly.
 *
 * \param ctx       HMAC context
 * \param input     buffer holding the  data
 * \param ilen      length of the input data
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_hmac_update(mpaas_antssm_md_context_t *ctx, const unsigned char *input,
                          size_t ilen);

/**
 * \brief           Output HMAC.
 *                  Called after mpaas_antssm_md_hmac_update().
 *                  Usually followed by mpaas_antssm_md_hmac_reset(),
 *                  mpaas_antssm_md_hmac_starts(), or mpaas_antssm_md_free().
 *
 * \param ctx       HMAC context
 * \param output    Generic HMAC checksum result
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_hmac_finish(mpaas_antssm_md_context_t *ctx, unsigned char *output);

/**
 * \brief           Prepare to authenticate a new message with the same key.
 *                  Called after mpaas_antssm_md_hmac_finish() and before
 *                  mpaas_antssm_md_hmac_update().
 *
 * \param ctx       HMAC context to be reset
 *
 * \returns         0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                  verification fails.
 */
int mpaas_antssm_md_hmac_reset(mpaas_antssm_md_context_t *ctx);

/**
 * \brief          Output = Generic_HMAC( hmac key, input buffer )
 *
 * \param md_info  message digest info
 * \param key      HMAC secret key
 * \param keylen   length of the HMAC key in bytes
 * \param input    buffer holding the  data
 * \param ilen     length of the input data
 * \param output   Generic HMAC-result
 *
 * \returns        0 on success, ANTSSM_ERR_MD_BAD_INPUT_DATA if parameter
 *                 verification fails.
 */
int mpaas_antssm_md_hmac(const mpaas_antssm_md_info_t *md_info, const unsigned char *key, size_t keylen,
                   const unsigned char *input, size_t ilen,
                   unsigned char *output);

#if defined(ANTSSM_SM3_C)

/*for now, just use for sm3*/
int mpaas_antssm_md_set_block_num(unsigned int num);

#endif

/* Internal use */
int mpaas_antssm_md_process(mpaas_antssm_md_context_t *ctx, const unsigned char *data);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_MD_H */
