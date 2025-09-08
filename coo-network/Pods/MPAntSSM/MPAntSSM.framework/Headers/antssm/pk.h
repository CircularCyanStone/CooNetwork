/**
 * \file pk.h
 *
 * \brief Public Key abstraction layer
 */
/*
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

#ifndef ANTSSM_PK_H
#define ANTSSM_PK_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "antssm/md.h"

#if defined(ANTSSM_RSA_C)
#include "antssm/rsa.h"
#endif

#if defined(ANTSSM_ECP_C)
#include "antssm/ecp.h"
#endif

#if defined(ANTSSM_ECDSA_C)
#include "antssm/ecdsa.h"
#endif

#if defined(ANTSSM_USE_PSA_CRYPTO)
#include "psa/crypto.h"
#endif

#if (defined(__ARMCC_VERSION) || defined(_MSC_VER)) && \
    !defined(inline) && !defined(__cplusplus)
#define inline __inline
#endif

#define ANTSSM_ERR_PK_H2B_IN_LEN_NOT_EVEN  0x4001
#define ANTSSM_ERR_PK_HASH_LEN_NOT_32     -0x4000  /**< Use the hash naked, but hash len is not 32 byte. */
#define ANTSSM_ERR_PK_ALLOC_FAILED        -0x3F80  /**< Memory allocation failed. */
#define ANTSSM_ERR_PK_TYPE_MISMATCH       -0x3F00  /**< Type mismatch, eg attempt to encrypt with an ECDSA key */
#define ANTSSM_ERR_PK_BAD_INPUT_DATA      -0x3E80  /**< Bad input parameters to function. */
#define ANTSSM_ERR_PK_FILE_IO_ERROR       -0x3E00  /**< Read/write of file failed. */
#define ANTSSM_ERR_PK_KEY_INVALID_VERSION -0x3D80  /**< Unsupported key version */
#define ANTSSM_ERR_PK_KEY_INVALID_FORMAT  -0x3D00  /**< Invalid key tag or value. */
#define ANTSSM_ERR_PK_UNKNOWN_PK_ALG      -0x3C80  /**< Key algorithm is unsupported (only RSA and EC are supported). */
#define ANTSSM_ERR_PK_PASSWORD_REQUIRED   -0x3C00  /**< Private key password can't be empty. */
#define ANTSSM_ERR_PK_PASSWORD_MISMATCH   -0x3B80  /**< Given private key password does not allow for correct decryption. */
#define ANTSSM_ERR_PK_INVALID_PUBKEY      -0x3B00  /**< The pubkey tag or value is invalid (only RSA and EC are supported). */
#define ANTSSM_ERR_PK_INVALID_ALG         -0x3A80  /**< The algorithm tag or value is invalid. */
#define ANTSSM_ERR_PK_UNKNOWN_NAMED_CURVE -0x3A00  /**< Elliptic curve is unsupported (only NIST curves are supported). */
#define ANTSSM_ERR_PK_FEATURE_UNAVAILABLE -0x3980  /**< Unavailable feature, e.g. RSA disabled for RSA key. */
#define ANTSSM_ERR_PK_SIG_LEN_MISMATCH    -0x3900  /**< The buffer contains a valid signature followed by more data. */

/* ANTSSM_ERR_PK_HW_ACCEL_FAILED is deprecated and should not be used. */
#define ANTSSM_ERR_PK_HW_ACCEL_FAILED     -0x3880  /**< PK hardware accelerator failed. */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          Public key types
 */
typedef enum {
    ANTSSM_PK_NONE = 0,
    ANTSSM_PK_RSA,
    ANTSSM_PK_ECKEY,
    ANTSSM_PK_ECKEY_DH,
    ANTSSM_PK_ECDSA,
    ANTSSM_PK_RSA_ALT,
    ANTSSM_PK_RSASSA_PSS,
    ANTSSM_PK_OPAQUE,
    ANTSSM_PK_SM2,
    ANTSSM_PK_THRESHOLD_SM2,
    ANTSSM_PK_SYMMETRIC,
} mpaas_antssm_pk_type_t;

/**
 * \brief           Options for RSASSA-PSS signature verification.
 *                  See \c mpaas_antssm_rsa_rsassa_pss_verify_ext()
 */
typedef struct mpaas_antssm_pk_rsassa_pss_options {
    mpaas_antssm_md_type_t mgf1_hash_id;
    int expected_salt_len;

} mpaas_antssm_pk_rsassa_pss_options;

/**
 * \brief           Maximum size of a signature made by mpaas_antssm_pk_sign().
 */
/* We need to set ANTSSM_PK_SIGNATURE_MAX_SIZE to the maximum signature
 * size among the supported signature types. Do it by starting at 0,
 * then incrementally increasing to be large enough for each supported
 * signature mechanism.
 *
 * The resulting value can be 0, for example if ANTSSM_ECDH_C is enabled
 * (which allows the pk module to be included) but neither ANTSSM_ECDSA_C
 * nor ANTSSM_RSA_C nor any opaque signature mechanism (PSA or RSA_ALT).
 */
#define ANTSSM_PK_SIGNATURE_MAX_SIZE 0

#if (defined(ANTSSM_RSA_C) || defined(ANTSSM_PK_RSA_ALT_SUPPORT)) && \
    ANTSSM_MPI_MAX_SIZE > ANTSSM_PK_SIGNATURE_MAX_SIZE
/* For RSA, the signature can be as large as the mpi module allows.
 * For RSA_ALT, the signature size is not necessarily tied to what the
 * mpi module can do, but in the absence of any specific setting,
 * we use that (rsa_alt_sign_wrap in pk_wrap will check). */
#undef ANTSSM_PK_SIGNATURE_MAX_SIZE
#define ANTSSM_PK_SIGNATURE_MAX_SIZE ANTSSM_MPI_MAX_SIZE
#endif

#if defined(ANTSSM_ECDSA_C) && \
    ANTSSM_ECDSA_MAX_LEN > ANTSSM_PK_SIGNATURE_MAX_SIZE
/* For ECDSA, the ecdsa module exports a constant for the maximum
 * signature size. */
#undef ANTSSM_PK_SIGNATURE_MAX_SIZE
#define ANTSSM_PK_SIGNATURE_MAX_SIZE ANTSSM_ECDSA_MAX_LEN
#endif

#if defined(ANTSSM_USE_PSA_CRYPTO)
#if PSA_SIGNATURE_MAX_SIZE > ANTSSM_PK_SIGNATURE_MAX_SIZE
/* PSA_SIGNATURE_MAX_SIZE is the maximum size of a signature made
 * through the PSA API in the PSA representation. */
#undef ANTSSM_PK_SIGNATURE_MAX_SIZE
#define ANTSSM_PK_SIGNATURE_MAX_SIZE PSA_SIGNATURE_MAX_SIZE
#endif

#if PSA_VENDOR_ECDSA_SIGNATURE_MAX_SIZE + 11 > ANTSSM_PK_SIGNATURE_MAX_SIZE
/* The Mbed TLS representation is different for ECDSA signatures:
 * PSA uses the raw concatenation of r and s,
 * whereas Mbed TLS uses the ASN.1 representation (SEQUENCE of two INTEGERs).
 * Add the overhead of ASN.1: up to (1+2) + 2 * (1+2+1) for the
 * types, lengths (represented by up to 2 bytes), and potential leading
 * zeros of the INTEGERs and the SEQUENCE. */
#undef ANTSSM_PK_SIGNATURE_MAX_SIZE
#define ANTSSM_PK_SIGNATURE_MAX_SIZE ( PSA_VENDOR_ECDSA_SIGNATURE_MAX_SIZE + 11 )
#endif
#endif /* defined(ANTSSM_USE_PSA_CRYPTO) */

/**
 * \brief           Types for interfacing with the debug module
 */
typedef enum {
    ANTSSM_PK_DEBUG_NONE = 0,
    ANTSSM_PK_DEBUG_MPI,
    ANTSSM_PK_DEBUG_ECP,
} mpaas_antssm_pk_debug_type;

/**
 * \brief           Item to send to the debug module
 */
typedef struct mpaas_antssm_pk_debug_item {
    mpaas_antssm_pk_debug_type type;
    const char *name;
    void *value;
} mpaas_antssm_pk_debug_item;

/** Maximum number of item send for debugging, plus 1 */
#define ANTSSM_PK_DEBUG_MAX_ITEMS 3

/**
 * \brief           Public key information and operations
 */
typedef struct mpaas_antssm_pk_info_t mpaas_antssm_pk_info_t;

/**
 * \brief           Public key container
 */
typedef struct mpaas_antssm_pk_context_t {
    const mpaas_antssm_pk_info_t *pk_info; /**< Public key information         */
    void *pk_ctx;  /**< Underlying public key context  */
} mpaas_antssm_pk_context_t;

#if defined(ANTSSM_ECDSA_C) && defined(ANTSSM_ECP_RESTARTABLE)
/**
 * \brief           Context for resuming operations
 */
typedef struct
{
    const mpaas_antssm_pk_info_t *   pk_info; /**< Public key information         */
    void *                      rs_ctx;  /**< Underlying restart context     */
} mpaas_antssm_pk_restart_ctx;
#else /* ANTSSM_ECDSA_C && ANTSSM_ECP_RESTARTABLE */
/* Now we can declare functions that take a pointer to that */
typedef void mpaas_antssm_pk_restart_ctx;
#endif /* ANTSSM_ECDSA_C && ANTSSM_ECP_RESTARTABLE */

#if defined(ANTSSM_RSA_C)

/**
 * Quick access to an RSA context inside a PK context.
 *
 * \warning You must make sure the PK context actually holds an RSA context
 * before using this function!
 */
static inline mpaas_antssm_rsa_context_t *mpaas_antssm_pk_rsa(const mpaas_antssm_pk_context_t pk)
{
    return ((mpaas_antssm_rsa_context_t *) (pk).pk_ctx);
}

#endif /* ANTSSM_RSA_C */

#if defined(ANTSSM_ECP_C)

/**
 * Quick access to an EC context inside a PK context.
 *
 * \warning You must make sure the PK context actually holds an EC context
 * before using this function!
 */
static inline mpaas_antssm_ecp_keypair_t *mpaas_antssm_pk_ec(const mpaas_antssm_pk_context_t pk)
{
    return ((mpaas_antssm_ecp_keypair_t *) (pk).pk_ctx);
}

#endif /* ANTSSM_ECP_C */

#if defined(ANTSSM_PK_RSA_ALT_SUPPORT)

/**
 * \brief           Types for RSA-alt abstraction
 */
typedef int (*mpaas_antssm_pk_rsa_alt_decrypt_func)(void *ctx, int mode, size_t *olen,
                                              const unsigned char *input,
                                              unsigned char *output,
                                              size_t output_max_len);

typedef int (*mpaas_antssm_pk_rsa_alt_sign_func)(void *ctx,
                                           int (*f_rng)(void *, unsigned char *,
                                                        size_t), void *p_rng,
                                           int mode, mpaas_antssm_md_type_t md_alg,
                                           unsigned int hashlen,
                                           const unsigned char *hash,
                                           unsigned char *sig);

typedef size_t (*mpaas_antssm_pk_rsa_alt_key_len_func)(void *ctx);

#endif /* ANTSSM_PK_RSA_ALT_SUPPORT */

/**
 * \brief           Convert the hex format string to bin format
 *
 * \param 
 *
 * \return          Length of the bin bytes.
 */
API_EXPORT
int h2b_with_inlen(unsigned char *hex_in, uint32_t hex_inlen, unsigned char *bin_out);

/**
 * \brief           Return information associated with the given PK type
 *
 * \param pk_type   PK type to search for.
 *
 * \return          The PK info associated with the type or NULL if not found.
 */
const mpaas_antssm_pk_info_t *mpaas_antssm_pk_info_from_type(mpaas_antssm_pk_type_t pk_type);

/**
 * \brief           Initialize a #mpaas_antssm_pk_context_t (as NONE).
 *
 * \param ctx       The context to initialize.
 *                  This must not be \c NULL.
 */
void mpaas_antssm_pk_init(mpaas_antssm_pk_context_t *ctx);

/**
 * \brief           Free the components of a #mpaas_antssm_pk_context.
 *
 * \param ctx       The context to clear. It must have been initialized.
 *                  If this is \c NULL, this function does nothing.
 *
 * \note            For contexts that have been set up with
 *                  mpaas_antssm_pk_setup_opaque(), this does not free the underlying
 *                  PSA key and you still need to call psa_destroy_key()
 *                  independently if you want to destroy that key.
 */
void mpaas_antssm_pk_free(mpaas_antssm_pk_context_t *ctx);

#if defined(ANTSSM_ECDSA_C) && defined(ANTSSM_ECP_RESTARTABLE)
/**
 * \brief           Initialize a restart context
 *
 * \param ctx       The context to initialize.
 *                  This must not be \c NULL.
 */
void mpaas_antssm_pk_restart_init( mpaas_antssm_pk_restart_ctx *ctx );

/**
 * \brief           Free the components of a restart context
 *
 * \param ctx       The context to clear. It must have been initialized.
 *                  If this is \c NULL, this function does nothing.
 */
void mpaas_antssm_pk_restart_free( mpaas_antssm_pk_restart_ctx *ctx );
#endif /* ANTSSM_ECDSA_C && ANTSSM_ECP_RESTARTABLE */

/**
 * \brief           Initialize a PK context with the information given
 *                  and allocates the type-specific PK subcontext.
 *
 * \param ctx       Context to initialize. It must not have been set
 *                  up yet (type #ANTSSM_PK_NONE).
 * \param info      Information to use
 *
 * \return          0 on success,
 *                  ANTSSM_ERR_PK_BAD_INPUT_DATA on invalid input,
 *                  ANTSSM_ERR_PK_ALLOC_FAILED on allocation failure.
 *
 * \note            For contexts holding an RSA-alt key, use
 *                  \c mpaas_antssm_pk_setup_rsa_alt() instead.
 */
int mpaas_antssm_pk_setup(mpaas_antssm_pk_context_t *ctx, const mpaas_antssm_pk_info_t *info);

#if defined(ANTSSM_USE_PSA_CRYPTO)
/**
 * \brief           Initialize a PK context to wrap a PSA key.
 *
 * \note            This function replaces mpaas_antssm_pk_setup() for contexts
 *                  that wrap a (possibly opaque) PSA key instead of
 *                  storing and manipulating the key material directly.
 *
 * \param ctx       The context to initialize. It must be empty (type NONE).
 * \param key       The PSA key to wrap, which must hold an ECC key pair
 *                  (see notes below).
 *
 * \note            The wrapped key must remain valid as long as the
 *                  wrapping PK context is in use, that is at least between
 *                  the point this function is called and the point
 *                  mpaas_antssm_pk_free() is called on this context. The wrapped
 *                  key might then be independently used or destroyed.
 *
 * \note            This function is currently only available for ECC key
 *                  pairs (that is, ECC keys containing private key material).
 *                  Support for other key types may be added later.
 *
 * \return          \c 0 on success.
 * \return          #ANTSSM_ERR_PK_BAD_INPUT_DATA on invalid input
 *                  (context already used, invalid key handle).
 * \return          #ANTSSM_ERR_PK_FEATURE_UNAVAILABLE if the key is not an
 *                  ECC key pair.
 * \return          #ANTSSM_ERR_PK_ALLOC_FAILED on allocation failure.
 */
int mpaas_antssm_pk_setup_opaque( mpaas_antssm_pk_context_t *ctx, const psa_key_handle_t key );
#endif /* ANTSSM_USE_PSA_CRYPTO */

#if defined(ANTSSM_PK_RSA_ALT_SUPPORT)

/**
 * \brief           Initialize an RSA-alt context
 *
 * \param ctx       Context to initialize. It must not have been set
 *                  up yet (type #ANTSSM_PK_NONE).
 * \param key       RSA key pointer
 * \param decrypt_func  Decryption function
 * \param sign_func     Signing function
 * \param key_len_func  Function returning key length in bytes
 *
 * \return          0 on success, or ANTSSM_ERR_PK_BAD_INPUT_DATA if the
 *                  context wasn't already initialized as RSA_ALT.
 *
 * \note            This function replaces \c mpaas_antssm_pk_setup() for RSA-alt.
 */
int mpaas_antssm_pk_setup_rsa_alt(mpaas_antssm_pk_context_t *ctx, void *key,
                            mpaas_antssm_pk_rsa_alt_decrypt_func decrypt_func,
                            mpaas_antssm_pk_rsa_alt_sign_func sign_func,
                            mpaas_antssm_pk_rsa_alt_key_len_func key_len_func);

#endif /* ANTSSM_PK_RSA_ALT_SUPPORT */

/**
 * \brief           Get the size in bits of the underlying key
 *
 * \param ctx       The context to query. It must have been initialized.
 *
 * \return          Key size in bits, or 0 on error
 */
size_t mpaas_antssm_pk_get_bitlen(const mpaas_antssm_pk_context_t *ctx);

/**
 * \brief           Get the length in bytes of the underlying key
 *
 * \param ctx       The context to query. It must have been initialized.
 *
 * \return          Key length in bytes, or 0 on error
 */
static inline size_t mpaas_antssm_pk_get_len(const mpaas_antssm_pk_context_t *ctx)
{
    return ((mpaas_antssm_pk_get_bitlen(ctx) + 7) / 8);
}

/**
 * \brief           Tell if a context can do the operation given by type
 *
 * \param ctx       The context to query. It must have been initialized.
 * \param type      The desired type.
 *
 * \return          1 if the context can do operations on the given type.
 * \return          0 if the context cannot do the operations on the given
 *                  type. This is always the case for a context that has
 *                  been initialized but not set up, or that has been
 *                  cleared with mpaas_antssm_pk_free().
 */
int mpaas_antssm_pk_can_do(const mpaas_antssm_pk_context_t *ctx, mpaas_antssm_pk_type_t type);

/**
 * \brief           Verify signature (including padding if relevant).
 *
 * \param ctx       The PK context to use. It must have been set up.
 * \param md_alg    Hash algorithm used (see notes)
 * \param hash      Hash of the message to sign
 * \param hash_len  Hash length or 0 (see notes)
 * \param sig       Signature to verify
 * \param sig_len   Signature length
 *
 * \return          0 on success (signature is valid),
 *                  #ANTSSM_ERR_PK_SIG_LEN_MISMATCH if there is a valid
 *                  signature in sig but its length is less than \p siglen,
 *                  or a specific error code.
 *
 * \note            For RSA keys, the default padding type is PKCS#1 v1.5.
 *                  Use \c mpaas_antssm_pk_verify_ext( ANTSSM_PK_RSASSA_PSS, ... )
 *                  to verify RSASSA_PSS signatures.
 *
 * \note            If hash_len is 0, then the length associated with md_alg
 *                  is used instead, or an error returned if it is invalid.
 *
 * \note            md_alg may be ANTSSM_MD_NONE, only if hash_len != 0
 */
int mpaas_antssm_pk_verify(mpaas_antssm_pk_context_t *ctx, mpaas_antssm_md_type_t md_alg,
                     const unsigned char *hash, size_t hash_len,
                     const unsigned char *sig, size_t sig_len);

/**
 * \brief           Restartable version of \c mpaas_antssm_pk_verify()
 *
 * \note            Performs the same job as \c mpaas_antssm_pk_verify(), but can
 *                  return early and restart according to the limit set with
 *                  \c mpaas_antssm_ecp_set_max_ops() to reduce blocking for ECC
 *                  operations. For RSA, same as \c mpaas_antssm_pk_verify().
 *
 * \param ctx       The PK context to use. It must have been set up.
 * \param md_alg    Hash algorithm used (see notes)
 * \param hash      Hash of the message to sign
 * \param hash_len  Hash length or 0 (see notes)
 * \param sig       Signature to verify
 * \param sig_len   Signature length
 * \param rs_ctx    Restart context (NULL to disable restart)
 *
 * \return          See \c mpaas_antssm_pk_verify(), or
 * \return          #ANTSSM_ERR_ECP_IN_PROGRESS if maximum number of
 *                  operations was reached: see \c mpaas_antssm_ecp_set_max_ops().
 */
int mpaas_antssm_pk_verify_restartable(mpaas_antssm_pk_context_t *ctx,
                                 mpaas_antssm_md_type_t md_alg,
                                 const unsigned char *hash, size_t hash_len,
                                 const unsigned char *sig, size_t sig_len,
                                 mpaas_antssm_pk_restart_ctx *rs_ctx);

/**
 * \brief           Verify signature, with options.
 *                  (Includes verification of the padding depending on type.)
 *
 * \param type      Signature type (inc. possible padding type) to verify
 * \param options   Pointer to type-specific options, or NULL
 * \param ctx       The PK context to use. It must have been set up.
 * \param md_alg    Hash algorithm used (see notes)
 * \param hash      Hash of the message to sign
 * \param hash_len  Hash length or 0 (see notes)
 * \param sig       Signature to verify
 * \param sig_len   Signature length
 *
 * \return          0 on success (signature is valid),
 *                  #ANTSSM_ERR_PK_TYPE_MISMATCH if the PK context can't be
 *                  used for this type of signatures,
 *                  #ANTSSM_ERR_PK_SIG_LEN_MISMATCH if there is a valid
 *                  signature in sig but its length is less than \p siglen,
 *                  or a specific error code.
 *
 * \note            If hash_len is 0, then the length associated with md_alg
 *                  is used instead, or an error returned if it is invalid.
 *
 * \note            md_alg may be ANTSSM_MD_NONE, only if hash_len != 0
 *
 * \note            If type is ANTSSM_PK_RSASSA_PSS, then options must point
 *                  to a mpaas_antssm_pk_rsassa_pss_options structure,
 *                  otherwise it must be NULL.
 */
int mpaas_antssm_pk_verify_ext(mpaas_antssm_pk_type_t type, const void *options,
                         mpaas_antssm_pk_context_t *ctx, mpaas_antssm_md_type_t md_alg,
                         const unsigned char *hash, size_t hash_len,
                         const unsigned char *sig, size_t sig_len);

/**
 * \brief           Make signature, including padding if relevant.
 *
 * \param ctx       The PK context to use. It must have been set up
 *                  with a private key.
 * \param md_alg    Hash algorithm used (see notes)
 * \param hash      Hash of the message to sign
 * \param hash_len  Hash length or 0 (see notes)
 * \param sig       Place to write the signature.
 *                  It must have enough room for the signature.
 *                  #ANTSSM_PK_SIGNATURE_MAX_SIZE is always enough.
 *                  You may use a smaller buffer if it is large enough
 *                  given the key type.
 * \param sig_len   On successful return,
 *                  the number of bytes written to \p sig.
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 on success, or a specific error code.
 *
 * \note            For RSA keys, the default padding type is PKCS#1 v1.5.
 *                  There is no interface in the PK module to make RSASSA-PSS
 *                  signatures yet.
 *
 * \note            If hash_len is 0, then the length associated with md_alg
 *                  is used instead, or an error returned if it is invalid.
 *
 * \note            For RSA, md_alg may be ANTSSM_MD_NONE if hash_len != 0.
 *                  For ECDSA, md_alg may never be ANTSSM_MD_NONE.
 */
int mpaas_antssm_pk_sign(mpaas_antssm_pk_context_t *ctx, mpaas_antssm_md_type_t md_alg,
                   const unsigned char *hash, size_t hash_len,
                   unsigned char *sig, size_t *sig_len,
                   int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Restartable version of \c mpaas_antssm_pk_sign()
 *
 * \note            Performs the same job as \c mpaas_antssm_pk_sign(), but can
 *                  return early and restart according to the limit set with
 *                  \c mpaas_antssm_ecp_set_max_ops() to reduce blocking for ECC
 *                  operations. For RSA, same as \c mpaas_antssm_pk_sign().
 *
 * \param ctx       The PK context to use. It must have been set up
 *                  with a private key.
 * \param md_alg    Hash algorithm used (see notes for mpaas_antssm_pk_sign())
 * \param hash      Hash of the message to sign
 * \param hash_len  Hash length or 0 (see notes for mpaas_antssm_pk_sign())
 * \param sig       Place to write the signature.
 *                  It must have enough room for the signature.
 *                  #ANTSSM_PK_SIGNATURE_MAX_SIZE is always enough.
 *                  You may use a smaller buffer if it is large enough
 *                  given the key type.
 * \param sig_len   On successful return,
 *                  the number of bytes written to \p sig.
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 * \param rs_ctx    Restart context (NULL to disable restart)
 *
 * \return          See \c mpaas_antssm_pk_sign().
 * \return          #ANTSSM_ERR_ECP_IN_PROGRESS if maximum number of
 *                  operations was reached: see \c mpaas_antssm_ecp_set_max_ops().
 */
int mpaas_antssm_pk_sign_restartable(mpaas_antssm_pk_context_t *ctx,
                               mpaas_antssm_md_type_t md_alg,
                               const unsigned char *hash, size_t hash_len,
                               unsigned char *sig, size_t *sig_len,
                               int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng,
                               mpaas_antssm_pk_restart_ctx *rs_ctx);

/**
 * \brief           Decrypt message (including padding if relevant).
 *
 * \param ctx       The PK context to use. It must have been set up
 *                  with a private key.
 * \param input     Input to decrypt
 * \param ilen      Input size
 * \param output    Decrypted output
 * \param olen      Decrypted message length
 * \param osize     Size of the output buffer
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \note            For RSA keys, the default padding type is PKCS#1 v1.5.
 *
 * \return          0 on success, or a specific error code.
 */
int mpaas_antssm_pk_decrypt(mpaas_antssm_pk_context_t *ctx,
                      const unsigned char *input, size_t ilen,
                      unsigned char *output, size_t *olen, size_t osize,
                      int (*f_rng)(void *, unsigned char *, size_t),
                      void *p_rng);

/**
 * \brief           Encrypt message (including padding if relevant).
 *
 * \param ctx       The PK context to use. It must have been set up.
 * \param input     Message to encrypt
 * \param ilen      Message size
 * \param output    Encrypted output
 * \param olen      Encrypted output length
 * \param osize     Size of the output buffer
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \note            For RSA keys, the default padding type is PKCS#1 v1.5.
 *
 * \return          0 on success, or a specific error code.
 */
int mpaas_antssm_pk_encrypt(mpaas_antssm_pk_context_t *ctx,
                      const unsigned char *input, size_t ilen,
                      unsigned char *output, size_t *olen, size_t osize,
                      int (*f_rng)(void *, unsigned char *, size_t),
                      void *p_rng);

/**
 * \brief           Check if a public-private pair of keys matches.
 *
 * \param pub       Context holding a public key.
 * \param prv       Context holding a private (and public) key.
 *
 * \return          \c 0 on success (keys were checked and match each other).
 * \return          #ANTSSM_ERR_PK_FEATURE_UNAVAILABLE if the keys could not
 *                  be checked - in that case they may or may not match.
 * \return          #ANTSSM_ERR_PK_BAD_INPUT_DATA if a context is invalid.
 * \return          Another non-zero value if the keys do not match.
 */
int mpaas_antssm_pk_check_pair(const mpaas_antssm_pk_context_t *pub,
                         const mpaas_antssm_pk_context_t *prv);

/**
 * \brief           Export debug information
 *
 * \param ctx       The PK context to use. It must have been initialized.
 * \param items     Place to write debug items
 *
 * \return          0 on success or ANTSSM_ERR_PK_BAD_INPUT_DATA
 */
int
mpaas_antssm_pk_debug(const mpaas_antssm_pk_context_t *ctx, mpaas_antssm_pk_debug_item *items);

/**
 * \brief           Access the type name
 *
 * \param ctx       The PK context to use. It must have been initialized.
 *
 * \return          Type name on success, or "invalid PK"
 */
const char *mpaas_antssm_pk_get_name(const mpaas_antssm_pk_context_t *ctx);

/**
 * \brief           Get the key type
 *
 * \param ctx       The PK context to use. It must have been initialized.
 *
 * \return          Type on success.
 * \return          #ANTSSM_PK_NONE for a context that has not been set up.
 */
mpaas_antssm_pk_type_t mpaas_antssm_pk_get_type(const mpaas_antssm_pk_context_t *ctx);

#if defined(ANTSSM_PK_WRITE_C)

/**
 * \brief           Write a private key to a PKCS#8 DER structure
 *                  Note: data is written at the end of the buffer! Use the
 *                        return value to determine where you should start
 *                        using the buffer
 *
 * \param ctx       PK context which must contain a valid private key.
 * \param buf       buffer to write to
 * \param size      size of the buffer
 *
 * \return          length of data written if successful, or a specific
 *                  error code
 */
int mpaas_antssm_pk_write_key_der(mpaas_antssm_pk_context_t *ctx,
                            unsigned char *password, size_t password_len,
                            unsigned char *buf, size_t size);
                            
/**
 * \brief           Write a private key by a raw format
 *                  Note: data is written at the end of the buffer! Use the
 *                        return value to determine where you should start
 *                        using the buffer
 *
 * \param ctx       PK context which must contain a valid private key.
 * \param buf       buffer to write to
 * \param size      size of the buffer
 *
 * \return          length of data written if successful, or a specific
 *                  error code
 */
int mpaas_antssm_pk_write_EC_key_raw(mpaas_antssm_pk_context_t *ctx,
                            unsigned char *password, size_t password_len,
                            unsigned char *buf, size_t size);

/**
 * \brief           Write a public key to a SubjectPublicKeyInfo DER structure
 *                  Note: data is written at the end of the buffer! Use the
 *                        return value to determine where you should start
 *                        using the buffer
 *
 * \param ctx       PK context which must contain a valid public or private key.
 * \param buf       buffer to write to
 * \param size      size of the buffer
 *
 * \return          length of data written if successful, or a specific
 *                  error code
 */
int mpaas_antssm_pk_write_pubkey_der(mpaas_antssm_pk_context_t *ctx, unsigned char *buf,
                               size_t size);
                               
int mpaas_antssm_pk_write_pubkey_raw(mpaas_antssm_pk_context_t *ctx, unsigned char *buf,
                               size_t size);

#if defined(ANTSSM_PEM_WRITE_C)

/**
 * \brief           Write a public key to a PEM string
 *
 * \param ctx       PK context which must contain a valid public or private key.
 * \param buf       Buffer to write to. The output includes a
 *                  terminating null byte.
 * \param size      Size of the buffer in bytes.
 *
 * \return          0 if successful, or a specific error code
 */
int mpaas_antssm_pk_write_pubkey_pem(mpaas_antssm_pk_context_t *ctx, unsigned char *buf,
                               size_t size);

/**
 * \brief           Write a private key to a PKCS#1 or SEC1 PEM string
 *
 * \param ctx       PK context which must contain a valid private key.
 * \param buf       Buffer to write to. The output includes a
 *                  terminating null byte.
 * \param size      Size of the buffer in bytes.
 *
 * \return          0 if successful, or a specific error code
 */
int mpaas_antssm_pk_write_key_pem(mpaas_antssm_pk_context_t *key,
                            unsigned char *password, size_t password_len,
                            unsigned char *buf, size_t size);

#endif /* ANTSSM_PEM_WRITE_C */
#endif /* ANTSSM_PK_WRITE_C */

#if defined(ANTSSM_PK_PARSE_C)
/** \ingroup pk_module */
/**
 * \brief           Parse a private key in PEM or DER format
 *
 * \param ctx       The PK context to fill. It must have been initialized
 *                  but not set up.
 * \param key       Input buffer to parse.
 *                  The buffer must contain the input exactly, with no
 *                  extra trailing material. For PEM, the buffer must
 *                  contain a null-terminated string.
 * \param keylen    Size of \b key in bytes.
 *                  For PEM data, this includes the terminating null byte,
 *                  so \p keylen must be equal to `strlen(key) + 1`.
 * \param pwd       Optional password for decryption.
 *                  Pass \c NULL if expecting a non-encrypted key.
 *                  Pass a string of \p pwdlen bytes if expecting an encrypted
 *                  key; a non-encrypted key will also be accepted.
 *                  The empty password is not supported.
 * \param pwdlen    Size of the password in bytes.
 *                  Ignored if \p pwd is \c NULL.
 *
 * \note            On entry, ctx must be empty, either freshly initialised
 *                  with mpaas_antssm_pk_init() or reset with mpaas_antssm_pk_free(). If you need a
 *                  specific key type, check the result with mpaas_antssm_pk_can_do().
 *
 * \note            The key is also checked for correctness.
 *
 * \return          0 if successful, or a specific PK or PEM error code
 */
int mpaas_antssm_pk_parse_key(mpaas_antssm_pk_context_t *ctx,
                        const unsigned char *key, size_t keylen,
                        const unsigned char *pwd, size_t pwdlen);

/** \ingroup pk_module */
/**
 * \brief           Parse a public key in PEM or DER format
 *
 * \param ctx       The PK context to fill. It must have been initialized
 *                  but not set up.
 * \param key       Input buffer to parse.
 *                  The buffer must contain the input exactly, with no
 *                  extra trailing material. For PEM, the buffer must
 *                  contain a null-terminated string.
 * \param keylen    Size of \b key in bytes.
 *                  For PEM data, this includes the terminating null byte,
 *                  so \p keylen must be equal to `strlen(key) + 1`.
 *
 * \note            On entry, ctx must be empty, either freshly initialised
 *                  with mpaas_antssm_pk_init() or reset with mpaas_antssm_pk_free(). If you need a
 *                  specific key type, check the result with mpaas_antssm_pk_can_do().
 *
 * \note            The key is also checked for correctness.
 *
 * \return          0 if successful, or a specific PK or PEM error code
 */
int mpaas_antssm_pk_parse_public_key(mpaas_antssm_pk_context_t *ctx,
                               const unsigned char *key, size_t keylen);

#if defined(ANTSSM_FS_IO)
/** \ingroup pk_module */
/**
 * \brief           Load and parse a private key
 *
 * \param ctx       The PK context to fill. It must have been initialized
 *                  but not set up.
 * \param path      filename to read the private key from
 * \param password  Optional password to decrypt the file.
 *                  Pass \c NULL if expecting a non-encrypted key.
 *                  Pass a null-terminated string if expecting an encrypted
 *                  key; a non-encrypted key will also be accepted.
 *                  The empty password is not supported.
 *
 * \note            On entry, ctx must be empty, either freshly initialised
 *                  with mpaas_antssm_pk_init() or reset with mpaas_antssm_pk_free(). If you need a
 *                  specific key type, check the result with mpaas_antssm_pk_can_do().
 *
 * \note            The key is also checked for correctness.
 *
 * \return          0 if successful, or a specific PK or PEM error code
 */
int mpaas_antssm_pk_parse_keyfile( mpaas_antssm_pk_context_t *ctx,
                      const char *path, const char *password );

/** \ingroup pk_module */
/**
 * \brief           Load and parse a public key
 *
 * \param ctx       The PK context to fill. It must have been initialized
 *                  but not set up.
 * \param path      filename to read the public key from
 *
 * \note            On entry, ctx must be empty, either freshly initialised
 *                  with mpaas_antssm_pk_init() or reset with mpaas_antssm_pk_free(). If
 *                  you need a specific key type, check the result with
 *                  mpaas_antssm_pk_can_do().
 *
 * \note            The key is also checked for correctness.
 *
 * \return          0 if successful, or a specific PK or PEM error code
 */
int mpaas_antssm_pk_parse_public_keyfile( mpaas_antssm_pk_context_t *ctx, const char *path );
#endif /* ANTSSM_FS_IO */
#endif /* ANTSSM_PK_PARSE_C */

/*
 * Internal module functions. You probably do not want to use these unless you
 * know you do.
 */
#if defined(ANTSSM_FS_IO)

int mpaas_antssm_pk_load_file(const char *path, unsigned char **buf, size_t *n);

#endif

#if defined(ANTSSM_USE_PSA_CRYPTO)
/**
 * \brief           Turn an EC key into an opaque one.
 *
 * \warning         This is a temporary utility function for tests. It might
 *                  change or be removed at any time without notice.
 *
 * \note            Only ECDSA keys are supported so far. Signing with the
 *                  specified hash is the only allowed use of that key.
 *
 * \param pk        Input: the EC key to import to a PSA key.
 *                  Output: a PK context wrapping that PSA key.
 * \param handle    Output: a PSA key handle.
 *                  It's the caller's responsibility to call
 *                  psa_destroy_key() on that handle after calling
 *                  mpaas_antssm_pk_free() on the PK context.
 * \param hash_alg  The hash algorithm to allow for use with that key.
 *
 * \return          \c 0 if successful.
 * \return          An Mbed TLS error code otherwise.
 */
int mpaas_antssm_pk_wrap_as_opaque( mpaas_antssm_pk_context_t *pk,
                               psa_key_handle_t *handle,
                               psa_algorithm_t hash_alg );
#endif /* ANTSSM_USE_PSA_CRYPTO */

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_PK_H */
