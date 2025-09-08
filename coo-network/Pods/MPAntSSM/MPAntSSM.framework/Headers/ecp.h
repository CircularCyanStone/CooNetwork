/**
 * \file ecp.h
 *
 * \brief Elliptic curves over GF(p)
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
#ifndef ANTSSM_ECP_H
#define ANTSSM_ECP_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "mpi.h"
#include "log.h"
typedef mpaas_antssm_mpi_uint uECC_word_t;
typedef int8_t wordcount_t;
#define num_words_sm2 ( 256 / 8 / sizeof( mpaas_antssm_mpi_uint ) )
typedef int8_t cmpresult_t;
/*
 * ECP error codes
 */
#define ANTSSM_ERR_ECP_BAD_INPUT_DATA                    -0x4F80  /**< Bad input parameters to function. */
#define ANTSSM_ERR_ECP_BUFFER_TOO_SMALL                  -0x4F00  /**< The buffer is too small to write to. */
#define ANTSSM_ERR_ECP_FEATURE_UNAVAILABLE               -0x4E80  /**< Requested curve not available. */
#define ANTSSM_ERR_ECP_VERIFY_FAILED                     -0x4E00  /**< The signature is not valid. */
#define ANTSSM_ERR_ECP_ALLOC_FAILED                      -0x4D80  /**< Memory allocation failed. */
#define ANTSSM_ERR_ECP_RANDOM_FAILED                     -0x4D00  /**< Generation of random value, such as (ephemeral) key, failed. */
#define ANTSSM_ERR_ECP_INVALID_KEY                       -0x4C80  /**< Invalid private or public key. */
#define ANTSSM_ERR_ECP_SIG_LEN_MISMATCH                  -0x4C00  /**< Signature is valid but shorter than the user-supplied length. */
#if defined(ANTSSM_SM2_C)
#define ANTSSM_ERR_ECP_ENCRYPT_FAILED                    -0x4B80  /**< encryption failed. */
#define ANTSSM_ERR_ECP_DECRYPT_FAILED                    -0x4B00  /**< decryption failed. */
#define ANTSSM_ERR_ECP_DER_ENCODE_FAILED                 -0x4A80  /**< i2d encode failed. */
#define ANTSSM_ERR_ECP_DER_DECODE_FAILED                 -0x4A00  /**< d2i decode failed. */
#endif

#if !defined(ANTSSM_ECP_ALT)
/*
 * default mbed TLS elliptic curve arithmetic implementation
 *
 * (in case ANTSSM_ECP_ALT is defined then the developer has to provide an
 * alternative implementation for the whole module and it will replace this
 * one.)
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Domain parameters (curve, subgroup and generator) identifiers.
 *
 * Only curves over prime fields are supported.
 *
 * \warning This library does not support validation of arbitrary domain
 * parameters. Therefore, only well-known domain parameters from trusted
 * sources should be used. See mpaas_antssm_ecp_group_load().
 */
typedef enum {
    ANTSSM_ECP_DP_NONE = 0,
    ANTSSM_ECP_DP_SECP192R1,      /*!< 192-bits NIST curve  */
    ANTSSM_ECP_DP_SECP224R1,      /*!< 224-bits NIST curve  */
    ANTSSM_ECP_DP_SECP256R1,      /*!< 256-bits NIST curve  */
    ANTSSM_ECP_DP_SECP384R1,      /*!< 384-bits NIST curve  */
    ANTSSM_ECP_DP_SECP521R1,      /*!< 521-bits NIST curve  */
    ANTSSM_ECP_DP_BP256R1,        /*!< 256-bits Brainpool curve */
    ANTSSM_ECP_DP_BP384R1,        /*!< 384-bits Brainpool curve */
    ANTSSM_ECP_DP_BP512R1,        /*!< 512-bits Brainpool curve */
    ANTSSM_ECP_DP_CURVE25519,     /*!< Curve25519               */
    ANTSSM_ECP_DP_SECP192K1,      /*!< 192-bits "Koblitz" curve */
    ANTSSM_ECP_DP_SECP224K1,      /*!< 224-bits "Koblitz" curve */
    ANTSSM_ECP_DP_SECP256K1,      /*!< 256-bits "Koblitz" curve */
    ANTSSM_ECP_DP_SM2,            /*!< "sm2" curve */
} mpaas_antssm_ecp_group_id;

/**
 * Number of supported curves (plus one for NONE).
 *
 * (Montgomery curves excluded for now.)
 */
#define ANTSSM_ECP_DP_MAX     12

/**
 * Curve information for use by other modules
 */
typedef struct {
    mpaas_antssm_ecp_group_id grp_id;    /*!< Internal identifier        */
    uint16_t tls_id;                /*!< TLS NamedCurve identifier  */
    uint16_t bit_size;              /*!< Curve size in bits         */
    const char *name;               /*!< Human-friendly name        */
} mpaas_antssm_ecp_curve_info;

/**
 * \brief           ECP point structure (jacobian coordinates)
 *
 * \note            All functions expect and return points satisfying
 *                  the following condition: Z == 0 or Z == 1. (Other
 *                  values of Z are used by internal functions only.)
 *                  The point is zero, or "at infinity", if Z == 0.
 *                  Otherwise, X and Y are its standard (affine) coordinates.
 */
typedef struct {
    mpaas_antssm_mpi_t X;          /*!<  the point's X coordinate  */
    mpaas_antssm_mpi_t Y;          /*!<  the point's Y coordinate  */
    mpaas_antssm_mpi_t Z;          /*!<  the point's Z coordinate  */
} mpaas_antssm_ecp_point_t;

/**
 * \brief           ECP group structure
 *
 * We consider two types of curves equations:
 * 1. Short Weierstrass y^2 = x^3 + A x + B     mod P   (SEC1 + RFC 4492)
 * 2. Montgomery,       y^2 = x^3 + A x^2 + x   mod P   (Curve25519 + draft)
 * In both cases, a generator G for a prime-order subgroup is fixed. In the
 * short weierstrass, this subgroup is actually the whole curve, and its
 * cardinal is denoted by N.
 *
 * In the case of Short Weierstrass curves, our code requires that N is an odd
 * prime. (Use odd in mpaas_antssm_ecp_mul() and prime in mpaas_antssm_ecdsa_sign() for blinding.)
 *
 * In the case of Montgomery curves, we don't store A but (A + 2) / 4 which is
 * the quantity actually used in the formulas. Also, nbits is not the size of N
 * but the required size for private keys.
 *
 * If modp is NULL, reduction modulo P is done using a generic algorithm.
 * Otherwise, it must point to a function that takes an mpaas_antssm_mpi_t in the range
 * 0..2^(2*pbits)-1 and transforms it in-place in an integer of little more
 * than pbits, so that the integer may be efficiently brought in the 0..P-1
 * range by a few additions or substractions. It must return 0 on success and
 * non-zero on failure.
 */
typedef struct {
    mpaas_antssm_ecp_group_id id;    /*!<  internal group identifier                     */
    mpaas_antssm_mpi_t P;              /*!<  prime modulus of the base field               */
    mpaas_antssm_mpi_t A;              /*!<  1. A in the equation, or 2. (A + 2) / 4       */
    mpaas_antssm_mpi_t B;              /*!<  1. B in the equation, or 2. unused            */
    mpaas_antssm_ecp_point_t G;        /*!<  generator of the (sub)group used              */
    mpaas_antssm_mpi_t N;              /*!<  1. the order of G, or 2. unused               */
    size_t pbits;       /*!<  number of bits in P                           */
    size_t nbits;       /*!<  number of bits in 1. P, or 2. private keys    */
    unsigned int h;     /*!<  internal: 1 if the constants are static       */
    int (*modp)(mpaas_antssm_mpi_t *); /*!<  function for fast reduction mod P             */
    int (*t_pre)(mpaas_antssm_ecp_point_t *, void *);  /*!< unused                         */
    int (*t_post)(mpaas_antssm_ecp_point_t *, void *); /*!< unused                         */
    void *t_data;                       /*!< unused                         */
    mpaas_antssm_ecp_point_t *T;       /*!<  pre-computed points for ecp_mul_comb()        */
    size_t T_size;      /*!<  number for pre-computed points                */
} mpaas_antssm_ecp_group_t;

/**
 * \brief           ECP key pair structure
 *
 * A generic key pair that could be used for ECDSA, fixed ECDH, etc.
 *
 * \note Members purposefully in the same order as struc mpaas_antssm_ecdsa_context.
 */
typedef struct {
    mpaas_antssm_ecp_group_t grp;      /*!<  Elliptic curve and base point     */
    mpaas_antssm_mpi_t d;              /*!<  our secret value                  */
    mpaas_antssm_ecp_point_t Q;        /*!<  our public value                  */
    char traceid[ANTSSM_TRACEID_LENGTH];  /*!<  trace id          */
    char userid[8192];
    unsigned int userid_len;
} mpaas_antssm_ecp_keypair_t;

/**
 * \name SECTION: Module settings
 *
 * The configuration options you can set for this module are in this section.
 * Either change them in config.h or define them on the compiler command line.
 * \{
 */

#if !defined(ANTSSM_ECP_MAX_BITS)
/**
 * Maximum size of the groups (that is, of N and P)
 */
#define ANTSSM_ECP_MAX_BITS     521   /**< Maximum bit size of groups */
#endif

#define ANTSSM_ECP_MAX_BYTES    ( ( ANTSSM_ECP_MAX_BITS + 7 ) / 8 )
#define ANTSSM_ECP_MAX_PT_LEN   ( 2 * ANTSSM_ECP_MAX_BYTES + 1 )

#if !defined(ANTSSM_ECP_WINDOW_SIZE)
/*
 * Maximum "window" size used for point multiplication.
 * Default: 6.
 * Minimum value: 2. Maximum value: 7.
 *
 * Result is an array of at most ( 1 << ( ANTSSM_ECP_WINDOW_SIZE - 1 ) )
 * points used for point multiplication. This value is directly tied to EC
 * peak memory usage, so decreasing it by one should roughly cut memory usage
 * by two (if large curves are in use).
 *
 * Reduction in size may reduce speed, but larger curves are impacted first.
 * Sample performances (in ECDHE handshakes/s, with FIXED_POINT_OPTIM = 1):
 *      w-size:     6       5       4       3       2
 *      521       145     141     135     120      97
 *      384       214     209     198     177     146
 *      256       320     320     303     262     226

 *      224       475     475     453     398     342
 *      192       640     640     633     587     476
 */
#define ANTSSM_ECP_WINDOW_SIZE    6   /**< Maximum window size used */
#endif /* ANTSSM_ECP_WINDOW_SIZE */

#if !defined(ANTSSM_ECP_FIXED_POINT_OPTIM)
/*
 * Trade memory for speed on fixed-point multiplication.
 *
 * This speeds up repeated multiplication of the generator (that is, the
 * multiplication in ECDSA signatures, and half of the multiplications in
 * ECDSA verification and ECDHE) by a factor roughly 3 to 4.
 *
 * The cost is increasing EC peak memory usage by a factor roughly 2.
 *
 * Change this value to 0 to reduce peak memory usage.
 */
#define ANTSSM_ECP_FIXED_POINT_OPTIM  1   /**< Enable fixed-point speed-up */
#endif /* ANTSSM_ECP_FIXED_POINT_OPTIM */

/* \} name SECTION: Module settings */

/*
 * Point formats, from RFC 4492's enum ECPointFormat
 */
#define ANTSSM_ECP_PF_UNCOMPRESSED    0   /**< Uncompressed point format */
#define ANTSSM_ECP_PF_COMPRESSED      1   /**< Compressed point format */

/*
 * Some other constants from RFC 4492
 */
#define ANTSSM_ECP_TLS_NAMED_CURVE    3   /**< ECCurveType's named_curve */

/**
 * \brief           Get the list of supported curves in order of preferrence
 *                  (full information)
 *
 * \return          A statically allocated array, the last entry is 0.
 */
const mpaas_antssm_ecp_curve_info *mpaas_antssm_ecp_curve_list(void);

/**
 * \brief           Get the list of supported curves in order of preferrence
 *                  (grp_id only)
 *
 * \return          A statically allocated array,
 *                  terminated with ANTSSM_ECP_DP_NONE.
 */
const mpaas_antssm_ecp_group_id *mpaas_antssm_ecp_grp_id_list(void);

/**
 * \brief           Get curve information from an internal group identifier
 *
 * \param grp_id    A ANTSSM_ECP_DP_XXX value
 *
 * \return          The associated curve information or NULL
 */
const mpaas_antssm_ecp_curve_info *mpaas_antssm_ecp_curve_info_from_grp_id(mpaas_antssm_ecp_group_id grp_id);

/**
 * \brief           Get curve information from a TLS NamedCurve value
 *
 * \param tls_id    A ANTSSM_ECP_DP_XXX value
 *
 * \return          The associated curve information or NULL
 */
const mpaas_antssm_ecp_curve_info *mpaas_antssm_ecp_curve_info_from_tls_id(uint16_t tls_id);

/**
 * \brief           Get curve information from a human-readable name
 *
 * \param name      The name
 *
 * \return          The associated curve information or NULL
 */
const mpaas_antssm_ecp_curve_info *mpaas_antssm_ecp_curve_info_from_name(const char *name);

/**
 * \brief           Initialize a point (as zero)
 */
void mpaas_antssm_ecp_point_init(mpaas_antssm_ecp_point_t *pt);

/**
 * \brief           Initialize a group (to something meaningless)
 */
void mpaas_antssm_ecp_group_init(mpaas_antssm_ecp_group_t *grp);

/**
 * \brief           Initialize a key pair (as an invalid one)
 */
void mpaas_antssm_ecp_keypair_init(mpaas_antssm_ecp_keypair_t *key);

/**
 * \brief           Free the components of a point
 */
void mpaas_antssm_ecp_point_free(mpaas_antssm_ecp_point_t *pt);

/**
 * \brief           Free the components of an ECP group
 */
void mpaas_antssm_ecp_group_free(mpaas_antssm_ecp_group_t *grp);

/**
 * \brief           Free the components of a key pair
 */
API_EXPORT
void mpaas_antssm_ecp_keypair_free(mpaas_antssm_ecp_keypair_t *key);

/**
 * \brief           Copy the contents of point Q into P
 *
 * \param P         Destination point
 * \param Q         Source point
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed
 */
int mpaas_antssm_ecp_copy(mpaas_antssm_ecp_point_t *P, const mpaas_antssm_ecp_point_t *Q);

/**
 * \brief           Copy the contents of a group object
 *
 * \param dst       Destination group
 * \param src       Source group
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed
 */
int mpaas_antssm_ecp_group_copy(mpaas_antssm_ecp_group_t *dst, const mpaas_antssm_ecp_group_t *src);

/**
 * \brief           Set a point to zero
 *
 * \param pt        Destination point
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed
 */
int mpaas_antssm_ecp_set_zero(mpaas_antssm_ecp_point_t *pt);

/**
 * \brief           Tell if a point is zero
 *
 * \param pt        Point to test
 *
 * \return          1 if point is zero, 0 otherwise
 */
int mpaas_antssm_ecp_is_zero(mpaas_antssm_ecp_point_t *pt);

/**
 * \brief           Compare two points
 *
 * \note            This assumes the points are normalized. Otherwise,
 *                  they may compare as "not equal" even if they are.
 *
 * \param P         First point to compare
 * \param Q         Second point to compare
 *
 * \return          0 if the points are equal,
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA otherwise
 */
int mpaas_antssm_ecp_point_cmp(const mpaas_antssm_ecp_point_t *P,
                         const mpaas_antssm_ecp_point_t *Q);

/**
 * \brief           Import a non-zero point from two ASCII strings
 *
 * \param P         Destination point
 * \param radix     Input numeric base
 * \param x         First affine coordinate as a null-terminated string
 * \param y         Second affine coordinate as a null-terminated string
 *
 * \return          0 if successful, or a ANTSSM_ERR_MPI_XXX error code
 */
int mpaas_antssm_ecp_point_read_string(mpaas_antssm_ecp_point_t *P, int radix,
                                 const char *x, const char *y);

/**
 * \brief           Export a point into unsigned binary data
 *
 * \param grp       Group to which the point should belong
 * \param P         Point to export
 * \param format    Point format, should be a ANTSSM_ECP_PF_XXX macro
 * \param olen      Length of the actual output
 * \param buf       Output buffer
 * \param buflen    Length of the output buffer
 *
 * \return          0 if successful,
 *                  or ANTSSM_ERR_ECP_BAD_INPUT_DATA
 *                  or ANTSSM_ERR_ECP_BUFFER_TOO_SMALL
 */
int mpaas_antssm_ecp_point_write_binary(const mpaas_antssm_ecp_group_t *grp, const mpaas_antssm_ecp_point_t *P,
                                  int format, size_t *olen,
                                  unsigned char *buf, size_t buflen);

/**
 * \brief           Import a point from unsigned binary data
 *
 * \param grp       Group to which the point should belong
 * \param P         Point to import
 * \param buf       Input buffer
 * \param ilen      Actual length of input
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA if input is invalid,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed,
 *                  ANTSSM_ERR_ECP_FEATURE_UNAVAILABLE if the point format
 *                  is not implemented.
 *
 * \note            This function does NOT check that the point actually
 *                  belongs to the given group, see mpaas_antssm_ecp_check_pubkey() for
 *                  that.
 */
int mpaas_antssm_ecp_point_read_binary(const mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *P,
                                 const unsigned char *buf, size_t ilen);

/**
 * \brief           Import a point from a TLS ECPoint record
 *
 * \param grp       ECP group used
 * \param pt        Destination point
 * \param buf       $(Start of input buffer)
 * \param len       Buffer length
 *
 * \note            buf is updated to point right after the ECPoint on exit
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_XXX if initialization failed
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA if input is invalid
 */
int mpaas_antssm_ecp_tls_read_point(const mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *pt,
                              const unsigned char **buf, size_t len);

/**
 * \brief           Export a point as a TLS ECPoint record
 *
 * \param grp       ECP group used
 * \param pt        Point to export
 * \param format    Export format
 * \param olen      length of data written
 * \param buf       Buffer to write to
 * \param blen      Buffer length
 *
 * \return          0 if successful,
 *                  or ANTSSM_ERR_ECP_BAD_INPUT_DATA
 *                  or ANTSSM_ERR_ECP_BUFFER_TOO_SMALL
 */
int mpaas_antssm_ecp_tls_write_point(const mpaas_antssm_ecp_group_t *grp, const mpaas_antssm_ecp_point_t *pt,
                               int format, size_t *olen,
                               unsigned char *buf, size_t blen);

/**
 * \brief           Set a group using well-known domain parameters
 *
 * \param grp       Destination group
 * \param id        Index in the list of well-known domain parameters
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_XXX if initialization failed
 *                  ANTSSM_ERR_ECP_FEATURE_UNAVAILABLE for unkownn groups
 *
 * \note            Index should be a value of RFC 4492's enum NamedCurve,
 *                  usually in the form of a ANTSSM_ECP_DP_XXX macro.
 */
int mpaas_antssm_ecp_group_load(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_group_id id);

/**
 * \brief           Set a group from a TLS ECParameters record
 *
 * \param grp       Destination group
 * \param buf       &(Start of input buffer)
 * \param len       Buffer length
 *
 * \note            buf is updated to point right after ECParameters on exit
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_MPI_XXX if initialization failed
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA if input is invalid
 */
int mpaas_antssm_ecp_tls_read_group(mpaas_antssm_ecp_group_t *grp, const unsigned char **buf, size_t len);

/**
 * \brief           Write the TLS ECParameters record for a group
 *
 * \param grp       ECP group used
 * \param olen      Number of bytes actually written
 * \param buf       Buffer to write to
 * \param blen      Buffer length
 *
 * \return          0 if successful,
 *                  or ANTSSM_ERR_ECP_BUFFER_TOO_SMALL
 */
int mpaas_antssm_ecp_tls_write_group(const mpaas_antssm_ecp_group_t *grp, size_t *olen,
                               unsigned char *buf, size_t blen);

/**
 * \brief           Multiplication by an integer: R = m * P
 *                  (Not thread-safe to use same group in multiple threads)
 *
 * \note            In order to prevent timing attacks, this function
 *                  executes the exact same sequence of (base field)
 *                  operations for any valid m. It avoids any if-branch or
 *                  array index depending on the value of m.
 *
 * \note            If f_rng is not NULL, it is used to randomize intermediate
 *                  results in order to prevent potential timing attacks
 *                  targeting these results. It is recommended to always
 *                  provide a non-NULL f_rng (the overhead is negligible).
 *
 * \param grp       ECP group
 * \param R         Destination point
 * \param m         Integer by which to multiply
 * \param P         Point to multiply
 * \param f_rng     RNG function (see notes)
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_ECP_INVALID_KEY if m is not a valid privkey
 *                  or P is not a valid pubkey,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed
 */
int mpaas_antssm_ecp_mul(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *R,
                   const mpaas_antssm_mpi_t *m, const mpaas_antssm_ecp_point_t *P,
                   int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Multiplication and addition of two points by integers:
 *                  R = m * P + n * Q
 *                  (Not thread-safe to use same group in multiple threads)
 *
 * \note            In contrast to mpaas_antssm_ecp_mul(), this function does not guarantee
 *                  a constant execution flow and timing.
 *
 * \param grp       ECP group
 * \param R         Destination point
 * \param m         Integer by which to multiply P
 * \param P         Point to multiply by m
 * \param n         Integer by which to multiply Q
 * \param Q         Point to be multiplied by n
 *
 * \return          0 if successful,
 *                  ANTSSM_ERR_ECP_INVALID_KEY if m or n is not a valid privkey
 *                  or P or Q is not a valid pubkey,
 *                  ANTSSM_ERR_MPI_ALLOC_FAILED if memory allocation failed
 */
int mpaas_antssm_ecp_muladd(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *R,
                      const mpaas_antssm_mpi_t *m, const mpaas_antssm_ecp_point_t *P,
                      const mpaas_antssm_mpi_t *n, const mpaas_antssm_ecp_point_t *Q);

/**
 * \brief           Check that a point is a valid public key on this curve
 *
 * \param grp       Curve/group the point should belong to
 * \param pt        Point to check
 *
 * \return          0 if point is a valid public key,
 *                  ANTSSM_ERR_ECP_INVALID_KEY otherwise.
 *
 * \note            This function only checks the point is non-zero, has valid
 *                  coordinates and lies on the curve, but not that it is
 *                  indeed a multiple of G. This is additional check is more
 *                  expensive, isn't required by standards, and shouldn't be
 *                  necessary if the group used has a small cofactor. In
 *                  particular, it is useless for the NIST groups which all
 *                  have a cofactor of 1.
 *
 * \note            Uses bare components rather than an mpaas_antssm_ecp_keypair_t structure
 *                  in order to ease use with other structures such as
 *                  mpaas_antssm_ecdh_context_t of mpaas_antssm_ecdsa_context.
 */
int mpaas_antssm_ecp_check_pubkey(const mpaas_antssm_ecp_group_t *grp, const mpaas_antssm_ecp_point_t *pt);

/**
 * \brief           Check that an mpaas_antssm_mpi_t is a valid private key for this curve
 *
 * \param grp       Group used
 * \param d         Integer to check
 *
 * \return          0 if point is a valid private key,
 *                  ANTSSM_ERR_ECP_INVALID_KEY otherwise.
 *
 * \note            Uses bare components rather than an mpaas_antssm_ecp_keypair_t structure
 *                  in order to ease use with other structures such as
 *                  mpaas_antssm_ecdh_context_t of mpaas_antssm_ecdsa_context.
 */
int mpaas_antssm_ecp_check_privkey(const mpaas_antssm_ecp_group_t *grp, const mpaas_antssm_mpi_t *d);

/**
 * \brief           Generate a keypair with configurable base point
 *
 * \param grp       ECP group
 * \param G         Chosen base point
 * \param d         Destination MPI (secret part)
 * \param Q         Destination point (public part)
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 *
 * \note            Uses bare components rather than an mpaas_antssm_ecp_keypair_t structure
 *                  in order to ease use with other structures such as
 *                  mpaas_antssm_ecdh_context_t of mpaas_antssm_ecdsa_context.
 */
int mpaas_antssm_ecp_gen_keypair_base(mpaas_antssm_ecp_group_t *grp,
                                const mpaas_antssm_ecp_point_t *G,
                                mpaas_antssm_mpi_t *d, mpaas_antssm_ecp_point_t *Q,
                                int (*f_rng)(void *, unsigned char *, size_t),
                                void *p_rng);

/**
 * \brief           Generate a keypair
 *
 * \param grp       ECP group
 * \param d         Destination MPI (secret part)
 * \param Q         Destination point (public part)
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 *
 * \note            Uses bare components rather than an mpaas_antssm_ecp_keypair_t structure
 *                  in order to ease use with other structures such as
 *                  mpaas_antssm_ecdh_context_t of mpaas_antssm_ecdsa_context.
 */
int mpaas_antssm_ecp_gen_keypair(mpaas_antssm_ecp_group_t *grp, mpaas_antssm_mpi_t *d, mpaas_antssm_ecp_point_t *Q,
                           int (*f_rng)(void *, unsigned char *, size_t),
                           void *p_rng);

/**
 * \brief           Generate a keypair
 *
 * \param grp_id    ECP group identifier
 * \param key       Destination keypair
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
int mpaas_antssm_ecp_gen_key(mpaas_antssm_ecp_group_id grp_id, mpaas_antssm_ecp_keypair_t *key,
                       int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Calculate a keypair with private key
 *
 * \param grp_id    ECP group identifier
 * \param key       Destination keypair
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
 API_EXPORT
int mpaas_antssm_ecp_cal_key_with_private_key(mpaas_antssm_ecp_group_id grp_id, mpaas_antssm_ecp_keypair_t *key,
                       const char *priv_hex,
                       int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

/**
 * \brief           Calculate a keypair with public key
 *
 * \param grp_id    ECP group identifier
 * \param key       Destination keypair
 * \param f_rng     RNG function
 * \param p_rng     RNG parameter
 *
 * \return          0 if successful,
 *                  or a ANTSSM_ERR_ECP_XXX or ANTSSM_MPI_XXX error code
 */
API_EXPORT
int mpaas_antssm_ecp_cal_key_with_public_key(mpaas_antssm_ecp_group_id grp_id, mpaas_antssm_ecp_keypair_t *key,
                       const char *pub_hex_x, const char *pub_hex_y);


/**
 * \brief           Check a public-private key pair
 *
 * \param pub       Keypair structure holding a public key
 * \param prv       Keypair structure holding a private (plus public) key
 *
 * \return          0 if successful (keys are valid and match), or
 *                  ANTSSM_ERR_ECP_BAD_INPUT_DATA, or
 *                  a ANTSSM_ERR_ECP_XXX or ANTSSM_ERR_MPI_XXX code.
 */
API_EXPORT
int mpaas_antssm_random_default(void *state, unsigned char *output, size_t len);

int mpaas_antssm_ecp_check_pub_priv(const mpaas_antssm_ecp_keypair_t *pub, const mpaas_antssm_ecp_keypair_t *prv);

int mpaas_antssm_ecp_add_mixed(const mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *R,
                  const mpaas_antssm_ecp_point_t *P, const mpaas_antssm_ecp_point_t *Q);

int mpaas_antssm_ecp_normalize_jac(const mpaas_antssm_ecp_group_t *grp, mpaas_antssm_ecp_point_t *pt);

#if defined(ANTSSM_SELF_TEST)

/**
 * \brief          Checkup routine
 *
 * \return         0 if successful, or 1 if a test failed
 */
int mpaas_antssm_ecp_self_test(int verbose);

#endif /* ANTSSM_SELF_TEST */

#ifdef __cplusplus
}
#endif

#else  /* ANTSSM_ECP_ALT */
#include "ecp_alt.h"
#endif /* ANTSSM_ECP_ALT */

#endif /* ecp.h */
