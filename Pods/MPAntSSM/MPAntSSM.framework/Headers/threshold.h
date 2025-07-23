/*
 * SM2threshold.h
 *
 *  Created on: Sep 13, 2018
 *      Author: pan
 */

#ifndef ANTSSM_THRESHOLD_H
#define ANTSSM_THRESHOLD_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "ecp.h"
#include "mpi.h"
#include "white_box.h"
#include "rsa.h"
#include "ecdsa.h"
#include "sm2.h"
#include "antcrypto_internal.h"

enum mpaas_antssm_threshold_algorithm {
    ANTSSM_THRESHOLD_NONE = 0,
    ANTSSM_THRESHOLD_WHITE_BOX_1 = 1,
    ANTSSM_THRESHOLD_WHITE_BOX_2 = 2,
    ANTSSM_THRESHOLD_WHITE_BOX_3 = 3,
    ANTSSM_THRESHOLD_SM2 = 4,
    ANTSSM_THRESHOLD_RSA2048 = 5,
    ANTSSM_THRESHOLD_ECDSA_SECP256K1 = 6,
    ANTSSM_THRESHOLD_SYMMETRIC= 7,
};

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief  生成根密钥存储分量
 *
 * \param  name  [IN]  密钥名
 * \param  password  [IN]  密钥访问口令
 * \param  algorithm_id  [IN]  算法ID
 * \param  buf  [OUT]  缓冲区
 * \param  buflen  [IN]  缓冲区长度
 * \param  outlen  [OUT]  输出长度
 *
 * \return  状态码[0:成功; 其他:错误码]
 */
int mpaas_antssm_threshold_generate_store_share(mpaas_antssm_white_box_context_t *white_box,
                                          const unsigned char name[16],
                                          const unsigned char password[16],
                                          int algorithm_id,
                                          unsigned char *buf,
                                          size_t *outlen);

/**
 * \brief 生成获取根密钥存储分量请求
 *
 * \param  name  [IN]  密钥名称
 * \param  password  [IN]  密钥访问口令
 * \param  algorithm_id  [IN]  算法ID
 * \param  buf  [OUT]  缓冲区
 * \param  buflen  [IN]  缓冲区长度
 * \param  outlen  [OUT]  缓冲区输出长度
 *
 * \return  状态码[0:成功; 其他:错误码]
 */
/**
 * \brief 获取根密钥存储分量
 * \param white_box
 * \param name  [IN]  密钥名称
 * \param password  [IN]  密钥访问口令
 * \param algorithm_id  [IN]  算法ID
 * \param buf  [OUT]  缓冲区
 * \param buflen  [OUT]  缓冲区输出长度
 * \return
 */
int mpaas_antssm_threshold_get_store_share(mpaas_antssm_white_box_context_t *white_box,
                                     const unsigned char name[16],
                                     const unsigned char password[16],
                                     int algorithm_id,
                                     unsigned char *buf,
                                     size_t *buflen);

/**
 * \brief  导入根密钥存储分量
 *
 * \param  name  [IN]  密钥名称
 * \param  password  [IN]  密钥访问口令
 * \param  algorithm_id  [IN]  算法ID
 * \param  buf  [OUT]  缓冲区
 * \param  buflen  [IN]  缓冲区长度
 * \param  outlen  [OUT]  缓冲区输出长度
 *
 * \return  状态码[0:成功; 其他:错误码]
 */
int mpaas_antssm_threshold_input_store_share(mpaas_antssm_white_box_context_t *white_box,
        const unsigned char name[16], const unsigned char password[16],
        int algorithm_id, const unsigned char *buf, size_t buflen);

int mpaas_antssm_threshold_gen_rsa_keypair(mpaas_antssm_white_box_context_t *white_box,
        mpaas_antssm_antcrypto_key_t *mpaas_antssm_key,
        mpaas_antssm_rsa_context_t *rsa_context);

int mpaas_antssm_threshold_find_rsa_keypair(mpaas_antssm_white_box_context_t *white_box,
        mpaas_antssm_antcrypto_key_t *mpaas_antssm_key,
        mpaas_antssm_rsa_context_t *rsa_ctx);

int mpaas_antssm_threshold_import_rsa_private_key(mpaas_antssm_white_box_context_t *white_box,
        mpaas_antssm_antcrypto_key_t *mpaas_antssm_key,
        const unsigned char *private_key, size_t private_key_len,
        mpaas_antssm_rsa_context_t *rsa_ctx);

int mpaas_antssm_threshold_gen_ecdsa_keypair(mpaas_antssm_white_box_context_t *white_box,
        const unsigned char *name, size_t name_len,
        const unsigned char *password, size_t password_len,
        mpaas_antssm_ecdsa_context_t *ecdsa_context,
        const uint32_t algorithm);      //specific the different curve group, eg:ecdsa_p256k1 and ecdsa_p256r1/v1

int mpaas_antssm_threshold_find_ecdsa_keypair(mpaas_antssm_white_box_context_t *white_box,
        const unsigned char *name, size_t name_len,
        const unsigned char *password, size_t password_len,
        mpaas_antssm_ecdsa_context_t *ecdsa_ctx,
        const uint32_t algorithm);

int mpaas_antssm_threshold_import_ecdsa_private_key(mpaas_antssm_white_box_context_t *white_box,
        const unsigned char *name, size_t name_len,
        const unsigned char *password, size_t password_len,
        const unsigned char *private_key, size_t private_key_len,
        mpaas_antssm_ecdsa_context_t *ecdsa_ctx,
        const uint32_t algorithm);

int mpaas_antssm_threshold_import_symmetric_key(mpaas_antssm_white_box_context_t *white_box,
        mpaas_antssm_antcrypto_key_t *mpaas_antssm_key, unsigned char *key, size_t key_len);

int mpaas_antssm_threshold_find_symmetric_key(mpaas_antssm_white_box_context_t *white_box,
        mpaas_antssm_antcrypto_key_t *key,
        const unsigned char *key_value, size_t *key_len);

int mpaas_antssm_threshold_gen_sm2_keypair(mpaas_antssm_white_box_context_t *white_box,
                                     const unsigned char *name, size_t name_len,
                                     const unsigned char *password, size_t password_len,
                                     mpaas_antssm_sm2_context_t *sm2_ctx);

int mpaas_antssm_threshold_gen_sm2_keypair_new(mpaas_antssm_white_box_context_t *white_box,
                                     mpaas_antssm_antcrypto_key_t *mpaas_antssm_key,
                                     mpaas_antssm_sm2_context_t *sm2_ctx);

int mpaas_antssm_threshold_find_sm2_keypair(mpaas_antssm_white_box_context_t *white_box,
                                      mpaas_antssm_antcrypto_key_t *mpaas_antssm_key,
                                      mpaas_antssm_sm2_context_t *sm2_ctx);

int
mpaas_antssm_threshold_import_sm2_private_key(mpaas_antssm_white_box_context_t *white_box,
                                        const unsigned char name[16],
                                        const unsigned char pwd[16],
                                        const unsigned char prikey[32],
                                        mpaas_antssm_sm2_context_t *sm2);

int mpaas_antssm_threshold_remove_keypair(mpaas_antssm_white_box_context_t *white_box,
                                    int algorithm,
                                    const unsigned char *name, size_t name_len);

/**
 * @brief SM2门限解密
 * @param ctx
 * @param f_rng
 * @param p_rng
 * @param md_type
 * @param name
 * @param pwd
 * @param in
 * @param inlen
 * @param out
 * @param outlen
 * @return
 */
int mpaas_antssm_threshold_sm2_decrypt(mpaas_antssm_white_box_context_t *white_box,
                                 mpaas_antssm_md_type_t md_type,
                                 const unsigned char name[16],
                                 const unsigned char pwd[16],
                                 const unsigned char *in,
                                 size_t inlen,
                                 unsigned char *out,
                                 size_t *outlen,
                                 int (*f_rng)(void *, unsigned char *, size_t),
                                 void *p_rng, mpaas_antssm_antcrypto_key_t *key);

int mpaas_antssm_threshold_gen_sm2_signature(mpaas_antssm_white_box_context_t *white_box,
                                       const unsigned char name[16], const unsigned char pwd[16],
                                       const unsigned char hash[32],
                                       mpaas_antssm_mpi_t *r, mpaas_antssm_mpi_t *s,
                                       mpaas_antssm_antcrypto_key_t *mpaas_antssm_key);

int mpaas_antssm_threshold_find_sm2_key_share(mpaas_antssm_white_box_context_t *white_box,
                                        const unsigned char name[16],
                                        const unsigned char pwd[16],
                                        int seq, mpaas_antssm_mpi_t *d1,
                                        mpaas_antssm_mpi_t *b1,
                                        mpaas_antssm_antcrypto_key_t *key);

int mpaas_antssm_threshold_store_sm2_key_share(mpaas_antssm_white_box_context_t *white_box,
                                         const unsigned char name[16],
                                         const unsigned char pwd[16],
                                         int seq, const mpaas_antssm_mpi_t *d1,
                                         const mpaas_antssm_mpi_t *b1,
                                         mpaas_antssm_antcrypto_key_t *mpaas_antssm_key);

int mpaas_antssm_threshold_change_sm2_password(mpaas_antssm_white_box_context_t *white_box,
                                         const unsigned char name[16],
                                         const unsigned char old_passwd[16],
                                         const unsigned char new_passwd[16]);

int mpaas_antssm_threshold_store_sm2_public_key(mpaas_antssm_white_box_context_t *white_box,
                                          const unsigned char name[16],
                                          const mpaas_antssm_ecp_point_t *dG,
                                          mpaas_antssm_antcrypto_key_t *mpaas_antssm_key);

int mpaas_antssm_threshold_find_sm2_public_key(mpaas_antssm_white_box_context_t *white_box,
                                         const unsigned char name[16],
                                         mpaas_antssm_ecp_point_t *dG,
                                         mpaas_antssm_antcrypto_key_t *mpaas_antssm_key);

int mpaas_antssm_threshold_point_mul(mpaas_antssm_mpi_t *d1, mpaas_antssm_mpi_t *d2,
                               mpaas_antssm_ecp_point_t *C, mpaas_antssm_ecp_point_t *dC);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_THRESHOLD_H */
