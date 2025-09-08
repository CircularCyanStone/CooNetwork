/**
 * \file rsa.h
 *
 * \brief The RSA public-key cryptosystem
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
#ifndef ANTSSM_RSA_H
#define ANTSSM_RSA_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "mpi.h"
#include "md.h"
#include "log.h"

#if defined(ANTSSM_THREADING_C)
#include "threading.h"
#endif

/*
 * RSA Error codes
 */
#define ANTSSM_ERR_RSA_BAD_INPUT_DATA                    -0x4080  /**< Bad input parameters to function. */
#define ANTSSM_ERR_RSA_INVALID_PADDING                   -0x4100  /**< Input data contains invalid padding and is rejected. */
#define ANTSSM_ERR_RSA_KEY_GEN_FAILED                    -0x4180  /**< Something failed during generation of a key. */
#define ANTSSM_ERR_RSA_KEY_CHECK_FAILED                  -0x4200  /**< Key failed to pass the library's validity check. */
#define ANTSSM_ERR_RSA_PUBLIC_FAILED                     -0x4280  /**< The public key operation failed. */
#define ANTSSM_ERR_RSA_PRIVATE_FAILED                    -0x4300  /**< The private key operation failed. */
#define ANTSSM_ERR_RSA_VERIFY_FAILED                     -0x4380  /**< The PKCS#1 verification failed. */
#define ANTSSM_ERR_RSA_OUTPUT_TOO_LARGE                  -0x4400  /**< The output buffer for decryption is not large enough. */
#define ANTSSM_ERR_RSA_RNG_FAILED                        -0x4480  /**< The random generator failed to generate non-zeros. */

/*
 * RSA constants
 */
#define ANTSSM_RSA_PUBLIC      0
#define ANTSSM_RSA_PRIVATE     1

#define ANTSSM_RSA_PKCS_V15    0
#define ANTSSM_RSA_PKCS_V21    1

#define ANTSSM_RSA_SIGN        1
#define ANTSSM_RSA_CRYPT       2

#define ANTSSM_RSA_SALT_LEN_ANY    -1

/*
 * The above constants may be used even if the RSA module is compile out,
 * eg for alternative (PKCS#11) RSA implemenations in the PK layers.
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          RSA context structure
 */
typedef struct {
    int ver;                    /*!<  always 0          */
    size_t len;                 /*!<  size(N) in chars  */

    mpaas_antssm_mpi_t N;                      /*!<  public modulus    */
    mpaas_antssm_mpi_t E;                      /*!<  public exponent   */

    mpaas_antssm_mpi_t D;                      /*!<  private exponent  */
    mpaas_antssm_mpi_t P;                      /*!<  1st prime factor  */
    mpaas_antssm_mpi_t Q;                      /*!<  2nd prime factor  */
    mpaas_antssm_mpi_t DP;                     /*!<  D % (P - 1)       */
    mpaas_antssm_mpi_t DQ;                     /*!<  D % (Q - 1)       */
    mpaas_antssm_mpi_t QP;                     /*!<  1 / (Q % P)       */

    mpaas_antssm_mpi_t RN;                     /*!<  cached R^2 mod N  */
    mpaas_antssm_mpi_t RP;                     /*!<  cached R^2 mod P  */
    mpaas_antssm_mpi_t RQ;                     /*!<  cached R^2 mod Q  */

    mpaas_antssm_mpi_t Vi;                     /*!<  cached blinding value     */
    mpaas_antssm_mpi_t Vf;                     /*!<  cached un-blinding value  */

    int padding;                /*!<  ANTSSM_RSA_PKCS_V15 for 1.5 padding and
                                      ANTSSM_RSA_PKCS_v21 for OAEP/PSS         */
    int hash_id;                /*!<  Hash identifier of mpaas_antssm_md_type_t as
                                      specified in the mpaas_antssm_md.h header file
                                      for the EME-OAEP and EMSA-PSS
                                      encoding                          */
#if defined(ANTSSM_THREADING_C)
    mpaas_antssm_threading_mutex_t mutex;    /*!<  Thread-safety mutex       */
#endif
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_rsa_context_t;

/**
 * \brief          Initialize an RSA context
 *
 *                 Note: Set padding to ANTSSM_RSA_PKCS_V21 for the RSAES-OAEP
 *                 encryption scheme and the RSASSA-PSS signature scheme.
 *
 * \param ctx      RSA context to be initialized
 * \param padding  ANTSSM_RSA_PKCS_V15 or ANTSSM_RSA_PKCS_V21
 * \param hash_id  ANTSSM_RSA_PKCS_V21 hash identifier
 *
 * \note           The hash_id parameter is actually ignored
 *                 when using ANTSSM_RSA_PKCS_V15 padding.
 *
 * \note           Choice of padding mode is strictly enforced for private key
 *                 operations, since there might be security concerns in
 *                 mixing padding modes. For public key operations it's merely
 *                 a default value, which can be overriden by calling specific
 *                 rsa_rsaes_xxx or rsa_rsassa_xxx functions.
 *
 * \note           The chosen hash is always used for OEAP encryption.
 *                 For PSS signatures, it's always used for making signatures,
 *                 but can be overriden (and always is, if set to
 *                 ANTSSM_MD_NONE) for verifying them.
 */
void mpaas_antssm_rsa_init(mpaas_antssm_rsa_context_t *ctx,
                     int padding,
                     int hash_id);

/**
 * \brief          This function imports a set of core parameters into an
 *                 RSA context.
 *
 * \note           This function can be called multiple times for successive
 *                 imports, if the parameters are not simultaneously present.
 *
 *                 Any sequence of calls to this function should be followed
 *                 by a call to mpaas_antssm_rsa_complete(), which checks and
 *                 completes the provided information to a ready-for-use
 *                 public or private RSA key.
 *
 * \note           See mpaas_antssm_rsa_complete() for more information on which
 *                 parameters are necessary to set up a private or public
 *                 RSA key.
 *
 * \note           The imported parameters are copied and need not be preserved
 *                 for the lifetime of the RSA context being set up.
 *
 * \param ctx      The initialized RSA context to store the parameters in.
 * \param N        The RSA modulus. This may be \c NULL.
 * \param P        The first prime factor of \p N. This may be \c NULL.
 * \param Q        The second prime factor of \p N. This may be \c NULL.
 * \param D        The private exponent. This may be \c NULL.
 * \param E        The public exponent. This may be \c NULL.
 *
 * \return         \c 0 on success.
 * \return         A non-zero error code on failure.
 */
int mpaas_antssm_rsa_import(mpaas_antssm_rsa_context_t *ctx,
                      const mpaas_antssm_mpi_t *N,
                      const mpaas_antssm_mpi_t *P, const mpaas_antssm_mpi_t *Q,
                      const mpaas_antssm_mpi_t *D, const mpaas_antssm_mpi_t *E);

/**
 * \brief          This function imports core RSA parameters, in raw big-endian
 *                 binary format, into an RSA context.
 *
 * \note           This function can be called multiple times for successive
 *                 imports, if the parameters are not simultaneously present.
 *
 *                 Any sequence of calls to this function should be followed
 *                 by a call to mpaas_antssm_rsa_complete(), which checks and
 *                 completes the provided information to a ready-for-use
 *                 public or private RSA key.
 *
 * \note           See mpaas_antssm_rsa_complete() for more information on which
 *                 parameters are necessary to set up a private or public
 *                 RSA key.
 *
 * \note           The imported parameters are copied and need not be preserved
 *                 for the lifetime of the RSA context being set up.
 *
 * \param ctx      The initialized RSA context to store the parameters in.
 * \param N        The RSA modulus. This may be \c NULL.
 * \param N_len    The Byte length of \p N; it is ignored if \p N == NULL.
 * \param P        The first prime factor of \p N. This may be \c NULL.
 * \param P_len    The Byte length of \p P; it ns ignored if \p P == NULL.
 * \param Q        The second prime factor of \p N. This may be \c NULL.
 * \param Q_len    The Byte length of \p Q; it is ignored if \p Q == NULL.
 * \param D        The private exponent. This may be \c NULL.
 * \param D_len    The Byte length of \p D; it is ignored if \p D == NULL.
 * \param E        The public exponent. This may be \c NULL.
 * \param E_len    The Byte length of \p E; it is ignored if \p E == NULL.
 *
 * \return         \c 0 on success.
 * \return         A non-zero error code on failure.
 */
int mpaas_antssm_rsa_import_raw(mpaas_antssm_rsa_context_t *ctx,
                          unsigned char const *N, size_t N_len,
                          unsigned char const *P, size_t P_len,
                          unsigned char const *Q, size_t Q_len,
                          unsigned char const *D, size_t D_len,
                          unsigned char const *E, size_t E_len);

/**
 * \brief          This function exports the core parameters of an RSA key.
 *
 *                 If this function runs successfully, the non-NULL buffers
 *                 pointed to by \p N, \p P, \p Q, \p D, and \p E are fully
 *                 written, with additional unused space filled leading by
 *                 zero Bytes.
 *
 *                 Possible reasons for returning
 *                 #ANTSSM_ERR_PLATFORM_FEATURE_UNSUPPORTED:<ul>
 *                 <li>An alternative RSA implementation is in use, which
 *                 stores the key externally, and either cannot or should
 *                 not export it into RAM.</li>
 *                 <li>A SW or HW implementation might not support a certain
 *                 deduction. For example, \p P, \p Q from \p N, \p D,
 *                 and \p E if the former are not part of the
 *                 implementation.</li></ul>
 *
 *                 If the function fails due to an unsupported operation,
 *                 the RSA context stays intact and remains usable.
 *
 * \param ctx      The initialized RSA context.
 * \param N        The MPI to hold the RSA modulus.
 *                 This may be \c NULL if this field need not be exported.
 * \param P        The MPI to hold the first prime factor of \p N.
 *                 This may be \c NULL if this field need not be exported.
 * \param Q        The MPI to hold the second prime factor of \p N.
 *                 This may be \c NULL if this field need not be exported.
 * \param D        The MPI to hold the private exponent.
 *                 This may be \c NULL if this field need not be exported.
 * \param E        The MPI to hold the public exponent.
 *                 This may be \c NULL if this field need not be exported.
 *
 * \return         \c 0 on success.
 * \return         #ANTSSM_ERR_PLATFORM_FEATURE_UNSUPPORTED if exporting the
 *                 requested parameters cannot be done due to missing
 *                 functionality or because of security policies.
 * \return         A non-zero return code on any other failure.
 *
 */
int mpaas_antssm_rsa_export(const mpaas_antssm_rsa_context_t *ctx,
                      mpaas_antssm_mpi_t *N, mpaas_antssm_mpi_t *P, mpaas_antssm_mpi_t *Q,
                      mpaas_antssm_mpi_t *D, mpaas_antssm_mpi_t *E);

/**
 * \brief          This function exports core parameters of an RSA key
 *                 in raw big-endian binary format.
 *
 *                 If this function runs successfully, the non-NULL buffers
 *                 pointed to by \p N, \p P, \p Q, \p D, and \p E are fully
 *                 written, with additional unused space filled leading by
 *                 zero Bytes.
 *
 *                 Possible reasons for returning
 *                 #ANTSSM_ERR_PLATFORM_FEATURE_UNSUPPORTED:<ul>
 *                 <li>An alternative RSA implementation is in use, which
 *                 stores the key externally, and either cannot or should
 *                 not export it into RAM.</li>
 *                 <li>A SW or HW implementation might not support a certain
 *                 deduction. For example, \p P, \p Q from \p N, \p D,
 *                 and \p E if the former are not part of the
 *                 implementation.</li></ul>
 *                 If the function fails due to an unsupported operation,
 *                 the RSA context stays intact and remains usable.
 *
 * \note           The length parameters are ignored if the corresponding
 *                 buffer pointers are NULL.
 *
 * \param ctx      The initialized RSA context.
 * \param N        The Byte array to store the RSA modulus,
 *                 or \c NULL if this field need not be exported.
 * \param N_len    The size of the buffer for the modulus.
 * \param P        The Byte array to hold the first prime factor of \p N,
 *                 or \c NULL if this field need not be exported.
 * \param P_len    The size of the buffer for the first prime factor.
 * \param Q        The Byte array to hold the second prime factor of \p N,
 *                 or \c NULL if this field need not be exported.
 * \param Q_len    The size of the buffer for the second prime factor.
 * \param D        The Byte array to hold the private exponent,
 *                 or \c NULL if this field need not be exported.
 * \param D_len    The size of the buffer for the private exponent.
 * \param E        The Byte array to hold the public exponent,
 *                 or \c NULL if this field need not be exported.
 * \param E_len    The size of the buffer for the public exponent.
 *
 * \return         \c 0 on success.
 * \return         #ANTSSM_ERR_PLATFORM_FEATURE_UNSUPPORTED if exporting the
 *                 requested parameters cannot be done due to missing
 *                 functionality or because of security policies.
 * \return         A non-zero return code on any other failure.
 */
int mpaas_antssm_rsa_export_raw(const mpaas_antssm_rsa_context_t *ctx,
                          unsigned char *N, size_t N_len,
                          unsigned char *P, size_t P_len,
                          unsigned char *Q, size_t Q_len,
                          unsigned char *D, size_t D_len,
                          unsigned char *E, size_t E_len);

/**
 * \brief          This function exports CRT parameters of a private RSA key.
 *
 * \note           Alternative RSA implementations not using CRT-parameters
 *                 internally can implement this function based on
 *                 mpaas_antssm_rsa_deduce_opt().
 *
 * \param ctx      The initialized RSA context.
 * \param DP       The MPI to hold \c D modulo `P-1`,
 *                 or \c NULL if it need not be exported.
 * \param DQ       The MPI to hold \c D modulo `Q-1`,
 *                 or \c NULL if it need not be exported.
 * \param QP       The MPI to hold modular inverse of \c Q modulo \c P,
 *                 or \c NULL if it need not be exported.
 *
 * \return         \c 0 on success.
 * \return         A non-zero error code on failure.
 *
 */
int mpaas_antssm_rsa_export_crt(const mpaas_antssm_rsa_context_t *ctx,
                          mpaas_antssm_mpi_t *DP, mpaas_antssm_mpi_t *DQ, mpaas_antssm_mpi_t *QP);

/**
 * \brief          This function completes an RSA context from
 *                 a set of imported core parameters.
 *
 *                 To setup an RSA public key, precisely \p N and \p E
 *                 must have been imported.
 *
 *                 To setup an RSA private key, sufficient information must
 *                 be present for the other parameters to be derivable.
 *
 *                 The default implementation supports the following:
 *                 <ul><li>Derive \p P, \p Q from \p N, \p D, \p E.</li>
 *                 <li>Derive \p N, \p D from \p P, \p Q, \p E.</li></ul>
 *                 Alternative implementations need not support these.
 *
 *                 If this function runs successfully, it guarantees that
 *                 the RSA context can be used for RSA operations without
 *                 the risk of failure or crash.
 *
 * \warning        This function need not perform consistency checks
 *                 for the imported parameters. In particular, parameters that
 *                 are not needed by the implementation might be silently
 *                 discarded and left unchecked. To check the consistency
 *                 of the key material, see mpaas_antssm_rsa_check_privkey().
 *
 * \param ctx      The initialized RSA context holding imported parameters.
 *
 * \return         \c 0 on success.
 * \return         #ANTSSM_ERR_RSA_BAD_INPUT_DATA if the attempted derivations
 *                 failed.
 *
 */
int mpaas_antssm_rsa_complete(mpaas_antssm_rsa_context_t *ctx);

/**
 * \brief          Set padding for an already initialized RSA context
 *                 See \c mpaas_antssm_rsa_init() for details.
 *
 * \param ctx      RSA context to be set
 * \param padding  ANTSSM_RSA_PKCS_V15 or ANTSSM_RSA_PKCS_V21
 * \param hash_id  ANTSSM_RSA_PKCS_V21 hash identifier
 */
void
mpaas_antssm_rsa_set_padding(mpaas_antssm_rsa_context_t *ctx, int padding, int hash_id);

/**
 * \brief          This function retrieves the length of RSA modulus in Bytes.
 *
 * \param ctx      The initialized RSA context.
 *
 * \return         The length of the RSA modulus in Bytes.
 *
 */
size_t mpaas_antssm_rsa_get_len(const mpaas_antssm_rsa_context_t *ctx);

/**
 * \brief          Generate an RSA keypair
 *
 * \param ctx      RSA context that will hold the key
 * \param f_rng    RNG function
 * \param p_rng    RNG parameter
 * \param nbits    size of the public key in bits
 * \param exponent public exponent (e.g., 65537)
 *
 * \note           mpaas_antssm_rsa_init() must be called beforehand to setup
 *                 the RSA context.
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 */
int mpaas_antssm_rsa_gen_key(mpaas_antssm_rsa_context_t *ctx,
                       int (*f_rng)(void *, unsigned char *, size_t),
                       void *p_rng,
                       unsigned int nbits, int exponent);

/**
 * \brief          Check a public RSA key
 *
 * \param ctx      RSA context to be checked
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 */
int mpaas_antssm_rsa_check_pubkey(const mpaas_antssm_rsa_context_t *ctx);

/**
 * \brief          Check a private RSA key
 *
 * \param ctx      RSA context to be checked
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 */
int mpaas_antssm_rsa_check_privkey(const mpaas_antssm_rsa_context_t *ctx);

/**
 * \brief          Check a public-private RSA key pair.
 *                 Check each of the contexts, and make sure they match.
 *
 * \param pub      RSA context holding the public key
 * \param prv      RSA context holding the private key
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 */
int mpaas_antssm_rsa_check_pub_priv(const mpaas_antssm_rsa_context_t *pub,
                              const mpaas_antssm_rsa_context_t *prv);

/**
 * \brief          Do an RSA public key operation
 *
 * \param ctx      RSA context
 * \param input    input buffer
 * \param output   output buffer
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           This function does NOT take care of message
 *                 padding. Also, be sure to set input[0] = 0 or ensure that
 *                 input is smaller than N.
 *
 * \note           The input and output buffers must be large
 *                 enough (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_public(mpaas_antssm_rsa_context_t *ctx,
                      const unsigned char *input,
                      unsigned char *output);

/**
 * \brief          Do an RSA private key operation
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for blinding)
 * \param p_rng    RNG parameter
 * \param input    input buffer
 * \param output   output buffer
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The input and output buffers must be large
 *                 enough (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_private(mpaas_antssm_rsa_context_t *ctx,
                       int (*f_rng)(void *, unsigned char *, size_t),
                       void *p_rng,
                       const unsigned char *input,
                       unsigned char *output);

/**
 * \brief          Generic wrapper to perform a PKCS#1 encryption using the
 *                 mode from the context. Add the message padding, then do an
 *                 RSA operation.
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for padding and PKCS#1 v2.1 encoding
 *                               and ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param ilen     contains the plaintext length
 * \param input    buffer holding the data to be encrypted
 * \param output   buffer that will hold the ciphertext
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_pkcs1_encrypt(mpaas_antssm_rsa_context_t *ctx,
                             int (*f_rng)(void *, unsigned char *, size_t),
                             void *p_rng,
                             int mode, size_t ilen,
                             const unsigned char *input,
                             unsigned char *output);

/**
 * \brief          Perform a PKCS#1 v1.5 encryption (RSAES-PKCS1-v1_5-ENCRYPT)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for padding and ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param ilen     contains the plaintext length
 * \param input    buffer holding the data to be encrypted
 * \param output   buffer that will hold the ciphertext
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsaes_pkcs1_v15_encrypt(mpaas_antssm_rsa_context_t *ctx,
                                       int (*f_rng)(void *, unsigned char *,
                                                    size_t),
                                       void *p_rng,
                                       int mode, size_t ilen,
                                       const unsigned char *input,
                                       unsigned char *output);

/**
 * \brief          Perform a PKCS#1 v2.1 OAEP encryption (RSAES-OAEP-ENCRYPT)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for padding and PKCS#1 v2.1 encoding
 *                               and ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param label    buffer holding the custom label to use
 * \param label_len contains the label length
 * \param ilen     contains the plaintext length
 * \param input    buffer holding the data to be encrypted
 * \param output   buffer that will hold the ciphertext
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsaes_oaep_encrypt(mpaas_antssm_rsa_context_t *ctx,
                                  int (*f_rng)(void *, unsigned char *, size_t),
                                  void *p_rng,
                                  int mode,
                                  const unsigned char *label, size_t label_len,
                                  size_t ilen,
                                  const unsigned char *input,
                                  unsigned char *output);

/**
 * \brief          Generic wrapper to perform a PKCS#1 decryption using the
 *                 mode from the context. Do an RSA operation, then remove
 *                 the message padding
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param olen     will contain the plaintext length
 * \param input    buffer holding the encrypted data
 * \param output   buffer that will hold the plaintext
 * \param output_max_len    maximum length of the output buffer
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer length \c output_max_len should be
 *                 as large as the size ctx->len of ctx->N (eg. 128 bytes
 *                 if RSA-1024 is used) to be able to hold an arbitrary
 *                 decrypted message. If it is not large enough to hold
 *                 the decryption of the particular ciphertext provided,
 *                 the function will return ANTSSM_ERR_RSA_OUTPUT_TOO_LARGE.
 *
 * \note           The input buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_pkcs1_decrypt(mpaas_antssm_rsa_context_t *ctx,
                             int (*f_rng)(void *, unsigned char *, size_t),
                             void *p_rng,
                             int mode, size_t *olen,
                             const unsigned char *input,
                             unsigned char *output,
                             size_t output_max_len);

/**
 * \brief          Perform a PKCS#1 v1.5 decryption (RSAES-PKCS1-v1_5-DECRYPT)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param olen     will contain the plaintext length
 * \param input    buffer holding the encrypted data
 * \param output   buffer that will hold the plaintext
 * \param output_max_len    maximum length of the output buffer
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer length \c output_max_len should be
 *                 as large as the size ctx->len of ctx->N (eg. 128 bytes
 *                 if RSA-1024 is used) to be able to hold an arbitrary
 *                 decrypted message. If it is not large enough to hold
 *                 the decryption of the particular ciphertext provided,
 *                 the function will return ANTSSM_ERR_RSA_OUTPUT_TOO_LARGE.
 *
 * \note           The input buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsaes_pkcs1_v15_decrypt(mpaas_antssm_rsa_context_t *ctx,
                                       int (*f_rng)(void *, unsigned char *,
                                                    size_t),
                                       void *p_rng,
                                       int mode, size_t *olen,
                                       const unsigned char *input,
                                       unsigned char *output,
                                       size_t output_max_len);

/**
 * \brief          Perform a PKCS#1 v2.1 OAEP decryption (RSAES-OAEP-DECRYPT)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param label    buffer holding the custom label to use
 * \param label_len contains the label length
 * \param olen     will contain the plaintext length
 * \param input    buffer holding the encrypted data
 * \param output   buffer that will hold the plaintext
 * \param output_max_len    maximum length of the output buffer
 *
 * \return         0 if successful, or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The output buffer length \c output_max_len should be
 *                 as large as the size ctx->len of ctx->N (eg. 128 bytes
 *                 if RSA-1024 is used) to be able to hold an arbitrary
 *                 decrypted message. If it is not large enough to hold
 *                 the decryption of the particular ciphertext provided,
 *                 the function will return ANTSSM_ERR_RSA_OUTPUT_TOO_LARGE.
 *
 * \note           The input buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsaes_oaep_decrypt(mpaas_antssm_rsa_context_t *ctx,
                                  int (*f_rng)(void *, unsigned char *, size_t),
                                  void *p_rng,
                                  int mode,
                                  const unsigned char *label, size_t label_len,
                                  size_t *olen,
                                  const unsigned char *input,
                                  unsigned char *output,
                                  size_t output_max_len);

/**
 * \brief          Generic wrapper to perform a PKCS#1 signature using the
 *                 mode from the context. Do a private RSA operation to sign
 *                 a message digest
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for PKCS#1 v2.1 encoding and for
 *                               ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer that will hold the ciphertext
 *
 * \return         0 if the signing operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 *
 * \note           In case of PKCS#1 v2.1 encoding, see comments on
 * \note           \c mpaas_antssm_rsa_rsassa_pss_sign() for details on md_alg and hash_id.
 */
int mpaas_antssm_rsa_pkcs1_sign(mpaas_antssm_rsa_context_t *ctx,
                          int (*f_rng)(void *, unsigned char *, size_t),
                          void *p_rng,
                          int mode,
                          mpaas_antssm_md_type_t md_alg,
                          unsigned int hashlen,
                          const unsigned char *hash,
                          unsigned char *sig);

/**
 * \brief          Perform a PKCS#1 v1.5 signature (RSASSA-PKCS1-v1_5-SIGN)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer that will hold the ciphertext
 *
 * \return         0 if the signing operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsassa_pkcs1_v15_sign(mpaas_antssm_rsa_context_t *ctx,
                                     int (*f_rng)(void *, unsigned char *,
                                                  size_t),
                                     void *p_rng,
                                     int mode,
                                     mpaas_antssm_md_type_t md_alg,
                                     unsigned int hashlen,
                                     const unsigned char *hash,
                                     unsigned char *sig);

/**
 * \brief          Perform a PKCS#1 v2.1 PSS signature (RSASSA-PSS-SIGN)
 *
 * \param ctx      RSA context
 * \param f_rng    RNG function (Needed for PKCS#1 v2.1 encoding and for
 *                               ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer that will hold the ciphertext
 *
 * \return         0 if the signing operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 *
 * \note           The hash_id in the RSA context is the one used for the
 *                 encoding. md_alg in the function call is the type of hash
 *                 that is encoded. According to RFC 3447 it is advised to
 *                 keep both hashes the same.
 */
int mpaas_antssm_rsa_rsassa_pss_sign(mpaas_antssm_rsa_context_t *ctx,
                               int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng,
                               int mode,
                               mpaas_antssm_md_type_t md_alg,
                               unsigned int hashlen,
                               const unsigned char *hash,
                               unsigned char *sig);

/**
 * \brief          Generic wrapper to perform a PKCS#1 verification using the
 *                 mode from the context. Do a public RSA operation and check
 *                 the message digest
 *
 * \param ctx      points to an RSA public key
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer holding the ciphertext
 *
 * \return         0 if the verify operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 *
 * \note           In case of PKCS#1 v2.1 encoding, see comments on
 *                 \c mpaas_antssm_rsa_rsassa_pss_verify() about md_alg and hash_id.
 */
int mpaas_antssm_rsa_pkcs1_verify(mpaas_antssm_rsa_context_t *ctx,
                            int (*f_rng)(void *, unsigned char *, size_t),
                            void *p_rng,
                            int mode,
                            mpaas_antssm_md_type_t md_alg,
                            unsigned int hashlen,
                            const unsigned char *hash,
                            const unsigned char *sig);

/**
 * \brief          Perform a PKCS#1 v1.5 verification (RSASSA-PKCS1-v1_5-VERIFY)
 *
 * \param ctx      points to an RSA public key
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer holding the ciphertext
 *
 * \return         0 if the verify operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 */
int mpaas_antssm_rsa_rsassa_pkcs1_v15_verify(mpaas_antssm_rsa_context_t *ctx,
                                       int (*f_rng)(void *, unsigned char *,
                                                    size_t),
                                       void *p_rng,
                                       int mode,
                                       mpaas_antssm_md_type_t md_alg,
                                       unsigned int hashlen,
                                       const unsigned char *hash,
                                       const unsigned char *sig);

/**
 * \brief          Perform a PKCS#1 v2.1 PSS verification (RSASSA-PSS-VERIFY)
 *                 (This is the "simple" version.)
 *
 * \param ctx      points to an RSA public key
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param sig      buffer holding the ciphertext
 *
 * \return         0 if the verify operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 *
 * \note           The hash_id in the RSA context is the one used for the
 *                 verification. md_alg in the function call is the type of
 *                 hash that is verified. According to RFC 3447 it is advised to
 *                 keep both hashes the same. If hash_id in the RSA context is
 *                 unset, the md_alg from the function call is used.
 */
int mpaas_antssm_rsa_rsassa_pss_verify(mpaas_antssm_rsa_context_t *ctx,
                                 int (*f_rng)(void *, unsigned char *, size_t),
                                 void *p_rng,
                                 int mode,
                                 mpaas_antssm_md_type_t md_alg,
                                 unsigned int hashlen,
                                 const unsigned char *hash,
                                 const unsigned char *sig);

/**
 * \brief          Perform a PKCS#1 v2.1 PSS verification (RSASSA-PSS-VERIFY)
 *                 (This is the version with "full" options.)
 *
 * \param ctx      points to an RSA public key
 * \param f_rng    RNG function (Only needed for ANTSSM_RSA_PRIVATE)
 * \param p_rng    RNG parameter
 * \param mode     ANTSSM_RSA_PUBLIC or ANTSSM_RSA_PRIVATE
 * \param md_alg   a ANTSSM_MD_XXX (use ANTSSM_MD_NONE for signing raw data)
 * \param hashlen  message digest length (for ANTSSM_MD_NONE only)
 * \param hash     buffer holding the message digest
 * \param mgf1_hash_id message digest used for mask generation
 * \param expected_salt_len Length of the salt used in padding, use
 *                 ANTSSM_RSA_SALT_LEN_ANY to accept any salt length
 * \param sig      buffer holding the ciphertext
 *
 * \return         0 if the verify operation was successful,
 *                 or an ANTSSM_ERR_RSA_XXX error code
 *
 * \note           The "sig" buffer must be as large as the size
 *                 of ctx->N (eg. 128 bytes if RSA-1024 is used).
 *
 * \note           The hash_id in the RSA context is ignored.
 */
int mpaas_antssm_rsa_rsassa_pss_verify_ext(mpaas_antssm_rsa_context_t *ctx,
                                     int (*f_rng)(void *, unsigned char *,
                                                  size_t),
                                     void *p_rng,
                                     int mode,
                                     mpaas_antssm_md_type_t md_alg,
                                     unsigned int hashlen,
                                     const unsigned char *hash,
                                     mpaas_antssm_md_type_t mgf1_hash_id,
                                     int expected_salt_len,
                                     const unsigned char *sig);

/**
 * \brief          Copy the components of an RSA context
 *
 * \param dst      Destination context
 * \param src      Source context
 *
 * \return         0 on success,
 *                 ANTSSM_ERR_MPI_ALLOC_FAILED on memory allocation failure
 */
int mpaas_antssm_rsa_copy(mpaas_antssm_rsa_context_t *dst, const mpaas_antssm_rsa_context_t *src);

/**
 * \brief          Free the components of an RSA key
 *
 * \param ctx      RSA Context to free
 */
void mpaas_antssm_rsa_free(mpaas_antssm_rsa_context_t *ctx);

/**
 * \brief          Checkup routine
 *
 * \return         0 if successful, or 1 if the test failed
 */
int mpaas_antssm_rsa_self_test(int verbose);

#ifdef __cplusplus
}
#endif

#endif /* rsa.h */
