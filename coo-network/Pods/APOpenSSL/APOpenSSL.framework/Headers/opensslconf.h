#if !defined(AntGM_OPENSSLCONF)
    #define AntGM_OPENSSLCONF
    /*########################################################################*/
    #include <stdint.h>
    #if defined(__LP64__)
        #include <openssl/opensslconf.64.h>
    #else
        #include <openssl/opensslconf.32.h>
    #endif
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(AntGM_BUILD)
        #ifdef sm2_compute_z_digest
            #undef sm2_compute_z_digest
        #endif
        #ifdef sm2_do_sign
            #undef sm2_do_sign
        #endif
        #ifdef sm2_do_verify
            #undef sm2_do_verify
        #endif
        #ifdef sm2_sign
            #undef sm2_sign
        #endif
        #ifdef sm2_verify
            #undef sm2_verify
        #endif
        #ifdef sm2_ciphertext_size
            #undef sm2_ciphertext_size
        #endif
        #ifdef sm2_plaintext_size
            #undef sm2_plaintext_size
        #endif
        #ifdef sm2_encrypt
            #undef sm2_encrypt
        #endif
        #ifdef sm2_decrypt
            #undef sm2_decrypt
        #endif
        #define sm2_compute_z_digest INTERNAL_sm2_compute_z_digest_INTERNAL
        #define sm2_do_sign          INTERNAL_sm2_do_sign_INTERNAL
        #define sm2_do_verify        INTERNAL_sm2_do_verify_INTERNAL
        #define sm2_sign             INTERNAL_sm2_sign_INTERNAL
        #define sm2_verify           INTERNAL_sm2_verify_INTERNAL
        #define sm2_ciphertext_size  INTERNAL_sm2_ciphertext_size_INTERNAL
        #define sm2_plaintext_size   INTERNAL_sm2_plaintext_size_INTERNAL
        #define sm2_encrypt          INTERNAL_sm2_encrypt_INTERNAL
        #define sm2_decrypt          INTERNAL_sm2_decrypt_INTERNAL
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    #if defined(AntGM_BUILD)
        #ifdef SM3state_st
            #undef SM3state_st
        #endif
        #ifdef SM3_CTX
            #undef SM3_CTX
        #endif
        #ifdef sm3_init
            #undef sm3_init
        #endif
        #ifdef sm3_update
            #undef sm3_update
        #endif
        #ifdef sm3_final
            #undef sm3_final
        #endif
        #ifdef sm3_block_data_order
            #undef sm3_block_data_order
        #endif
        #ifdef sm3_transform
            #undef sm3_transform
        #endif
        #define SM3state_st          INTERNAL_SM3state_st_INTERNAL
        #define SM3_CTX              INTERNAL_SM3_CTX_INTERNAL
        #define sm3_init             INTERNAL_sm3_init_INTERNAL
        #define sm3_update           INTERNAL_sm3_update_INTERNAL
        #define sm3_final            INTERNAL_sm3_final_INTERNAL
        #define sm3_block_data_order INTERNAL_sm3_block_data_order_INTERNAL
        #define sm3_transform        INTERNAL_sm3_transform_INTERNAL
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    #if defined(AntGM_BUILD)
        #ifdef SM4_KEY_st
            #undef SM4_KEY_st
        #endif
        #ifdef SM4_KEY
            #undef SM4_KEY
        #endif
        #ifdef SM4_set_key
            #undef SM4_set_key
        #endif
        #ifdef SM4_encrypt_affine_ni
            #undef SM4_encrypt_affine_ni
        #endif
        #ifdef SM4_encrypt_sboxt_ni
            #undef SM4_encrypt_sboxt_ni
        #endif
        #ifdef SM4_encrypt
            #undef SM4_encrypt
        #endif
        #ifdef SM4_decrypt
            #undef SM4_decrypt
        #endif
        #define SM4_KEY_st            INTERNAL_SM4_KEY_st_INTERNAL
        #define SM4_KEY               INTERNAL_SM4_KEY_INTERNAL
        #define SM4_set_key           INTERNAL_SM4_set_key_INTERNAL
        #define SM4_encrypt_affine_ni INTERNAL_SM4_encrypt_affine_ni_INTERNAL
        #define SM4_encrypt_sboxt_ni  INTERNAL_SM4_encrypt_sboxt_ni_INTERNAL
        #define SM4_encrypt           INTERNAL_SM4_encrypt_INTERNAL
        #define SM4_decrypt           INTERNAL_SM4_decrypt_INTERNAL
    #endif
    /*########################################################################*/
#endif
