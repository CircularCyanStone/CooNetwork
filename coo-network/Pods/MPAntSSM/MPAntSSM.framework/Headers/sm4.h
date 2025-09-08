#ifndef ANTSSM_SM4_H
#define ANTSSM_SM4_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>
#include <stdint.h>

#include "log.h"

#define ANTSSM_ERR_SM4_BAD_INPUT_DATA        0x0011
#define ANTSSM_ERR_SM4_INVALID_INPUT_LENGTH     0x0013

#define ANTSSM_SM4_ENCRYPT              (1)
#define ANTSSM_SM4_DECRYPT              (0)

#if !defined(ANTSSM_SM4_ALT)
#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          SM4 context structure
 */
typedef struct {
    uint32_t key[32];   /*SOFT ALGORITHM*/
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_sm4_context_t;

typedef struct {
    uint32_t key1[32]; /*ROUND KEY*/
    uint32_t key2[32]; /*ROUND KEY*/
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_sm4_xts_context_t;
void printArraySM4(char *s, unsigned char *a, int l);
/**
 * \brief          Initialize SM4 context
 *
 * \param ctx      SM4 context to be initialized
 */
void mpaas_antssm_sm4_init(mpaas_antssm_sm4_context_t *ctx);

/**
 * \brief          Initialize SM4_XTS context
 *
 * \param ctx      SM4_XTS context to be initialized
 */
void mpaas_antssm_sm4_xts_init(mpaas_antssm_sm4_xts_context_t *ctx);

/**
 * \brief          Clear SM4 context
 *
 * \param ctx      SM4 context to be cleared
 */
void mpaas_antssm_sm4_free(mpaas_antssm_sm4_context_t *ctx);

/**
 * \brief          Clear SM4_XTS context
 *
 * \param ctx      SM4_XTS context to be cleared
 */
void mpaas_antssm_sm4_xts_free(mpaas_antssm_sm4_xts_context_t *ctx);

/**
 * \brief          SM4 key schedule
 *
 * \param ctx      SM4 context to be initialized
 * \param userKey  16-byte secret key
 * \param length   secret key length, it's 16
 *
 */
int mpaas_antssm_sm4_set_key(mpaas_antssm_sm4_context_t *ctx, const unsigned char *userKey, size_t length);

/**
 * \brief          SM4_XTS key schedule
 *
 * \param ctx      SM4_XTS context to be initialized
 * \param userKey  32-byte secret key
 * \param length   secret key length, it's 32
 *
 */
int mpaas_antssm_sm4_xts_set_key(mpaas_antssm_sm4_xts_context_t *ctx, const unsigned char *userKey, size_t length);

/**
 * \brief          SM4 encryption one block
 *
 * \param ctx      SM4 context
 * \param in       buffer holding the input data
 * \param out      buffer holding the output data
 *
 */
int mpaas_antssm_sm4_encrypt(mpaas_antssm_sm4_context_t *ctx, const unsigned char *in, unsigned char *out);
int mpaas_antssm_sm4_encrypt_notrace(int enc, const uint32_t *rk, const unsigned char *src, unsigned char *dst);

/**
 * \brief          SM4 decryption one block
 *
 * \param ctx      SM4 context
 * \param in       buffer holding the input data
 * \param out      buffer holding the output data
 *
 */
int mpaas_antssm_sm4_decrypt(mpaas_antssm_sm4_context_t *ctx, const unsigned char *in, unsigned char *out);
int mpaas_antssm_sm4_decrypt_notrace(int dec, const uint32_t *rk, const unsigned char *src, unsigned char *dst);

#if !defined(ANTSSM_SM4_CRYPT_ECB_ALT)

/**
 * \brief          SM4-ECB block encryption/decryption
 *
 * \param ctx      SM4 context
 * \param mode     ANTSSM_SM4_ENCRYPT or ANTSSM_SM4_DECRYPT
 * \param length   length of input data
 * \param in       buffer holding the input data
 * \param out      buffer holding the output data
 *
 */
int mpaas_antssm_sm4_crypt_ecb(mpaas_antssm_sm4_context_t *ctx,
                         int mode,
                         size_t length,
                         const unsigned char *input,
                         unsigned char *output);

#endif

#if defined(ANTSSM_CIPHER_MODE_CBC)

/**
 * \brief          SM4-CBC buffer encryption/decryption
 *
 * \note           Upon exit, the content of the IV is updated so that you can
 *                 call the function same function again on the following
 *                 block(s) of data and get the same result as if it was
 *                 encrypted in one call. This allows a "streaming" usage.
 *                 If on the other hand you need to retain the contents of the
 *                 IV, you should either save it manually or use the cipher
 *                 module instead.
 *
 * \param ctx      SM4 context
 * \param mode     ANTSSM_SM4_ENCRYPT or ANTSSM_SM4_DECRYPT
 * \param length   length of the input data
 * \param iv       initialization vector (updated after use)
 * \param input    buffer holding the input data
 * \param output   buffer holding the output data
 */
int mpaas_antssm_sm4_crypt_cbc(mpaas_antssm_sm4_context_t *ctx,
                         int mode,
                         size_t length,
                         unsigned char *iv,
                         const unsigned char *input,
                         unsigned char *output);

#endif /* ANTSSM_CIPHER_MODE_CBC */

#if defined(ANTSSM_CIPHER_MODE_XTS)
/**
 * T * alpha
 * @param T
 */
void sm4_xts_mul_alpha_gf(uint8_t T[16]);

/**
 * \brief               SM4_XTS encryption/decryption
 *
 * \note                Each input is assigned a 128bits-length tweak value,
 *
 *
 * @param ctx           SM4_XTS context
 * @param mode          ANTSSM_SM4_ENCRYPT or ANTSSM_SM4_DECRYPT
 * @param length        length of the input data
 * @param tweak_value   tweak_value
 * @param input         buffer holding the input data
 * @param output        buffer holding the output data
 * @return
 */
int mpaas_antssm_sm4_crypt_xts(mpaas_antssm_sm4_xts_context_t *ctx,
                         int mode,
                         size_t length,
                         const unsigned char *tweak_value,
                         const unsigned char *input,
                         unsigned char *output);
#endif /* ANTSSM_CIPHER_MODE_XTS */

#ifdef __cplusplus
}
#endif

#else  /* ANTSSM_SM4_ALT */
#include "sm4_alt.h"
#endif /* ANTSSM_SM4_ALT */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          Checkup routine
 *
 * \return         0 if successful, or 1 if the test failed
 */
int mpaas_antssm_sm4_self_test(int verbose);

#ifdef __cplusplus
}
#endif

#endif /* sm4.h */
