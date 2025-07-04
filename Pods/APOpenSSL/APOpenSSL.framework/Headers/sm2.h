#if !defined(AntGM_SM2)
    #define AntGM_SM2
    /*########################################################################*/
    #include <openssl/evp.h>
    #include <openssl/ec.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if !defined(OPENSSL_NO_SM2)
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #include <stddef.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if !defined(AntGM_BUILD)
        #define sm2dh_data_st             AntGM_sm2dh_data_st
        #define SM2DH_DATA                AntGM_SM2DH_DATA
        #define sm2enc_st                 AntGM_sm2enc_st
        #define SM2ENC                    AntGM_SM2ENC
        #define KDF_X9_63                 AntGM_KDF_X9_63
        #define ECDSA_sm2_get_Z           AntGM_ECDSA_sm2_get_Z
        #define sm2_do_sign               AntGM_sm2_do_sign
        #define sm2_do_verify             AntGM_sm2_do_verify
        #define sm2_encrypt               AntGM_sm2_encrypt
        #define sm2_decrypt               AntGM_sm2_decrypt
        #define old_sm2_encrypt           AntGM_old_sm2_encrypt
        #define old_sm2_decrypt           AntGM_old_sm2_decrypt
        #define SM2DH_get_ex_data_index   AntGM_SM2DH_get_ex_data_index
        #define SM2DH_set_ex_data         AntGM_SM2DH_set_ex_data
        #define SM2DH_get_ex_data         AntGM_SM2DH_get_ex_data
        #define SM2DH_prepare             AntGM_SM2DH_prepare
        #define SM2DH_compute_key         AntGM_SM2DH_compute_key
        #define SM2DH_get_ensure_checksum AntGM_SM2DH_get_ensure_checksum
        #define SM2DH_get_send_checksum   AntGM_SM2DH_get_send_checksum
        #define SM2DH_set_checksum        AntGM_SM2DH_set_checksum
        #define SM2Kap_compute_key        AntGM_SM2Kap_compute_key
        #define i2d_sm2_enc               AntGM_i2d_sm2_enc
        #define d2i_sm2_enc               AntGM_d2i_sm2_enc
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    typedef struct AntGM_sm2dh_data_st {
        int           server;
        int           checksum;
        int           r_len;
        int           Rp_len;
        int           Rs_len;
        unsigned char r[64];
        unsigned char Rs[129];
        unsigned char Rp[129];
        unsigned char s_checksum[EVP_MAX_MD_SIZE];
        unsigned char e_checksum[EVP_MAX_MD_SIZE];
        int           peerid_len;
        int           selfid_len;
        unsigned char peer_id[64];
        unsigned char self_id[64];
    } AntGM_SM2DH_DATA;
    /*========================================================================*/
    typedef struct AntGM_sm2enc_st {
        ASN1_INTEGER      *x;
        ASN1_INTEGER      *y;
        ASN1_OCTET_STRING *m;
        ASN1_OCTET_STRING *c;
    } AntGM_SM2ENC;
    /*========================================================================*/
    typedef void *(*AntGM_KDF_f)(const void *in,
                                 size_t      inlen,
                                 void       *out,
                                 size_t     *outlen);
    /*========================================================================*/
    int AntGM_KDF_X9_63(unsigned char       *out,
                        size_t               outlen,
                        const unsigned char *Z,
                        size_t               Zlen,
                        const unsigned char *sinfo,
                        size_t               sinfolen,
                        const EVP_MD        *md);
    /*------------------------------------------------------------------------*/
    int AntGM_ECDSA_sm2_get_Z(const EC_KEY  *ec_key,
                              const EVP_MD  *md,
                              const char    *uid,
                              int            uid_len,
                              unsigned char *z_buf,
                              size_t        *z_len);
    /*------------------------------------------------------------------------*/
    ECDSA_SIG *AntGM_sm2_do_sign(const unsigned char *dgst,
                                 int                  dgst_len,
                                 const BIGNUM        *in_kinv,
                                 const BIGNUM        *in_r,
                                 EC_KEY              *eckey);
    /*------------------------------------------------------------------------*/
    int AntGM_sm2_do_verify(const unsigned char *dgst,
                            int                  dgst_len,
                            const ECDSA_SIG     *sig,
                            EC_KEY              *eckey);
    /*------------------------------------------------------------------------*/
    int AntGM_sm2_encrypt(unsigned char       *out,
                          size_t              *outlen,
                          const unsigned char *in,
                          size_t               inlen,
                          const EVP_MD        *md,
                          EC_KEY              *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_sm2_decrypt(unsigned char       *out,
                          size_t              *outlen,
                          const unsigned char *in,
                          size_t               inlen,
                          const EVP_MD        *md,
                          EC_KEY              *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_old_sm2_encrypt(unsigned char       *out,
                              size_t              *outlen,
                              const unsigned char *in,
                              size_t               inlen,
                              const EVP_MD        *md,
                              EC_KEY              *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_old_sm2_decrypt(unsigned char       *out,
                              size_t              *outlen,
                              const unsigned char *in,
                              size_t               inlen,
                              const EVP_MD        *md,
                              EC_KEY              *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_get_ex_data_index(void);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_set_ex_data(EC_KEY *ec_key, void *datas);
    /*------------------------------------------------------------------------*/
    void *AntGM_SM2DH_get_ex_data(EC_KEY *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_prepare(EC_KEY        *ec_key,
                            int            server,
                            unsigned char *R,
                            size_t        *Rlen);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_compute_key(void           *out,
                                size_t          outlen,
                                const EC_POINT *pub_key,
                                EC_KEY         *ec_key,
                                AntGM_KDF_f     KDF);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_get_ensure_checksum(void *out, EC_KEY *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_get_send_checksum(void *out, EC_KEY *ec_key);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2DH_set_checksum(EC_KEY *eckey, int checksum);
    /*------------------------------------------------------------------------*/
    int AntGM_SM2Kap_compute_key(void         *out,
                                 size_t        outlen,
                                 int           server,
                                 const char   *peer_uid,
                                 int           peer_uid_len,
                                 const char   *self_uid,
                                 int           self_uid_len,
                                 const EC_KEY *peer_ecdhe_key,
                                 const EC_KEY *self_ecdhe_key,
                                 const EC_KEY *peer_pub_key,
                                 const EC_KEY *self_ec_key,
                                 const EVP_MD *md);
    /*------------------------------------------------------------------------*/
    int AntGM_i2d_sm2_enc(const unsigned char *in,
                          size_t               inlen,
                          unsigned char      **out);
    /*------------------------------------------------------------------------*/
    int AntGM_d2i_sm2_enc(const unsigned char *in,
                          size_t               inlen,
                          unsigned char      **out);
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #endif
    /*########################################################################*/
#endif
