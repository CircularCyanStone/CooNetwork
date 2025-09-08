#ifndef ANTSSM_INTERFACE_H
#define ANTSSM_INTERFACE_H

#include <stdarg.h>
#include <stdlib.h>

typedef int STATUS;
#define SGD_SM2 0x00020100
#define SGD_RSA2048 0x00010000
#define SGD_RSA2048_EMSA_PKCS1_v1_5_NO_ALGORITHM 0x00010001
#define SGD_SM4_ECB 0x00000401
#define SGD_SM4_CBC 0x00000402
#define SGD_SM4_CTR 0x00000404
#define SGD_AES128_ECB 0x00001001
#define SGD_AES128_CBC 0x00001002
#define SGD_3DES_ECB 0x00002001
#define SGD_3DES_CBC 0x00002002
#define SGD_SHA256 0x00000004
#define SGD_SM3 0x00000001
#define SGD_ECDSA_SECP256K1 0x00004001
#define SGD_ECDSA_SECP256K1_rsv 0x00004002

#define STATUS_success 0
#define STATUS_uninit 1
#define STATUS_selftest 2

#define STATUS_prikey_lenerror -10001
#define STATUS_pubkey_lenerror -10002
#define STATUS_plain_lenerror -10003
#define STATUS_cipher_lenerror -10004
#define STATUS_cipherkey_lenerror -10005
#define STATUS_other_lenerror -10006
#define STATUS_prikey_formaterror -10007
#define STATUS_pubkey_formaterror -10008
#define STATUS_plain_formaterror -10009
#define STATUS_cipher_formaterror -10010
#define STATUS_cipherkey_formaterror -10011
#define STATUS_other_formaterror -10012
#define STATUS_buffer_tooshort -10013
#define STATUS_diskfile_error -10014
#define STATUS_FileOpen_error -10015
#define STATUS_handlenotexist -10016
#define STATUS_malloc_fail -10017
#define STATUS_notsupport -10018
#define STATUS_gen_crypt_key_fail -10019
#define STATUS_null_pointer_error -10020
#define STATUS_session_key_load_error -10021
#define STATUS_algorithm_support_error -10022
#define STATUS_login_error -10023
#define STATUS_timestamp_get_error -10024
#define STATUS_password_length_error -10025
#define STATUS_keypair_check_fail -10026
#define STATUS_userid_length_error -10027
#define STATUS_root_check_fail -10028
#define STATUS_root_su_file -10029
#define STATUS_root_system_dir -10030
#define STATUS_root_euid -10031
#define STATUS_getenv_fail -10032


#define STATUS_MPI_error -20000
#define STATUS_WHITEBOX_INPUT_toolong -20001
#define STATUS_WHITEBOX_Encrypt_fail -20002
#define STATUS_File_contentlen_error -20003
#define STATUS_WHITEBOX_hash_error -20004
#define STATUS_WHITEBOX_Decrypt_fail -20005
#define STATUS_Getfinger_fail -20006
#define STATUS_key_hash_error -20007
#define STATUS_algo_error -20008
#define STATUS_rnd_error -20009
#define STATUS_Andriod_APK_error -20010
#define STATUS_FILE_integrity_error -20011
#define STATUS_key_exit_error -20012
#define STATUS_undefinederror -99999

#ifndef true
#define true 1
#endif

#ifndef false
#define false 0
#endif

#define SIGNATURE_VERIFY_PASS 1
#define SIGNATURE_VERIFY_FAIL 0

#ifdef WASM
    #include <emscripten/emscripten.h>
    #define API_EXPORT EMSCRIPTEN_KEEPALIVE
#else
    #define API_EXPORT __attribute__ ((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

API_EXPORT
int asym_keygeneration(unsigned char name[16], unsigned char pwd[16], int ALG_ID, int OnDisk);

API_EXPORT
int asym_sign(unsigned char name[16], unsigned char pwd[16], int ALG_ID,
              unsigned char *message, int messageLen, unsigned char *signaturebuf,
              int signaturebufLen, int *signatureLen);

API_EXPORT
int asym_getpubkey(unsigned char name[16], unsigned char pwd[16], int ALG_ID,
                   unsigned char *pubkeybuf, int pubkeybufLen, int *pubkeyLen);

API_EXPORT
int asym_verify_ex(int ALG_ID, unsigned char *pubkey, int pubkeyLen,
                   unsigned char *message, int messageLen, unsigned char *signature,
                   int signatureLen, int *success);

API_EXPORT
int asym_verify(unsigned char name[16], unsigned char pwd[16], int ALG_ID,
                unsigned char *message, int messageLen, unsigned char *signature,
                int signatureLen, int *success);

API_EXPORT
int asym_encrypt_ex(int ALG_ID, unsigned char *pubkey, int pubkeyLen,
                    unsigned char *plain, int plainLen, unsigned char *cipherbuf,
                    int cipherbufLen, int *cipherLen);

API_EXPORT
int asym_encrypt(unsigned char name[16], unsigned char pwd[16], int ALG_ID, unsigned char *plain,
                 int plainLen, unsigned char *cipherbuf, int cipherbufLen, int *cipherLen);

API_EXPORT
int asym_decrypt(unsigned char name[16], unsigned char pwd[16], int ALG_ID, unsigned char *cipher,
                 int cipherLen, unsigned char *plainbuf, int plainbufLen, int *plainLen);

API_EXPORT
int SM2_Agreement_tempkey(int *temprikeyhandleid, unsigned char temppubkey[64]);

API_EXPORT
int SM2_Agreement_result(unsigned char name[16], unsigned char pwd[16], int isserver, int temprikeyhandleid,
                         unsigned char Owntemppubkey[64], unsigned char otherpubkey[64],
                         unsigned char othertemppubkey[64], int agreeLen, unsigned char *agreebuf);

API_EXPORT
int asym_deletekey(unsigned char name[16], unsigned char pwd[16]);

API_EXPORT
int asym_keyimport(unsigned char name[16], unsigned char pwd[16], int ALG_ID, int OnDisk, unsigned char *prikey,
                   int prikeyLen);

API_EXPORT
int sym_keyimport(unsigned char *key, int keyLen, int *handleid);

API_EXPORT
int sym_encrypt(int handleid, int ALG_ID, unsigned char IV[16], unsigned char *plain, int plainLen,
                unsigned char *cipherbuf,
                int cipherbufLen, int *cipherLen);

API_EXPORT
int sym_decrypt(int handleid, int ALG_ID, unsigned char IV[16], unsigned char *cipher, int cipherLen,
                unsigned char *plainbuf, int plainbufLen, int *plainLen);

API_EXPORT
int sym_deletekey(int handleid);

API_EXPORT
int Hash(int ALG_ID, unsigned char *message, int messageLen, unsigned char hashresult[32]);

API_EXPORT
int Hmac(int handleid, int ALG_ID, unsigned char *message, int messageLen,
         unsigned char hashresult[32]); //only support 128bits key now
API_EXPORT
int Getrandom(unsigned char *randbuf, int randLen);

//advanced interface
API_EXPORT
int asym_encryptedkeyimport(unsigned char name[16], unsigned char pwd[16], int ALG_ID,
                            int OnDisk, unsigned char *prikey_encrypted, int prikeyLen);

API_EXPORT
int
symGenerate_asymencrypt(int sym_ALG_ID, int asym_ALG_ID, unsigned char *pubkey, int pubkeyLen, unsigned char *cipherbuf,
                        int cipherbufLen, int *cipherLen, int *handleid);

API_EXPORT
int asymdecrypt_symimport(int asym_ALG_ID, unsigned char name[16], unsigned char pwd[16], unsigned char *cipher,
                          int cipherLen, int *handleid);

API_EXPORT
int mpaas_antssm_entropy_get_protect_key(unsigned char *buf, int buflen, int *outlen);

API_EXPORT
int mpaas_antssm_entropy_add(const unsigned char *buf, int buflen);

API_EXPORT
double mpaas_antssm_entropy_get_margin_percent();

API_EXPORT
int mpaas_antssm_session_gen_token(const unsigned char *password, size_t password_len,
                             unsigned char *token, size_t *token_len);

API_EXPORT
int mpaas_antssm_session_login(const unsigned char *token, size_t token_len);

API_EXPORT
int mpaas_antssm_session_logout();

API_EXPORT
int mpaas_antssm_session_modify_password(const unsigned char *old_password, size_t old_password_len,
                                   const unsigned char *new_password, size_t new_password_len);

API_EXPORT
int mpaas_antssm_store_share_set_userid(const unsigned char userid[16]);

API_EXPORT
int mpaas_antssm_store_share_generate_register(const unsigned char name[16],
                                         const unsigned char password[16],
                                         int algorithm_id,
                                         unsigned char *buf,
                                         size_t *buflen);

API_EXPORT
int mpaas_antssm_store_share_generate_get(const unsigned char name[16],
                                    const unsigned char password[16],
                                    int algorithm_id,
                                    unsigned char *buf,
                                    size_t *buflen);

API_EXPORT
int mpaas_antssm_store_share_input(const unsigned char name[16],
                             const unsigned char password[16],
                             int algorithm_id,
                             const unsigned char *buf,
                             size_t buflen);

//store interface
API_EXPORT
int SetDirectory(char *dirname, int dirnamelen);

API_EXPORT
int Getversion(int *status, int *version);

API_EXPORT
int CheckIntegrity(void);

/**
 * 注入日志实现
 */
API_EXPORT
int mpaas_antssm_log_setup(const char *name,
                     void *impl_ctx,
                     int (*mpaas_antssm_log_digest_function)(void *ctx, const char *format, va_list args),
                     int (*mpaas_antssm_log_debug_function)(void *ctx, const char *format, va_list args),
                     int (*mpaas_antssm_log_info_function)(void *ctx, const char *format, va_list args),
                     int (*mpaas_antssm_log_warn_function)(void *ctx, const char *format, va_list args),
                     int (*mpaas_antssm_log_error_function)(void *ctx, const char *format, va_list args));

#if defined(ANTSSM_SELF_TEST)
int interface_asym_self_test( int verbose );
int interface_sym_others_self_test( int verbose );
#endif

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_INTERFACE_H */
