/*
 * Copyright 2017 The OpenSSL Project Authors. All Rights Reserved.
 * Copyright 2017 Ribose Inc. All Rights Reserved.
 *
 * Licensed under the OpenSSL license (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

#ifndef OSSL_CRYPTO_SM4_H
# define OSSL_CRYPTO_SM4_H

//# include <openssl/opensslconf.h>
#define ossl_inline inline
#include <stdint.h>

# ifdef OPENSSL_NO_SM4
#  error SM4 is disabled.
# endif

# define SM4_ENCRYPT     1
# define SM4_DECRYPT     0

# define SM4_BLOCK_SIZE    16
# define SM4_KEY_SCHEDULE  32

typedef struct {
    uint32_t rk[SM4_KEY_SCHEDULE];
} mpaas_antssm_sm4_asm_context_t;

typedef struct {
    uint32_t rk1[SM4_KEY_SCHEDULE];
    uint32_t rk2[SM4_KEY_SCHEDULE];
} mpaas_antssm_sm4_xts_asm_context_t;


void mpaas_antssm_sm4_asm_init(mpaas_antssm_sm4_asm_context_t *ctx);
void mpaas_antssm_sm4_xts_asm_init(mpaas_antssm_sm4_xts_asm_context_t *ctx);

void mpaas_antssm_sm4_asm_free(mpaas_antssm_sm4_asm_context_t *ctx);
void mpaas_antssm_sm4_xts_asm_free(mpaas_antssm_sm4_xts_asm_context_t *ctx);

int mpaas_antssm_sm4_asm_set_key(mpaas_antssm_sm4_asm_context_t *ctx, const uint8_t *key);
int mpaas_antssm_sm4_xts_asm_set_key(mpaas_antssm_sm4_xts_asm_context_t *ctx, const uint8_t *key);

void mpaas_antssm_sm4_asm_encrypt_ctr(mpaas_antssm_sm4_asm_context_t *ctx,
                                unsigned char iv[16], unsigned char *plain,
                                int plainLen, unsigned char *cipherbuf);

int mpaas_antssm_sm4_asm_encrypt_xts(mpaas_antssm_sm4_xts_asm_context_t *ctx,
                                unsigned char iv[16], unsigned char *plain,
                                int plainLen, unsigned char *cipherbuf);

void mpaas_antssm_sm4_asm_decrypt_ctr(mpaas_antssm_sm4_asm_context_t *ctx, unsigned char iv[16],
                           unsigned char *cipher, int cipherLen,
                           unsigned char *plainbuf);

int mpaas_antssm_sm4_asm_decrypt_xts(mpaas_antssm_sm4_xts_asm_context_t *ctx, unsigned char iv[16],
                           unsigned char *cipher, int cipherLen,
                           unsigned char *plainbuf);

uint32_t mpaas_antssm_avx_avx_ctr_blocks(const uint32_t *rk, const uint8_t *iv, const uint8_t *pi,
                            uint8_t *po, uint32_t lenX, uint32_t cnt);
#endif
