/**
 * \file ecdh.h
 *
 * \brief Elliptic curve Diffie-Hellman
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
#ifndef ANTSSM_ECDH_H
#define ANTSSM_ECDH_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "ecp.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * When importing from an EC key, select if it is our key or the peer's key
 */
typedef enum {
    ANTSSM_ECDH_OURS,
    ANTSSM_ECDH_THEIRS,
} mpaas_antssm_ecdh_side;

/**
 * \brief           ECDH context structure
 */
typedef struct {
    mpaas_antssm_ecp_group_t grp;      /*!<  elliptic curve used                           */
    mpaas_antssm_mpi_t d;              /*!<  our secret value (private key)                */
    mpaas_antssm_ecp_point_t Q;        /*!<  our public value (public key)                 */
    mpaas_antssm_ecp_point_t Qp;       /*!<  peer's public value (public key)              */
    mpaas_antssm_mpi_t z;              /*!<  shared secret                                 */
    int point_format;   /*!<  format for point export in TLS messages       */
    mpaas_antssm_ecp_point_t Vi;       /*!<  blinding value (for later)                    */
    mpaas_antssm_ecp_point_t Vf;       /*!<  un-blinding value (for later)                 */
    mpaas_antssm_mpi_t _d;             /*!<  previous d (for later)                        */
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_ecdh_context_t;

/**
 * \brief           Generate a public key.
 *                  Raw function that only does the core computation.
 *
 * \param grp       ECP group
 * \param d         Destination MPI (secret exponent, aka private key)
 * \param Q         Destination point (public key)
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
int mpaas_antssm_ecdh_gen_public(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_mpi_t *d, mpaas_antssm_ecp_point_t *Q,
                           int (*f_rng)(void *, unsigned char *, size_t),
                           void *p_rng);

/**
 * \brief           Compute shared secret
 *                  Raw function that only does the core computation.
 *
 * \param grp       ECP group
 * \param z         Destination MPI (shared secret)
 * \param Q         Public key from other party
 * \param d         Our secret exponent (private key)
 * \param f_rng     RNG function (see notes)
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 *
 * \note            If f_rng is not NULL, it is used to implement
 *                  countermeasures against potential elaborate timing
 *                  attacks, see \c mpaas_antssm_ecp_mul() for details.
 */
int mpaas_antssm_ecdh_compute_shared(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_mpi_t *z,
                               const mpaas_antssm_ecp_point_t *Q, const mpaas_antssm_mpi_t *d,
                               int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng);

/**
 * \brief           Initialize context
 *
 * \param ctx       Context to initialize
 */
void mpaas_antssm_ecdh_init(mpaas_antssm_ecdh_context_t *ctx);

/**
 * \brief           Free context
 *
 * \param ctx       Context to free
 */
void mpaas_antssm_ecdh_free(mpaas_antssm_ecdh_context_t *ctx);

/**
 * \brief           Generate a public key and a TLS ServerKeyExchange payload.
 *                  (First function used by a TLS server for ECDHE.)
 *
 * \param ctx       ECDH context
 * \param olen      number of chars written
 * \param buf       destination buffer
 * \param blen      length of buffer
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \note            This function assumes that ctx->grp has already been
 *                  properly set (for example using mpaas_antssm_ecp_group_load).
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_make_params(mpaas_antssm_ecdh_context_t *ctx, size_t *olen,
                            unsigned char *buf, size_t blen,
                            int (*f_rng)(void *, unsigned char *, size_t),
                            void *p_rng);

/**
 * \brief           Parse and procress a TLS ServerKeyExhange payload.
 *                  (First function used by a TLS client for ECDHE.)
 *
 * \param ctx       ECDH context
 * \param buf       pointer to start of input buffer
 * \param end       one past end of buffer
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_read_params(mpaas_antssm_ecdh_context_t *ctx,
                            const unsigned char **buf, const unsigned char *end);

/**
 * \brief           Setup an ECDH context from an EC key.
 *                  (Used by clients and servers in place of the
 *                  ServerKeyEchange for static ECDH: import ECDH parameters
 *                  from a certificate's EC key information.)
 *
 * \param ctx       ECDH constext to set
 * \param key       EC key to use
 * \param side      Is it our key (1) or the peer's key (0) ?
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_get_params(mpaas_antssm_ecdh_context_t *ctx, const mpaas_antssm_ecp_keypair_t *key,
                           mpaas_antssm_ecdh_side side);

/**
 * \brief           Generate a public key and a TLS ClientKeyExchange payload.
 *                  (Second function used by a TLS client for ECDH(E).)
 *
 * \param ctx       ECDH context
 * \param olen      number of bytes actually written
 * \param buf       destination buffer
 * \param blen      size of destination buffer
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_make_public(mpaas_antssm_ecdh_context_t *ctx, size_t *olen,
                            unsigned char *buf, size_t blen,
                            int (*f_rng)(void *, unsigned char *, size_t),
                            void *p_rng);

/**
 * \brief           Parse and process a TLS ClientKeyExchange payload.
 *                  (Second function used by a TLS server for ECDH(E).)
 *
 * \param ctx       ECDH context
 * \param buf       start of input buffer
 * \param blen      length of input buffer
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_read_public(mpaas_antssm_ecdh_context_t *ctx,
                            const unsigned char *buf, size_t blen);

/**
 * \brief           Derive and export the shared secret.
 *                  (Last function used by both TLS client en servers.)
 *
 * \param ctx       ECDH context
 * \param olen      number of bytes written
 * \param buf       destination buffer
 * \param blen      buffer length
 * \param f_rng     RNG function, see notes for \c mpaas_antssm_ecdh_compute_shared()
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful, or an ANTSSM_ERR_ECP_XXX error code
 */
int mpaas_antssm_ecdh_calc_secret(mpaas_antssm_ecdh_context_t *ctx, size_t *olen,
                            unsigned char *buf, size_t blen,
                            int (*f_rng)(void *, unsigned char *, size_t),
                            void *p_rng);

#ifdef __cplusplus
}
#endif

#endif /* ecdh.h */
