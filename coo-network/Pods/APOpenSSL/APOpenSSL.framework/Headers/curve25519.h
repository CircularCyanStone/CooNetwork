#if !defined(AntGM_CURVE25519)
    #define AntGM_CURVE25519
    /*########################################################################*/
    #include <openssl/e_os2.h>
    #include <stddef.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if !defined(AntGM_BUILD)
        #define ED25519_sign                AntGM_ED25519_sign
        #define ED25519_verify              AntGM_ED25519_verify
        #define ED25519_public_from_private AntGM_ED25519_public_from_private
        #define X25519                      AntGM_X25519
        #define X25519_public_from_private  AntGM_X25519_public_from_private
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    int AntGM_ED25519_sign(uint8_t       *out_sig,
                           const uint8_t *message,
                           size_t         message_len,
                           const uint8_t  public_key[32],
                           const uint8_t  private_key[32]);
    /*------------------------------------------------------------------------*/
    int AntGM_ED25519_verify(const uint8_t *message,
                             size_t         message_len,
                             const uint8_t  signature[64],
                             const uint8_t  public_key[32]);
    /*------------------------------------------------------------------------*/
    void AntGM_ED25519_public_from_private(uint8_t       out_public_key[32],
                                           const uint8_t private_key[32]);
    /*------------------------------------------------------------------------*/
    int AntGM_X25519(uint8_t       out_shared_key[32],
                     const uint8_t private_key[32],
                     const uint8_t peer_public_value[32]);
    /*------------------------------------------------------------------------*/
    void AntGM_X25519_public_from_private(uint8_t       out_public_value[32],
                                          const uint8_t private_key[32]);
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*########################################################################*/
#endif
