#if !defined(AntGM_SM4)
    #define AntGM_SM4
    /*########################################################################*/
    #include <openssl/e_os2.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if !defined(OPENSSL_NO_SM4)
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #include <stddef.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #define AntGM_SM4_KEY_LENGTH 16
    #define AntGM_SM4_BLOCK_SIZE 16
    #define AntGM_SM4_IV_LENGTH  AntGM_SM4_BLOCK_SIZE
    #define AntGM_SM4_NUM_ROUNDS 32
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    #define AntGM_SM4_ENCRYPT 1
    #define AntGM_SM4_DECRYPT 0
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    #if !defined(AntGM_BUILD)
        #define SM4_KEY_LENGTH   AntGM_SM4_KEY_LENGTH
        #define SM4_BLOCK_SIZE   AntGM_SM4_BLOCK_SIZE
        #define SM4_IV_LENGTH    AntGM_SM4_IV_LENGTH
        #define SM4_NUM_ROUNDS   AntGM_SM4_NUM_ROUNDS
        #define SM4_ENCRYPT      AntGM_SM4_ENCRYPT
        #define SM4_DECRYPT      AntGM_SM4_DECRYPT
        #define sm4_key_st       AntGM_sm4_key_st
        #define SM4_KEY          AntGM_SM4_KEY
        #define SM4_set_key      AntGM_SM4_set_key
        #define SM4_encrypt      AntGM_SM4_encrypt
        #define SM4_decrypt      AntGM_SM4_decrypt
        #define SM4_ecb_encrypt  AntGM_SM4_ecb_encrypt
        #define SM4_cbc_encrypt  AntGM_SM4_cbc_encrypt
        #define SM4_cfb_encrypt  AntGM_SM4_cfb_encrypt
        #define SM4_cfb1_encrypt AntGM_SM4_cfb1_encrypt
        #define SM4_cfb8_encrypt AntGM_SM4_cfb8_encrypt
        #define SM4_ofb_encrypt  AntGM_SM4_ofb_encrypt
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    typedef struct AntGM_sm4_key_st {
        uint32_t key[AntGM_SM4_NUM_ROUNDS];
    } AntGM_SM4_KEY;
    /*========================================================================*/
    int AntGM_SM4_set_key(const unsigned char *user_key,
                          size_t               length,
                          AntGM_SM4_KEY       *key);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_encrypt(const unsigned char *in,
                           unsigned char       *out,
                           const AntGM_SM4_KEY *key);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_decrypt(const unsigned char *in,
                           unsigned char       *out,
                           const AntGM_SM4_KEY *key);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_ecb_encrypt(const unsigned char *in,
                               unsigned char       *out,
                               size_t               length,
                               const AntGM_SM4_KEY *key,
                               const int            enc);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_cbc_encrypt(const unsigned char *in,
                               unsigned char       *out,
                               size_t               length,
                               const AntGM_SM4_KEY *key,
                               unsigned char       *ivec,
                               const int            enc);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_cfb_encrypt(const unsigned char *in,
                               unsigned char       *out,
                               size_t               length,
                               const AntGM_SM4_KEY *key,
                               unsigned char       *ivec,
                               int                 *num,
                               const int            enc);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_cfb1_encrypt(const unsigned char *in,
                                unsigned char       *out,
                                size_t               length,
                                const AntGM_SM4_KEY *key,
                                unsigned char       *ivec,
                                int                 *num,
                                const int            enc);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_cfb8_encrypt(const unsigned char *in,
                                unsigned char       *out,
                                size_t               length,
                                const AntGM_SM4_KEY *key,
                                unsigned char       *ivec,
                                int                 *num,
                                const int            enc);
    /*------------------------------------------------------------------------*/
    void AntGM_SM4_ofb_encrypt(const unsigned char *in,
                               unsigned char       *out,
                               size_t               length,
                               const AntGM_SM4_KEY *key,
                               unsigned char       *ivec,
                               int                 *num);
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #endif
    /*########################################################################*/
#endif
