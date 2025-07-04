/**
 * \file ecdsa.h
 *
 * \brief Elliptic curve DSA
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
#ifndef ANTSSM_ECDSA_H
#define ANTSSM_ECDSA_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "ecp.h"
#include "md.h"

/*
 * RFC 4492 page 20:
 *
 *     Ecdsa-Sig-Value ::= SEQUENCE {
 *         r       INTEGER,
 *         s       INTEGER
 *     }
 *
 * Size is at most
 *    1 (tag) + 1 (len) + 1 (initial 0) + ECP_MAX_BYTES for each of r and s,
 *    twice that + 1 (tag) + 2 (len) for the sequence
 * (assuming ECP_MAX_BYTES is less than 126 for r and s,
 * and less than 124 (total len <= 255) for the sequence)
 */
#if ANTSSM_ECP_MAX_BYTES > 124
#error "ANTSSM_ECP_MAX_BYTES bigger than expected, please fix ANTSSM_ECDSA_MAX_LEN"
#endif

/** Maximum size of an ECDSA signature in bytes */
#define ANTSSM_ECDSA_MAX_LEN  ( 3 + 2 * ( 3 + ANTSSM_ECP_MAX_BYTES ) )

/**
 * \brief           ECDSA context structure
 */
typedef mpaas_antssm_ecp_keypair_t mpaas_antssm_ecdsa_context_t;

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          This function checks whether a given group can be used
 *                 for ECDSA.
 *
 * \param gid      The ECP group ID to check.
 *
 * \return         \c 1 if the group can be used, \c 0 otherwise
 */
int mpaas_antssm_ecdsa_can_do(mpaas_antssm_ecp_group_id gid);

/**
 * \brief           Compute ECDSA signature of a previously hashed message
 *
 * \note            The deterministic version is usually prefered.
 *
 * \param grp       ECP group
 * \param r         First output integer
 * \param s         Second output integer
 * \param d         Private signing key
 * \param buf       Message hash
 * \param blen      Length of buf
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \note            If the bitlength of the message hash is larger than the
 *                  bitlength of the group order, then the hash is truncated as
 *                  prescribed by SEC1 4.1.3 step 5.
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
int mpaas_antssm_ecdsa_sign(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_mpi_t *r, mpaas_antssm_mpi_t *s,
                      const mpaas_antssm_mpi_t *d, const unsigned char *buf, size_t blen,
                      int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Verify ECDSA signature of a previously hashed message
 *
 * \param grp       ECP group
 * \param buf       Message hash
 * \param blen      Length of buf
 * \param Q         Public key to use for verification
 * \param r         First integer of the signature
 * \param s         Second integer of the signature
 *
 * \note            If the bitlength of the message hash is larger than the
 *                  bitlength of the group order, then the hash is truncated as
 *                  prescribed by SEC1 4.1.4 step 3.
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA if signature is invalid
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
int mpaas_antssm_ecdsa_verify(mpaas_antssm_ecp_group_t *grp,
                        const unsigned char *buf, size_t blen,
                        const mpaas_antssm_ecp_point_t *Q, const mpaas_antssm_mpi_t *r, const mpaas_antssm_mpi_t *s);

/**
 * \brief           Compute ECDSA signature and write it to buffer,
 *                  serialized as defined in RFC 4492 page 20.
 *                  (Not thread-safe to use same context in multiple threads)
 *
 * \note            The deterministic version (RFC 6979) is used if
 *                  ANTSSM_ECDSA_DETERMINISTIC is defined.
 *
 * \param ctx       ECDSA context
 * \param md_alg    Algorithm that was used to hash the message
 * \param hash      Message hash
 * \param hlen      Length of hash
 * \param sig       Buffer that will hold the signature
 * \param slen      Length of the signature written
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \note            The "sig" buffer must be at least as large as twice the
 *                  size of the curve used, plus 9 (eg. 73 bytes if a 256-bit
 *                  curve is used). ANTSSM_ECDSA_MAX_LEN is always safe.
 *
 * \note            If the bitlength of the message hash is larger than the
 *                  bitlength of the group order, then the hash is truncated as
 *                  prescribed by SEC1 4.1.3 step 5.
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX, ANTSSM_ERR_MPI_XXX or
 *                  ANTSSM_ERR_ASN1_XXX error code
 */
int mpaas_antssm_ecdsa_write_signature(mpaas_antssm_ecdsa_context_t *ctx, mpaas_antssm_md_type_t md_alg,
                                 const unsigned char *hash, size_t hlen,
                                 unsigned char *sig, size_t *slen,
                                 int (*f_rng)(void *, unsigned char *, size_t),
                                 void *p_rng);

/**
 * \brief           Read and verify an ECDSA signature
 *
 * \param ctx       ECDSA context
 * \param hash      Message hash
 * \param hlen      Size of hash
 * \param sig       Signature to read and verify
 * \param slen      Size of sig
 *
 * \note            If the bitlength of the message hash is larger than the
 *                  bitlength of the group order, then the hash is truncated as
 *                  prescribed by SEC1 4.1.4 step 3.
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA if signature is invalid,
 *                  ANTSSM_ERR_ECP_SIG_LEN_MISMATCH if the signature is
 *                  valid but its actual length is less than siglen,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_ERR_MPI_XXX error code
 */
int mpaas_antssm_ecdsa_read_signature(mpaas_antssm_ecdsa_context_t *ctx,
                                const unsigned char *hash, size_t hlen,
                                const unsigned char *sig, size_t slen);

/**
 * \brief           Generate an ECDSA keypair on the given curve
 *
 * \param ctx       ECDSA context in which the keypair should be stored
 * \param gid       Group (elliptic curve) to use. One of the various
 *                  ANTSSM_ECP_DP_XXX macros depending on configuration.
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 on success, or a ANTSSM_ERR_ECP_XXX code.
 */
int mpaas_antssm_ecdsa_genkey(mpaas_antssm_ecdsa_context_t *ctx, mpaas_antssm_ecp_group_id gid,
                        int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Set an ECDSA context from an EC key pair
 *
 * \param ctx       ECDSA context to set
 * \param key       EC key to use
 *
 * \return          0 on success, or a ANTSSM_ERR_ECP_XXX code.
 */
int mpaas_antssm_ecdsa_from_keypair(mpaas_antssm_ecdsa_context_t *ctx, const mpaas_antssm_ecp_keypair_t *key);

/**
 * \brief           Initialize context
 *
 * \param ctx       Context to initialize
 */
void mpaas_antssm_ecdsa_init(mpaas_antssm_ecdsa_context_t *ctx);

/**
 * \brief           Free context
 *
 * \param ctx       Context to free
 */
void mpaas_antssm_ecdsa_free(mpaas_antssm_ecdsa_context_t *ctx);

#ifdef __cplusplus
}
#endif

#endif /* ecdsa.h */
