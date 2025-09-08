/*
 * Created by jinbei on 2020/1/5.
 */
#ifndef ANTSSM_ANTCRYPTO_INTERNAL_H
#define ANTSSM_ANTCRYPTO_INTERNAL_H

#include "antssm/key_rep.h"
#include "antssm/sm4_asm.h"
#include "antssm/sm2.h"

#define ANTSSM_mpaas_AK_NAME_MAX_LENGTH  (16)
#define ANTSSM_mpaas_AK_PASSWORD_MAX_LENGTH  (16)
#define ANTSSM_mpaas_AK_OBJECT_VALUE_MAX_LENGTH  (4096)
#define ANTSSM_mpaas_AK_INSTANCE_ID_MAX_LENGTH (64)
#define ANTSSM_CIPHER_KEY_NAME "ANTSSM_KEY_NAME"

typedef enum {
    ANTSSM_ANTCRYPTO_KEY_CTX_NONE = 0,
    ANTSSM_ANTCRYPTO_KEY_CTX_PK = 1,
    ANTSSM_ANTCRYPTO_KEY_CTX_CIPHER = 2,
    ANTSSM_ANTCRYPTO_KEY_CTX_MD = 3,
} antsssm_api_key_ctx_type;

typedef struct {
    unsigned char name[ANTSSM_mpaas_AK_NAME_MAX_LENGTH];
    size_t name_len;
    unsigned char password[ANTSSM_mpaas_AK_PASSWORD_MAX_LENGTH];
    size_t password_len;
    size_t password_length;
    mpaas_antssm_key_rep_attr_t attr;
    unsigned char value[ANTSSM_mpaas_AK_OBJECT_VALUE_MAX_LENGTH];
    size_t value_length;
    int ctx_type;
    void *ctx;
    void *session;
    mpaas_antssm_sm4_asm_context_t SM4_rk;
    int isSM4_rkvalid;
    char keyid[ANTSSM_mpaas_AK_INSTANCE_ID_MAX_LENGTH];             /*!< 实例标识 */
    size_t cipher_flag;
    size_t symmetric_speed;
    char cipher[4096];
    size_t cipher_len;
    mpaas_antssm_sm2_context_t sm2_internal_ctx;      //used for tmp store the internal encrypt sm2 public key
    unsigned char *sm2_priv_key_in;
} mpaas_antssm_antcrypto_key_t;

int mpaas_antssm_antcrypto_key_init(mpaas_antssm_antcrypto_key_t *key);

int mpaas_antssm_antcrypto_key_free(mpaas_antssm_antcrypto_key_t *key);

int
mpaas_antssm_antcrypto_key_setup(mpaas_antssm_antcrypto_key_t *key, void *session_handle,
                           uint32_t type, uint32_t algorithm,
                           unsigned char *name, size_t name_len,
                           unsigned char *password, size_t password_len);

int mpaas_antssm_antcrypto_key_store_attr(mpaas_antssm_antcrypto_key_t *key);

int mpaas_antssm_antcrypto_key_find_attr(mpaas_antssm_antcrypto_key_t *key,
                                   const unsigned char *name, size_t name_len,
                                   int version);

int mpaas_antssm_antcrypto_key_load_attr(mpaas_antssm_antcrypto_key_t *key);

#endif //ANTSSM_ANTCRYPTO_INTERNAL_H
