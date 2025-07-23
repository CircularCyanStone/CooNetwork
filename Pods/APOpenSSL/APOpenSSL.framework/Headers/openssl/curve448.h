#if !defined(AntGM_CURVE448)
    #define AntGM_CURVE448
    /*########################################################################*/
    #include <openssl/e_os2.h>
    #include <stddef.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if !defined(AntGM_BUILD)
        #define ED448_sign                AntGM_ED448_sign
        #define ED448_verify              AntGM_ED448_verify
        #define ED448ph_sign              AntGM_ED448ph_sign
        #define ED448ph_verify            AntGM_ED448ph_verify
        #define ED448_public_from_private AntGM_ED448_public_from_private
        #define X448                      AntGM_X448
        #define X448_public_from_private  AntGM_X448_public_from_private
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    int AntGM_ED448_sign(uint8_t       *out_sig,
                         const uint8_t *message,
                         size_t         message_len,
                         const uint8_t  public_key[57],
                         const uint8_t  private_key[57],
                         const uint8_t *context,
                         size_t         context_len);
    /*------------------------------------------------------------------------*/
    int AntGM_ED448_verify(const uint8_t *message,
                           size_t         message_len,
                           const uint8_t  signature[114],
                           const uint8_t  public_key[57],
                           const uint8_t *context,
                           size_t         context_len);
    /*------------------------------------------------------------------------*/
    int AntGM_ED448ph_sign(uint8_t       *out_sig,
                           const uint8_t  hash[64],
                           const uint8_t  public_key[57],
                           const uint8_t  private_key[57],
                           const uint8_t *context,
                           size_t         context_len);
    /*------------------------------------------------------------------------*/
    int AntGM_ED448ph_verify(const uint8_t  hash[64],
                             const uint8_t  signature[114],
                             const uint8_t  public_key[57],
                             const uint8_t *context,
                             size_t         context_len);
    /*------------------------------------------------------------------------*/
    int AntGM_ED448_public_from_private(uint8_t       out_public_key[57],
                                        const uint8_t private_key[57]);
    /*------------------------------------------------------------------------*/
    int AntGM_X448(uint8_t       out_shared_key[56],
                   const uint8_t private_key[56],
                   const uint8_t peer_public_value[56]);
    /*------------------------------------------------------------------------*/
    void AntGM_X448_public_from_private(uint8_t       out_public_value[56],
                                        const uint8_t private_key[56]);
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*########################################################################*/
#endif
