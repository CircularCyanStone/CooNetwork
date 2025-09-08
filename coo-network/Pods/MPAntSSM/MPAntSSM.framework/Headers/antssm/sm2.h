#ifndef ANTSSM_SM2_H
#define ANTSSM_SM2_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "ecp.h"
#include "md.h"

#define ANTSSM_ERR_SM2_BAD_INPUT_DATA        -0X5A00
#define ANTSSM_ERR_SM2_INVALID_INPUT_LENGTH  -0x5A80
#define ANTSSM_ERR_SM2_BUFFER_TOO_SMALL      -0x5B00
#define ANTSSM_ERR_SM2_ALLOC_FAILED          -0x5B80
#define ANTSSM_ERR_SM2_DECRYPT_FAILED        -0x5C00
#define ANTSSM_ERR_SM2_SIGN_FAILED           -0x5C80
#define ANTSSM_ERR_SM2_VERIFY_FAILED         -0x5D00
#define ANTSSM_ERR_SM2_ENCRYPT_FAILED        -0x5D80

#ifdef  __cplusplus
extern "C" {
#endif

/**
 * \brief SM2上下文环境
 */
typedef mpaas_antssm_ecp_keypair_t mpaas_antssm_sm2_context_t;

/**
 * @brief SM2上下文初始化
 * @param ctx
 */
void mpaas_antssm_sm2_init(mpaas_antssm_sm2_context_t *ctx);

/**
 * @brief SM2上下文释放
 * @param ctx
 */
void mpaas_antssm_sm2_free(mpaas_antssm_sm2_context_t *ctx);

int mpaas_antssm_sm2_gen_key(mpaas_antssm_sm2_context_t *ctx,
                        int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);

size_t mpaas_antssm_sm2_get_len(const mpaas_antssm_sm2_context_t *ctx);

/*X9.63 Key Derive Function*/

int mpaas_antssm_sm2_kdf_x9_63(unsigned char *out, size_t outlen,
                         const unsigned char *Z, size_t Zlen,
                         const unsigned char *SharedInfo, size_t SharedInfolen,
                         const mpaas_antssm_md_info_t *md);

/**
 * @brief 获取SM2签名的中间结果Z
 * @param ctx
 * @param md_info
 * @param uid
 * @param uid_len
 * @param z_buf
 * @param z_len
 * @return
 */
int mpaas_antssm_sm2_get_z(mpaas_antssm_sm2_context_t *ctx, const mpaas_antssm_md_info_t *md_info,
                     const char *uid, int uid_len,
                     unsigned char *z_buf, size_t *z_len);

/**
 * \brief SM2 签名预计算
 * \param ctx
 * \param md_alg
 * \param msg
 * \param msg_len
 * \param buffer
 * \param buffer_len
 * \return
 */
int
mpaas_antssm_sm2_sig_pre_compute(mpaas_antssm_sm2_context_t *ctx, mpaas_antssm_md_type_t md_alg,
                           const unsigned char *msg, size_t msg_len,
                           unsigned char *buffer, size_t *buffer_len);

/**
 * @brief 加密
 * @param ctx
 * @param f_rng
 * @param p_rng
 * @param md_type
 * @param in
 * @param inlen
 * @param out
 * @param outlen
 * @return
 */
int mpaas_antssm_sm2_encrypt(mpaas_antssm_sm2_context_t *ctx,
                       mpaas_antssm_md_type_t md_type,
                       const unsigned char *in,
                       size_t inlen,
                       unsigned char *out,
                       size_t *outlen,
                       int (*f_rng)(void *, unsigned char *, size_t),
                       void *p_rng);

/**
 * @brief 解密
 * @param ctx
 * @param f_rng
 * @param p_rng
 * @param md_type
 * @param in
 * @param inlen
 * @param out
 * @param outlen
 * @return
 */
int mpaas_antssm_sm2_decrypt(mpaas_antssm_sm2_context_t *ctx,
                       mpaas_antssm_md_type_t md_type,
                       const unsigned char *in,
                       size_t inlen,
                       unsigned char *out,
                       size_t *outlen,
                       int (*f_rng)(void *, unsigned char *, size_t),
                       void *p_rng);

int mpaas_antssm_sm2_write_signature(mpaas_antssm_sm2_context_t *ctx,
                               const unsigned char *hash, size_t hlen,
                               unsigned char *sig, size_t *slen,
                               int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng);

int mpaas_antssm_sm2_read_signature(mpaas_antssm_sm2_context_t *ctx,
                              const unsigned char *hash, size_t hlen,
                              const unsigned char *sig, size_t slen);

/**
 * @brief SM2签名
 * @param ctx
 * @param f_rng
 * @param p_rng
 * @param buf
 * @param blen
 * @param r
 * @param s
 * @return
 */
int mpaas_antssm_sm2_sign(mpaas_antssm_sm2_context_t *ctx,
                    const unsigned char *buf,
                    size_t blen,
                    mpaas_antssm_mpi_t *r,
                    mpaas_antssm_mpi_t *s,
                    int (*f_rng)(void *, unsigned char *, size_t),
                    void *p_rng);

int mpaas_antssm_sm2_sig_to_asn1( const mpaas_antssm_mpi_t *r, const mpaas_antssm_mpi_t *s,
                            unsigned char *sig, size_t *slen );

/**
 * @brief SM2验签
 * @param ctx
 * @param buf
 * @param blen
 * @param r
 * @param s
 * @return
 */
int mpaas_antssm_sm2_verify(mpaas_antssm_sm2_context_t *ctx,
                      const unsigned char *buf,
                      size_t blen,
                      const mpaas_antssm_mpi_t *r,
                      const mpaas_antssm_mpi_t *s);
API_EXPORT
int mpaas_antssm_sm2_kap_compute_key(void *out, size_t outlen, int server,
                               const char *peer_uid, int peer_uid_len, const char *self_uid, int self_uid_len,
                               const mpaas_antssm_sm2_context_t *peer_ecdhe_key, const mpaas_antssm_sm2_context_t *self_ecdhe_key,
                               const mpaas_antssm_sm2_context_t *peer_pub_key, const mpaas_antssm_sm2_context_t *self_eckey,
                               const mpaas_antssm_md_info_t *md, int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng);

int
mpaas_antssm_sm2_thred_kap_compute_key(unsigned char name[16], unsigned char pwd[16], void *out, size_t outlen, int server,
                                 const char *peer_uid, int peer_uid_len, const char *self_uid, int self_uid_len,
                                 const mpaas_antssm_sm2_context_t *peer_ecdhe_key, const mpaas_antssm_sm2_context_t *self_ecdhe_key,
                                 const mpaas_antssm_sm2_context_t *peer_pub_key, const mpaas_antssm_sm2_context_t *self_eckey,
                                 const mpaas_antssm_md_info_t *md, int (*f_rng)(void *, unsigned char *, size_t),
                                 void *p_rng);

int mpaas_antssm_i2d_sm2_enc(const unsigned char *in, size_t inlen, unsigned char **out, size_t *out_len);

/**
 * \brief          Checkup routine
 *
 * \return         0 if successful, or 1 if the test failed
 */
int mpaas_antssm_sm2_self_test(int verbose);

#ifdef  __cplusplus
}
#endif

#endif                          /* ANTSSM_SM2_H */
