/*
 * Sm4WB.h
 *
 *  Created on: 2018年9月6日
 *      Author: wangweiping
 */

#ifndef ANTSSM_WHITE_BOX_H
#define ANTSSM_WHITE_BOX_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stdint.h>
#include <stdlib.h>
#include "platform_specific.h"
#include "hashmap.h"
#include "key_rep.h"
#include "antcrypto_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t mpaas_antssm_mbM_32x32[32][3][32];
    uint32_t mpaas_antssm_mbP_32x32[8][32];
    uint32_t mpaas_antssm_invPP[32][32];
    uint32_t mpaas_antssm_invQP[32][32];
    uint32_t mpaas_antssm_Part2Box[32][4][256]; //加密查找表；
    uint32_t mpaas_antssm_Part2InvBox[32][4][256];//解密查找表;

    mpaas_antssm_pthread_mutex_t mutex;

    mpaas_antssm_key_rep_context_t key_rep;

#ifdef ANTSSM_THRESHOLD_STORE_KEY_SHARE
    unsigned char userid[16];
    unsigned char sk[16];
    mpaas_antssm_hashmap_t server_store_share_map;
#endif
    void * session;
} mpaas_antssm_white_box_context_t;

void mpaas_antssm_white_box_init(mpaas_antssm_white_box_context_t *ctx);

int mpaas_antssm_white_box_init_internal(mpaas_antssm_white_box_context_t *ctx, unsigned char *white_box, void *session);

void mpaas_antssm_white_box_free(mpaas_antssm_white_box_context_t *ctx);

#ifdef ANTSSM_THRESHOLD_STORE_KEY_SHARE

int mpaas_antssm_white_box_set_userid(mpaas_antssm_white_box_context_t *ctx,
                                const unsigned char *userid,
                                size_t userid_len);

#endif

int mpaas_antssm_white_box_setup(mpaas_antssm_white_box_context_t *ctx,
                           const char *filename,
                           size_t filenamelen);

int mpaas_antssm_load_white_box(mpaas_antssm_white_box_context_t *ctx, int seq);

int mpaas_antssm_File2BOX(mpaas_antssm_white_box_context_t *ctx, const char *whiteboxfile);

int mpaas_antssm_white_box_encrypt(mpaas_antssm_white_box_context_t *ctx,
                             unsigned char *PlainData,
                             size_t PlainDataLen,
                             unsigned char *CipherBuff,
                             size_t CipherBuffLen,
                             size_t *CipherLen);

int mpaas_antssm_white_box_decrypt(mpaas_antssm_white_box_context_t *ctx,
                             const unsigned char *Cipher,
                             size_t CipherLen,
                             unsigned char *PlainBuff,
                             size_t PlainBuffLen,
                             size_t *PlainLen);

int mpaas_antssm_white_box_find(mpaas_antssm_white_box_context_t *ctx, int seq, const unsigned char *filename, size_t filenamelen,
                          const unsigned char *outputbuf, size_t outputbuflen, mpaas_antssm_antcrypto_key_t *key);

int mpaas_antssm_white_box_store(mpaas_antssm_white_box_context_t *ctx, int seq, const unsigned char *filename, size_t filenamelen,
                           const unsigned char *inputbuf, size_t inputbuflen, mpaas_antssm_antcrypto_key_t *mpaas_antssm_key);

#ifdef __cplusplus
}
#endif
#endif /* ANTSSM_WHITE_BOX_H */
