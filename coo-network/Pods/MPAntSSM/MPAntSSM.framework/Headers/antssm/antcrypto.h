/*
 * Created by jinbei on 2019/12/24.
 */
#ifndef _ANTCRYPTO_H_
#define _ANTCRYPTO_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>
#include "antssm/sm2.h"
typedef enum {
    mpaas_AK_OBJECT_TYPE_NONE = 0x00000000,
    mpaas_AK_PGP_PUBLIC_KEY = 0x00000001,
    mpaas_AK_PGP_PRIVATE_KEY = 0x00000002,
    mpaas_AK_PRIVATE_KEY = 0x00000003,
    mpaas_AK_PUBLIC_KEY = 0x00000004,
    mpaas_AK_SYMMETRIC_KEY = 0x00000005,
    mpaas_AK_SECRET = 0x00000006,
    mpaas_AK_CERTIFICATE = 0x00000007,
    mpaas_AK_TEMP_SYMMETRIC_KEY = 0x00000008,
    mpaas_AK_TEMP_PRIVATE_KEY = 0x00000009,
    mpaas_AK_TEMP_PUBLIC_KEY = 0x00000000A,
    mpaas_AK_TEMP_CERTIFICATE = 0x00000000B,
    mpaas_AK_TEMP_SECRET = 0x00000000C
} mpaas_AK_ObjectType;

typedef enum {
    mpaas_AK_ALGORITHM_NONE = 0x00000000,
    mpaas_AK_AES128 = 0x00011001,
    mpaas_AK_AES192 = 0x00011002,
    mpaas_AK_AES256 = 0x00011003,
    mpaas_AK_DES = 0x00011004,
    mpaas_AK_TWO_KEY_3DES = 0x00011005,
    mpaas_AK_THREE_KEY_3DES = 0x00011006,
    mpaas_AK_SM4 = 0x00011007,
    mpaas_AK_SM4_XTS = 0x00011008,
    mpaas_AK_RSA1024 = 0x00012001,
    mpaas_AK_RSA2048 = 0x00012002,
    mpaas_AK_RSA4096 = 0x00012003,
    mpaas_AK_ECDSA_P256 = 0x00012004,
    mpaas_AK_SM2 = 0x00012005,
    mpaas_AK_DSA1024 = 0x00012006,
    mpaas_AK_DSA2048 = 0x00012007,
    mpaas_AK_ECDSA_P256_V1 = 0x00012008,
    mpaas_AK_SHA1 = 0x00013001,
    mpaas_AK_SHA256 = 0x00013002,
    mpaas_AK_SHA512 = 0x00013003,
    mpaas_AK_MD5 = 0x00013004,
    mpaas_AK_SM3 = 0x00013005,
    mpaas_AK_NAKED = 0x00013006,
    mpaas_AK_HMAC_SHA1 = 0x00014001,
    mpaas_AK_HMAC_SHA256 = 0x00014002,
    mpaas_AK_HMAC_SHA512 = 0x00014003,
    mpaas_AK_HMAC_MD5 = 0x00014004,
    mpaas_AK_HMAC_SM3 = 0x00014005,
    mpaas_AK_PBE_SHA256_AES128_BC = 0x00015001
} mpaas_AK_Algorithm;

typedef enum {
    mpaas_AK_PADDING_MODE_NONE = 0x00000000,
    mpaas_AK_RSAES_OAEP = 0x00020002,
    mpaas_AK_RSAES_PKCS1_V1_5 = 0x00020003,
    mpaas_AK_RSASSA_PSS = 0x00020004,
    mpaas_AK_RSASSA_PKCS1_V1_5 = 0x00020005,
    mpaas_AK_PKCS5 = 0x00020006,
    mpaas_AK_PKCS7 = 0x00020007,
} mpaas_AK_PaddingMode;

typedef enum {
    mpaas_AK_CBC = 0x00030001,
    mpaas_AK_ECB = 0x00030002,
    mpaas_AK_CFB = 0x00030003,
    mpaas_AK_OFB = 0x00030004,
    mpaas_AK_CTR = 0x00030005,
    mpaas_AK_CCM = 0x00030006,
    mpaas_AK_GCM = 0x00030007,
    mpaas_AK_XTS = 0x00030008
} mpaas_AK_CipherMode;

typedef enum {
    mpaas_AK_USER_PASSWORD = 0x00080001,
    mpaas_AK_DIRECTORY = 0x00080002
} mpaas_AK_CredentialType;

typedef enum {
    mpaas_AK_PLAIN_KEY_FORMAT_NONE = 0x00000000,
    mpaas_AK_KEY_FORMAT_RAW = 0x00090001,
    mpaas_AK_PUBLIC_X509_DER = 0x00090002,
    mpaas_AK_PUBLIC_X509_PEM = 0x00090003,
    mpaas_AK_RSA_PUBLIC_PKCS1_DER = 0x00090004,
    mpaas_AK_RSA_PUBLIC_PKCS1_PEM = 0x00090005,
    mpaas_AK_RSA_PRIVATE_PKCS1_DER = 0x00090006,
    mpaas_AK_RSA_PRIVATE_PKCS1_PEM = 0x00090007,
    mpaas_AK_PRIVATE_PKCS8_PLAIN_DER = 0x00090008,
    mpaas_AK_PRIVATE_PKCS8_PLAIN_PEM = 0x00090009,
    mpaas_AK_PRIVATE_PKCS8_ENCRYPTED_DER = 0x0009000A,
    mpaas_AK_PRIVATE_PKCS8_ENCRYPTED_PEM = 0x0009000B,
    mpaas_AK_SM2_PUBLIC_GMT0009_RAW = 0x0009000C,
    mpaas_AK_SM2_PUBLIC_GMT0009_DER = 0x0009000D,
    mpaas_AK_SM2_PRIVATE_GMT0009_RAW = 0x0009000E,
    mpaas_AK_SM2_PRIVATE_GMT0009_DER = 0x0009000F,
    mpaas_AK_SM2_PRIVATE_ENVELOPED_KEY = 0x00090010,
    mpaas_AK_SM2_PRIVATE_GMT0009_RAW_HEX = 0x00090011,
    mpaas_AK_SM2_PUBLIC_GMT0009_RAW_HEX = 0x00090012,
    mpaas_AK_WHITE_BOX_WRAP_RAW = 0x0009A001,
    mpaas_AK_TEMP_PUBLIC_KEY_SHARED_KEY_WRAP_RAW = 0x0009A002, /*!< 临时公钥共享密钥双重加密 */
    mpaas_AK_KEK_WRAP_RAW = 0x0009A003,         /*!< 主密钥加密数据密钥 */
    mpaas_AK_TEMP_PUBLIC_KEY_WRAP_RAW = 0x0009A004, /*!< 临时公钥加密 */
} mpaas_AK_KeyFormat;

typedef enum {
    mpaas_AK_ATTR_UID = 0x000a0000,
    mpaas_AK_ATTR_NAME = 0x000a0001,
    mpaas_AK_ATTR_VERSION = 0x000a0002,
    mpaas_AK_ATTR_OBJECT_TYPE = 0x000a0003,
    mpaas_AK_ATTR_ALGORITHM = 0x000a0004,
    mpaas_AK_ATTR_HASH_ALGORITHM = 0x000a0005,
    mpaas_AK_ATTR_PADDING_MODE = 0x000a0006,
    mpaas_AK_ATTR_CIPHER_MODE = 0x000a0007,
    mpaas_AK_ATTR_START = 0x000a0008,
    mpaas_AK_ATTR_END = 0x000a0009,
    mpaas_AK_ATTR_KEY_USAGE = 0x000a000a,
    mpaas_AK_ATTR_EXPORT_POLICY = 0x000a000b,
    mpaas_AK_ATTR_LIFE_CYCLE_STATE = 0x000a000c,
    mpaas_AK_ATTR_KEY_PASSWORD = 0x000a000d,
    mpaas_AK_ATTR_SYMMETRIC_SPEED = 0x000a000e,
    mpaas_AK_ATTR_ORIGIN_IV = 0x000a000f,
    mpaas_AK_ATTR_KEY_USERID = 0x00a0010,
    mpaas_AK_ATTR_MASTER_KEY_ID = 0x00aF001,
} mpaas_AK_Attribute;

typedef enum {
    mpaas_AK_SPEED_UP = 0x000b0001,
    mpaas_AK_SPEED_DOWN = 0x000b0002,
    mpaas_AK_UPDATE_IV = 0x000b0003,
    mpaas_AK_NOT_UPDATE_IV = 0x000b0004
} mpaas_AK_UserAttr;

#define mpaas_AK_OK 0
#define mpaas_AK_ERR -1
#define mpaas_AK_ERROR_BASE -0x0E000000
#define mpaas_AK_ERROR_CORRUPTION_DETECTED -0x0E000001
#define mpaas_AK_ERROR_OBJECT_TYPE_INVALID -0x0E010001
#define mpaas_AK_ERROR_BUFFER_TOO_SMALL -0x0E010003
#define mpaas_AK_ERROR_VERIFICATION_FAILED -0x0E010004
#define mpaas_AK_ERROR_NAME_TOO_LONG -0x0E010005
#define mpaas_AK_ERROR_DATA_TOO_LONG -0x0E010006
#define mpaas_AK_ERROR_ARGUMENT_NULL -0x0E010007
#define mpaas_AK_ERROR_ARGUMENT_BAD -0x0E010008
#define mpaas_AK_ERROR_GEN_RN_FAILED -0x0E010009
#define mpaas_AK_ERROR_FILE_OPEN_FAILED -0x0E01000A
#define mpaas_AK_ERROR_FILE_WRITE_FAILED -0x0E01000B
#define mpaas_AK_ERROR_DATA_LEN_RANGE -0x0E01000C
#define mpaas_AK_ERROR_CRYPT_MODE_BAD -0x0E01000D
#define mpaas_AK_ERROR_PASSWORD_TOO_LONG -0x0E01000E
#define mpaas_AK_ERROR_NAME_EXIST -0x0E01000F

#define mpaas_AK_ERROR_OBJECT_NOT_FOUND -0x0E050001
#define mpaas_AK_ERROR_ALGORITHM_UNSUPPORT -0x0E050004
#define mpaas_AK_ERROR_OBJECT_TYPE_UNSUPPORT -0x0E050005
#define mpaas_AK_ERROR_FORMAT_UNSUPPORT -0x0E050006
#define mpaas_AK_ERROR_ATTRIBUTE_TYPE_UNSUPPORT -0x0E050007
#define mpaas_AK_ERROR_CREDENTIAL_TYPE_UNSUPPORT -0x0E050008
#define mpaas_AK_ERROR_CIPHER_MODE_UNSUPPORT -0x0E050009
#define mpaas_AK_ERROR_KEK_TYPE_UNSUPPORT -0x0E05000A
#define mpaas_AK_ERROR_CURVE_ECDSA_FAILED 0x0E05000B
#define mpaas_AK_ERROR_CURVE_ECDSA_V1_FAILED 0x0E05000C
#define mpaas_AK_ERROR_WHITEBOX_CTX_NULL 0x0E05000D
#define mpaas_AK_ERROR_SYMMETRIC_SPEED_UP_FAILED 0x0E05000E
#define mpaas_AK_ERROR_WHITEBOX_LEN_FAILED 0x0E05000F
#define mpaas_AK_ERROR_LOGIN_WITH_WHITEBOX_FAILED 0x0E050010
#define mpaas_AK_ERROR_mpaas_AK_IMPORTOBJECT_FAILED 0x0E050011
#define mpaas_AK_ERROR_mpaas_AK_ENCRYPT_FAILED 0x0E050012
#define mpaas_AK_ERROR_CIPHER_WHITEBOX_KEY_LEN_FAILED 0x0E050013
#define mpaas_AK_ERROR_WHITEBOX_LEN_TOO_SMALL_FAILED 0x0E050014
#define mpaas_AK_ERROR_mpaas_AK_CONVERT_PLAINKY_TO_CIPHERKEY_FAILED 0x0E050015
#define mpaas_AK_ERROR_CIPHER_DATA_LEN_FAILED 0x0E050016
#define mpaas_AK_ERROR_CIPHER_MODE_FAILED 0x0E050017
#define mpaas_AK_ERROR_PADDING_MODE_FAILED 0x0E050018
#define mpaas_AK_ERROR_IV_LEN_FAILED 0x0E050019
#define mpaas_AK_ERROR_PLAIN_DATA_LEN_FAILED 0x0E050020
#define mpaas_AK_ERROR_ALGORITHM_FAILED 0x0E050021
#define mpaas_AK_ERROR_HMAC_KEY_LEN_TOO_SHORT_FAILED 0x0E050022
#define mpaas_AK_ERROR_SM2_PRIVATE_KEY_LEN_NOT_32 0xE050023
#define mpaas_AK_ERROR_SM2_PUBLIC_KEY_LEN_NOT_64 0xE050024
#define mpaas_AK_ERROR_CIPHER_KEY_LEN_TOO_BIG 0xE050025
#define mpaas_AK_ERROR_ATTRIBUTE_USERID_LEN_EXCEED_8192_1 0xE050026;
#define mpaas_AK_ERROR_PRIV_KEY_INVALID 0xE050027;


#define mpaas_AK_ERROR_MALLOC_FAIL -0x0E060003
#define mpaas_AK_ERROR_FUNCTION_UNSUPPORT -0x0EFF0001


int32_t mpaas_AK_Login(uint32_t type, const char *credential, void **phSession);

int32_t mpaas_AK_Login_with_whitebox(uint32_t type, const char *credential, void **phSession, const char *white_box);

int32_t mpaas_AK_Logout(void *hSession);

int32_t mpaas_AK_Logout_by_key(void *object);

int32_t mpaas_AK_set_key_session(void *object, void *session);

int32_t mpaas_AK_release_wb_object(void *object);

int32_t mpaas_AK_symmetric_kdf(unsigned char *info, size_t info_len, unsigned char *Z, size_t Zlen, unsigned char *out, size_t *outlen);

int32_t mpaas_AK_gen_sm2_object_with_priv_key(void *session_handle, unsigned char *priv_key, size_t priv_key_len, void **object);

int32_t mpaas_AK_GenerateObject(void *session, const char *name, uint32_t ObjectType,
                          uint32_t algorithm, void **object);

int32_t mpaas_AK_gen_cipher_key(void *session_handle,
                          uint32_t object_type, uint32_t algorithm,
                          const unsigned char *password, uint32_t password_len,
                          unsigned char *cipher, uint32_t *cipher_len, void **object);

int32_t mpaas_AK_import_cipher_key(void *session_handle, 
                             const unsigned char *password, uint32_t password_len,
                             const unsigned char *cipher, uint32_t cipher_len,
                             void **object);

int32_t mpaas_AK_convert_plainkey_to_cipherkey(void *session_handle,
                        uint32_t object_type, uint32_t algorithm,
                        uint32_t format,
                        const unsigned char *plain_key, uint32_t plain_key_len,
                        const unsigned char *password, uint32_t password_len,
                        unsigned char *cipher_key, uint32_t *cipher_key_len,
                        void **object);

int32_t mpaas_AK_FindObjectbyName(void *hSession, const char *Name, uint32_t Version,
                            void **phObject);

int32_t mpaas_AK_FindObjectbyUID(void *hSession, uint64_t UID, void **phObject);

int32_t mpaas_AK_ImportObject(void *hSession, const char *Name, uint32_t ObjectType,
                        uint32_t Algorithm, uint32_t Format,
                        const unsigned char *Data, uint32_t DataLen,
                        void **phObject);

int32_t mpaas_AK_KeyLogin(void *object, const unsigned char *key_password,
                    uint32_t key_password_len);

int32_t mpaas_AK_ImportEncryptedObject(void *hSession, const char *Name, uint32_t ObjectType,
                         uint32_t Algorithm, uint32_t Format, void *hKEK,
                         const unsigned char *Cipher, uint32_t CipherLen,
                         void **phObject);

int32_t mpaas_AK_SetAttr(void *hObject, uint32_t Attribute, const unsigned char *Data,
                   uint32_t DataLen);

int32_t mpaas_AK_GetAttr(void *hObject, uint32_t Attribute, unsigned char *Buf,
                   uint32_t *BufLen);
int32_t mpaas_AK_GetMaxVersion(void *hObject, uint32_t *Version);
int32_t mpaas_AK_ExportObject(void *hObject, uint32_t Format, unsigned char *Buf,
                        uint32_t *BufLen);
int32_t mpaas_AK_ExportEncryptedObject(void *hObject, uint32_t Format, void *hKEK,
                                 unsigned char *Buf, uint32_t *BufLen);
int32_t mpaas_AK_Encrypt_exIV(void *hObject, const unsigned char *Plain, uint32_t PlainLen,
                   unsigned char *IVout, uint32_t *IVLen, unsigned char *Buf,
                   uint32_t *BufLen);
int32_t mpaas_AK_Encrypt(void *hObject, const unsigned char *Plain, uint32_t PlainLen,
                   unsigned char *IVout, uint32_t *IVLen, unsigned char *Buf,
                   uint32_t *BufLen);
int32_t mpaas_AK_Decrypt(void *hObject, const unsigned char *Cipher, uint32_t CipherLen,
           const unsigned char *IV, uint32_t IVLen, unsigned char *Buf,
           uint32_t *BufLen);
int32_t mpaas_AK_encrypt_by_whitebox(void *session, const unsigned char *plain, uint32_t plain_len,
                   unsigned char *cipher, uint32_t *cipher_len, int padding_mode, uint32_t encrypt_level);

int32_t mpaas_AK_decrypt_by_whitebox(void *session, const unsigned char *cipher, uint32_t cipher_len,
                   unsigned char *plain, uint32_t *plain_len, int padding_mode, uint32_t decrypt_level);
int32_t mpaas_AK_Sign(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
                unsigned char *Buf, uint32_t *BufLen);
int32_t mpaas_AK_Verify(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
                  const unsigned char *Sign, uint32_t SignLen);
int32_t mpaas_AK_Sign_Iot(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
                    unsigned char *Buf, uint32_t *BufLen);
int32_t mpaas_AK_Verify_Iot(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
                      const unsigned char *Sign, uint32_t SignLen);
int32_t mpaas_AK_Hash(void *hSession, uint32_t Algorithm, const unsigned char *Msg,
                uint32_t MsgLen, unsigned char *Buf, uint32_t *BufLen);
int32_t mpaas_AK_GetRandom(void *hSession, unsigned char *Buf, uint32_t BufLen);
int32_t mpaas_AK_MAC(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
               unsigned char *Buf, uint32_t *BufLen);
int32_t mpaas_AK_MACVerify(void *hObject, const unsigned char *Msg, uint32_t MsgLen,
                     unsigned char *MAC, uint32_t MACLen);
int32_t mpaas_AK_UpdateObject(void *hObject);
int32_t mpaas_AK_DeleteObject(void *hObject);
int32_t mpaas_AK_ReleaseObjectHandle(void* hObject);
int32_t mpaas_AK_Format(uint32_t iFormat, const unsigned char *Data, uint32_t DataLen,
                  uint32_t oFormat, unsigned char *Buf, uint32_t *BufLen);
//advanced interface
int32_t mpaas_AK_GetShareKeyId(void *session, unsigned char *buffer, uint32_t *buffer_len);
int32_t mpaas_AK_EncryptPosition(void* hObject, const unsigned char* Plain,uint32_t PlainLen,uint64_t Offset,const unsigned char* IV,uint32_t IVLen,unsigned char* Buf,uint32_t* BufLen);
int32_t mpaas_AK_DecryptPosition(void* hObject, const unsigned char* Cipher,uint32_t CipherLen,uint64_t Offset,const unsigned char* IV,uint32_t IVLen,unsigned char* Buf,uint32_t* BufLen);
int32_t mpaas_AK_sign_by_user_private_key(const unsigned char *data_base64, unsigned char *cipher_key_base64, unsigned char *password, unsigned char *signature, int* sign_len);
int32_t mpaas_AK_get_ec_keypair_t_size();
int32_t mpaas_AK_get_sm2_group_id();
const void *mpaas_AK_get_md_info();
void mpaas_AK_ecp_keypair_free(void *key);
int32_t mpaas_AK_ecp_cal_key_with_private_key(int grp_id, void *key, const char *priv_hex,int (*f_rng)(void *, unsigned char *, size_t), void *p_rng);
int32_t mpaas_AK_ecp_cal_key_with_public_key(int grp_id, void *key, const char *pub_hex_x, const char *pub_hex_y);
int32_t mpaas_AK_sm2_kap_compute_key(void *out, size_t outlen, int server,
                               const char *peer_uid, int peer_uid_len,
                               const char *self_uid, int self_uid_len,
                               void *peer_ecdhe_key,
                               void *self_ecdhe_key,
                               void *peer_pub_key,
                               void *self_et,
                               const void *md,
                               int (*f_rng)(void *, unsigned char *, size_t),
                               void *p_rng);
#ifdef __cplusplus
}
#endif

#endif //_ANTCRYPTO_H_
