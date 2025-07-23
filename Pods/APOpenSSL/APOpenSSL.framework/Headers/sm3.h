#if !defined(AntGM_SM3)
    #define AntGM_SM3
    /*########################################################################*/
    #include <openssl/opensslconf.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if !defined(OPENSSL_NO_SM3)
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #include <stddef.h>
    /*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #define AntGM_SM3_DIGEST_LENGTH 32
    #define AntGM_SM3_LBLOCK        16
    #define AntGM_SM3_CBLOCK        64
    #define AntGM_SM3_LONG          unsigned int
    #define AntGM_SM3_LONG_LOG2     2
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    #if !defined(AntGM_BUILD)
        #define SM3_DIGEST_LENGTH AntGM_SM3_DIGEST_LENGTH
        #define SM3_LBLOCK        AntGM_SM3_LBLOCK
        #define SM3_CBLOCK        AntGM_SM3_CBLOCK
        #define SM3_LONG          AntGM_SM3_LONG
        #define SM3_LONG_LOG2     AntGM_SM3_LONG_LOG2
        #define SM3state_st       AntGM_SM3state_st
        #define SM3_CTX           AntGM_SM3_CTX
        #define SM3_Init          AntGM_SM3_Init
        #define SM3_Update        AntGM_SM3_Update
        #define SM3_Final         AntGM_SM3_Final
        #define SM3               AntGM_SM3_one
        #define SM3_Transform     AntGM_SM3_Transform
    #endif
    /*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
    typedef struct AntGM_SM3state_st {
        AntGM_SM3_LONG digest[8];
        AntGM_SM3_LONG Nl, Nh;
        AntGM_SM3_LONG data[AntGM_SM3_LBLOCK];
        unsigned int   num;
        int            hdev;
    } AntGM_SM3_CTX;
    /*========================================================================*/
    int AntGM_SM3_Init(AntGM_SM3_CTX *c);
    /*------------------------------------------------------------------------*/
    int AntGM_SM3_Update(AntGM_SM3_CTX *c, const void *data, size_t len);
    /*------------------------------------------------------------------------*/
    int AntGM_SM3_Final(unsigned char *md, AntGM_SM3_CTX *c);
    /*------------------------------------------------------------------------*/
    unsigned char *AntGM_SM3_one(const unsigned char *d,
                                 size_t               n,
                                 unsigned char       *md);
    /*------------------------------------------------------------------------*/
    void AntGM_SM3_Transform(AntGM_SM3_CTX *c, const unsigned char *data);
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #endif
    /*########################################################################*/
#endif
