/**
 * \file pk_internal.h
 *
 * \brief Public Key abstraction layer: wrapper functions
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

#ifndef ANTSSM_PK_WRAP_H
#define ANTSSM_PK_WRAP_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "antssm/config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "pk.h"
#include "white_box.h"
#include "sm2.h"

struct mpaas_antssm_pk_info_t {
    /** Public key type */
    mpaas_antssm_pk_type_t type;

    /** Type name */
    const char *name;

    /** Get key size in bits */
    size_t (*get_bitlen)(const void *);

    /** Tell if the context implements this type (e.g. ECKEY can do ECDSA) */
    int (*can_do)(mpaas_antssm_pk_type_t type);

    /** Verify signature */
    int (*verify_func)(void *ctx, mpaas_antssm_md_type_t md_alg,
                       const unsigned char *hash, size_t hash_len,
                       const unsigned char *sig, size_t sig_len);

    /** Make signature */
    int (*sign_func)(void *ctx, mpaas_antssm_md_type_t md_alg,
                     const unsigned char *hash, size_t hash_len,
                     unsigned char *sig, size_t *sig_len,
                     int (*f_rng)(void *, unsigned char *, size_t),
                     void *p_rng);

#if defined(ANTSSM_ECDSA_C) && defined(ANTSSM_ECP_RESTARTABLE)
    /** Verify signature (restartable) */
    int (*verify_rs_func)( void *ctx, mpaas_antssm_md_type_t md_alg,
                           const unsigned char *hash, size_t hash_len,
                           const unsigned char *sig, size_t sig_len,
                           void *rs_ctx );

    /** Make signature (restartable) */
    int (*sign_rs_func)( void *ctx, mpaas_antssm_md_type_t md_alg,
                         const unsigned char *hash, size_t hash_len,
                         unsigned char *sig, size_t *sig_len,
                         int (*f_rng)(void *, unsigned char *, size_t),
                         void *p_rng, void *rs_ctx );
#endif /* ANTSSM_ECDSA_C && ANTSSM_ECP_RESTARTABLE */

    /** Decrypt message */
    int (*decrypt_func)(void *ctx, const unsigned char *input, size_t ilen,
                        unsigned char *output, size_t *olen, size_t osize,
                        int (*f_rng)(void *, unsigned char *, size_t),
                        void *p_rng);

    /** Encrypt message */
    int (*encrypt_func)(void *ctx, const unsigned char *input, size_t ilen,
                        unsigned char *output, size_t *olen, size_t osize,
                        int (*f_rng)(void *, unsigned char *, size_t),
                        void *p_rng);

    /** Check public-private key pair */
    int (*check_pair_func)(const void *pub, const void *prv);

    /** Allocate a new context */
    void *(*ctx_alloc_func)(void);

    /** Free the given context */
    void (*ctx_free_func)(void *ctx);

#if defined(ANTSSM_ECDSA_C) && defined(ANTSSM_ECP_RESTARTABLE)
    /** Allocate the restart context */
    void * (*rs_alloc_func)( void );

    /** Free the restart context */
    void (*rs_free_func)( void *rs_ctx );
#endif /* ANTSSM_ECDSA_C && ANTSSM_ECP_RESTARTABLE */

    /** Interface with the debug module */
    void (*debug_func)(const void *ctx, mpaas_antssm_pk_debug_item *items);

};

#if defined(ANTSSM_PK_RSA_ALT_SUPPORT)
/* Container for RSA-alt */
typedef struct {
    void *key;
    mpaas_antssm_pk_rsa_alt_decrypt_func decrypt_func;
    mpaas_antssm_pk_rsa_alt_sign_func sign_func;
    mpaas_antssm_pk_rsa_alt_key_len_func key_len_func;
} mpaas_antssm_rsa_alt_context;
#endif

#if defined(ANTSSM_RSA_C)
extern const mpaas_antssm_pk_info_t mpaas_antssm_rsa_info;
#endif

#if defined(ANTSSM_ECP_C)
extern const mpaas_antssm_pk_info_t mpaas_antssm_eckey_info;
extern const mpaas_antssm_pk_info_t mpaas_antssm_eckeydh_info;
#endif

#if defined(ANTSSM_ECDSA_C)
extern const mpaas_antssm_pk_info_t mpaas_antssm_ecdsa_info;
#endif

#if defined(ANTSSM_SM2_C)
extern const mpaas_antssm_pk_info_t mpaas_antssm_sm2_info;

typedef struct mpaas_antssm_pk_threshold_sm2_context {
    unsigned char name[16];
    unsigned char password[16];
    mpaas_antssm_sm2_context_t ctx;
    mpaas_antssm_white_box_context_t *white_box;
    mpaas_antssm_antcrypto_key_t *mpaas_antssm_key;
} mpaas_antssm_pk_threshold_sm2_context_t;
extern const mpaas_antssm_pk_info_t mpaas_antssm_threshold_sm2_info;
#endif

#if defined(ANTSSM_PK_RSA_ALT_SUPPORT)
extern const mpaas_antssm_pk_info_t mpaas_antssm_rsa_alt_info;
#endif

#if defined(ANTSSM_USE_PSA_CRYPTO)
extern const mpaas_antssm_pk_info_t mpaas_antssm_pk_opaque_info;
#endif

#endif /* ANTSSM_PK_WRAP_H */
