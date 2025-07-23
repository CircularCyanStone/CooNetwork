/**
 * \file gcm.h
 *
 * \brief 这个模块是进行GCM加密的，由论大（李论）开发,主要内容是通过增加GCM工作模式，给SM4加密实现加密的同时验证消息完整性的功能
 *  代码由两部分构成：
 *  第一部分是基于Mbed TLS的GCM模式，由gcm.c构成。适用于全部的有CipherID加密算法。
 *  第二部分是高速SM4-GCM-AVX算法，由汇编文件和gcm_avx.c和ghash_x86-64.s文件构成
 *
 *  This file is part of Antssm
 */

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

//是否开启功能
#if (defined(ANTSSM_GCM) || defined(ANTSSM_GCM_SM4_FAST)) //lunda: 20200811 必须在config.h里面注明，否则会关掉这个功能！！

#include "antssm/cipher.h"
#include <stdint.h>

/////////////////////////////////////////
#define ANTSSM_GCM_ENCRYPT     1
#define ANTSSM_GCM_DECRYPT     0

#define ANTSSM_ERR_GCM_AUTH_FAILED                       -0x0012  /**< 认证额外数据ADD失败 Authenticated decryption failed. */
/* ANTSSM_ERR_GCM_HW_ACCEL_FAILED is deprecated and should not be used. */
#define ANTSSM_ERR_GCM_HW_ACCEL_FAILED                   -0x0013  /**< GCM硬件加速失败 GCM hardware accelerator failed. */
#define ANTSSM_ERR_GCM_BAD_INPUT                         -0x0014  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_1                       -0x0015  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_2                       -0x0016  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_3                       -0x0017  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_4                       -0x0018  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_5                       -0x0019  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_6                       -0x001a  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_7                       -0x001b  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_8                       -0x001c  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_9                       -0x001d  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_10                      -0x001e  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_11                      -0x001f  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_12                      -0x0020  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_13                      -0x0021  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_14                      -0x0022  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_15                      -0x0023  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_16                      -0x0024  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_17                      -0x0025  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_18                      -0x0026  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_19                      -0x0027  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_20                      -0x0028  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_21                      -0x0029  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_22                      -0x002a  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_23                      -0x002b  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_24                      -0x002c  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_25                      -0x002d  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_26                      -0x002e  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_27                      -0x002f  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_28                      -0x0030  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_29                      -0x0031  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_30                      -0x0032  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_40                      -0x0033  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_41                      -0x0034  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_42                      -0x0035  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_43                      -0x0036  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_44                      -0x0037  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_45                      -0x0038  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_46                      -0x0039  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_47                      -0x003a  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_48                      -0x003b  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_49                      -0x003c  /**< 函数输入参数范围不对 Bad input parameters to function. */
#define ANTSSM_ERR_GCM_BAD_INPUT_50                      -0x003d  /**< 函数输入参数范围不对 Bad input parameters to function. */



//////////////////////////////////

#ifndef u128
/*- GCM definitions */ 
typedef struct {
	uint64_t hi, lo;
} u128;
#endif
///////////////////////////////////////

#ifdef __cplusplus
extern "C" {
#endif


# ifndef SM4_KEY_SCHEDULE
# define SM4_KEY_SCHEDULE  32
#endif

#if defined(ANTSSM_GCM)
/**
 * \brief          GCM主体结构-The GCM context structure.
 */
typedef struct mpaas_antssm_gcm_context
{
    //以下为NON-AVX专用
    mpaas_antssm_cipher_context_t cipher_ctx;  /*!< 使用的加密ctx - The cipher context used. */
    uint64_t HL[16];                      /*!< 提前计算好的low哈希表 - Precalculated HTable low. */
    uint64_t HH[16];                      /*!< 提前计算好的high哈希表 - Precalculated HTable high. */
    uint64_t len;                         /*!< 加密的总长度 - The total length of the encrypted data. */
    uint64_t add_len;                     /*!< 额外数据add的长度 - The total length of the additional data. */
    unsigned char base_ectr[16];          /*!< （准备给tag的）第一波加密输出 - The first ECTR for tag. */ //尚不知道ECTR是什么，感觉是密文相关
    unsigned char y[16];                  /*!< 运行中的Y数值 - The Y working value. */
    unsigned char buf[16];                /*!< 运行中的缓存buf - The buf working value. */
    int mode;                             /*!< 使用中的模式，加密或解密- The operation to perform:
                                               #ANTSSM_GCM_ENCRYPT or
                                               #ANTSSM_GCM_DECRYPT. */

}
mpaas_antssm_gcm_context;
#endif //#if defined(ANTSSM_GCM)


#if defined(ANTSSM_GCM_SM4_FAST)
/**
 * \brief  GCM-avx主体结构.
 */
typedef struct mpaas_antssm_sm4_asm_gcm_context
{
    //以下为AVX专用
    u128 Htable_avx[16];
    u128 Htable_4bit[16];
    uint64_t Xi[2];//Xi是用来生成Htable的必要元素。
    //以下为SM4-AVX-GCM专用key
    uint32_t rk[SM4_KEY_SCHEDULE];
    //检测AVX的数目
    int avxbits;

}
mpaas_antssm_sm4_asm_gcm_context;
#endif //#if defined(ANTSSM_GCM_SM4_FAST)

#if defined(ANTSSM_GCM_SM4_FAST)
////////////////////////////以下内容来自于openssl函数，不推荐直接调用，通过下方mpaas_antssm_ghash类的函数调用

void gcm_init_avx(u128 Htable[16], const uint64_t Xi[2]);
// void gcm_gmult_avx(uint64_t Xi[2], const u128 Htable[16]);
void gcm_ghash_avx(uint64_t Xi[2], const u128 Htable[16], const uint8_t *inp,
                   int len);
/////////////////////////以上内容来自于openssl函数汇编代码块//////////////////////////





/**
 * \brief  本函数基于openssl的纯C生成4bit专用的乘法表，它不需要使用任何AVX或者AES相关的x86指令集，因此可以移植到诸如ARM的平台
*/
void gcm_init_4bit(u128 Htable[16], uint64_t H[2]);

/**
 * \brief  本函数基于openssl的纯C的GHash函数，它不需要使用任何AVX或者AES相关的x86指令集，因此可以移植到诸如ARM的平台
 *         此函数不含填充，填充等算法整合到mpaas_antssm_gcm_ghash_fast中
 * \warning 【不要直接调用，全部都放在mpaas_antssm_gcm_ghash_fast中了】
*/
void mpaas_antssm_gcm_ghash_4bit(uint64_t Xi[2], const u128 Htable[16],
                           const uint8_t *inp, size_t len,int verbose);

/**
 * \brief       基于openssl汇编块代码扩展，处理了填充等问题,这个算法主要是实现Ghash，
 *              全部使用AVX的汇编写，内部使用了一些openssl相关的汇编代码。不可调试
 *              ghash的是128bit的整数倍，对于不是整数倍的，后面会用0填充到128bit
 *              会根据ctx->avxbits的数值自动选择是否调用AVX
 * 
 * \warning     【注意】必须先调用SETKEY！才能调用这个函数。
 */
int mpaas_antssm_gcm_ghash_fast(mpaas_antssm_sm4_asm_gcm_context *ctx, const unsigned char *x, const long x_len,
                               uint64_t *Xi);

#endif //#if defined(ANTSSM_GCM_SM4_FAST)


#if defined(ANTSSM_GCM)

//////////////////////////////////////////////下面是GCM大模块相关函数，GCM模块主要的算法都在GCM.c中，它可以兼容于cipher.h中有ID的任意一种加密算法//////////////////////

/**
 * \brief 本函数基于mbedtls相关函数编写，他使用了AESNI指令进行了优化。速度比较慢。如果支持AVX推荐使用mpaas_antssm_gcm_ghash_fast
*/
int mpaas_antssm_gcm_ghash(mpaas_antssm_gcm_context *ctx, unsigned char *x, long x_len,
                      unsigned char *Y_m);


/**
 * \brief           这是GCM初始化，主要是为了保证context初始化并且准备context，以及函数mpaas_antssm_gcm_setkey() or mpaas_antssm_gcm_free()的正常使用
 *                  请注意这个函数不会绑定具体的加密模式也不设置key，如果要处理相关内容，请使用函数mpaas_antssm_gcm_setkey()。
 *                  ===================================
 *                  This function initializes the specified GCM context,
 *                  to make references valid, and prepares the context
 *                  for mpaas_antssm_gcm_setkey() or mpaas_antssm_gcm_free().
 *
 *                  The function does not bind the GCM context to a particular
 *                  cipher, nor set the key. For this purpose, use
 *                  mpaas_antssm_gcm_setkey().
 *
 * \param ctx       初始化context，context必须不能为NULL - The GCM context to initialize. This must not be \c NULL.
 */
void mpaas_antssm_gcm_init( mpaas_antssm_gcm_context *ctx );

/**
 * \brief           主要用于清理GCM的context以及所包含的所有下级context。
 *                  This function clears a GCM context and the underlying
 *                  cipher sub-context.
 *
 * \param ctx       用于清理的ctx，如果是NULL，则直接无效果
 *                  The GCM context to clear. If this is \c NULL, the call has
 *                  no effect. Otherwise, this must be initialized.
 */
void mpaas_antssm_gcm_free( mpaas_antssm_gcm_context *ctx );




/**
 * \brief           这个算法主要是给GCM分配一个密钥，并且确定密码学算法用哪个对称密钥算法
 *                  This function associates a GCM context with a
 *                  cipher algorithm and a key.
 *
 * \param ctx       gcm的context，这个必须先init - The GCM context. This must be initialized.
 * \param cipher    使用128位block的加密算法。可选参照cipher.h - The 128-bit block cipher to use.
 * \param key       使用的加密key，必须是可识别的比特且长达大于等于 \p keybits - The encryption key. This must be a readable buffer of at
 *                  least \p keybits bits.
 * \param keybits   加密的key的比特，可选的为：- The key size in bits. Valid options are:
 *                  <ul><li>128 bits</li>
 *                  <li>192 bits</li>
 *                  <li>256 bits</li></ul>
 *
 * \return          \c 0 表示成功 - on success.
 * \return          如果错误会返回特定的code - 参照 error.h - A cipher-specific error code on failure.
 */
int mpaas_antssm_gcm_setkey( mpaas_antssm_gcm_context *ctx,
                        mpaas_antssm_cipher_id_t cipher,
                        const unsigned char *key,
                        unsigned int keybits
                        );


/**
 * \brief           这个函数主要是从buffer中执行GCM相关的加密解密 - This function performs GCM encryption or decryption of a buffer.
 *
 * \note            对于加密来说，output的输出可以定位在input同一个地址。对于解密来说，output和input不能再同一个buffer中，
 *                  如果buffer复用，请让op在ip至少8个bit后面。
 *                  For encryption, the output buffer can be the same as the
 *                  input buffer. For decryption, the output buffer cannot be
 *                  the same as input buffer. If the buffers overlap, the output
 *                  buffer must trail at least 8 Bytes behind the input buffer.
 *
 * \warning         当这个函数用于解密的时候，output的tag没有起到验证的作用，因此最好不要使用这个函数解密，需要解密，请使用
 *                  函数mpaas_antssm_gcm_auth_decrypt()
 *                  When this function performs a decryption, it outputs the
 *                  authentication tag and does not verify that the data is
 *                  authentic. You should use this function to perform encryption
 *                  only. For decryption, use mpaas_antssm_gcm_auth_decrypt() instead.
 *
 * \param ctx       gcm的context，这个必须先init-
 *                  The GCM context to use for encryption or decryption. This
 *                  must be initialized.
 * \param mode      执行的操作有加密和解密两种。请注意解密ANTSSM_GCM_DECRYPT不推荐使用，因为他不验证tag。请使用mpaas_antssm_gcm_auth_decrypt()
 *                  The operation to perform:
 *                  - #ANTSSM_GCM_ENCRYPT to perform authenticated encryption.
 *                    The ciphertext is written to \p output and the
 *                    authentication tag is written to \p tag.
 *                  - #ANTSSM_GCM_DECRYPT to perform decryption.
 *                    The plaintext is written to \p output and the
 *                    authentication tag is written to \p tag.
 *                    Note that this mode is not recommended, because it does
 *                    not verify the authenticity of the data. For this reason,
 *                    you should use mpaas_antssm_gcm_auth_decrypt() instead of
 *                    calling this function in decryption mode.
 * \param length    input的长度，应该等于output的长度才可以
 *                  The length of the input data, which is equal to the length
 *                  of the output data.
 * \param iv        初始向量，必须是可读的buffer并且最少有IV_LEN的长度才可以
 *                  The initialization vector. This must be a readable buffer of
 *                  at least \p iv_len Bytes.
 * \param iv_len    初始向量的长度 - The length of the IV.
 * \param add       用于验证的额外数据的buffer，长度最少需要是字节级的·
 *                  The buffer holding the additional data. This must be of at
 *                  least that size in Bytes.
 * \param add_len   额外数据的长度 - The length of the additional data.
 * \param input     输入的buffer，必须比0大，并且最小是字节级别的输入。The buffer holding the input data. If \p length is greater
 *                  than zero, this must be a readable buffer of at least that
 *                  size in Bytes.
 * \param output    输出的buffer，必须比0大，并且最小是字节级别的输入。The buffer for holding the output data. If \p length is greater
 *                  than zero, this must be a writable buffer of at least that
 *                  size in Bytes.
 * \param tag_len   tag的长度，注意必须是2-16字节的长度。，否则会报错。The length of the tag to generate.
 * \param tag       tag存储的buffer，这个必须是可读取的并且最少tag_len长度。The buffer for holding the tag. This must be a readable
 *                  buffer of at least \p tag_len Bytes.
 *
 * \return          \c 0 返回值-如果加解密成功，注意#ANTSSM_GCM_DECRYPT模式的话，即使错误的验证也会返回0，因为本函数不验证数据
 *                  if the encryption or decryption was performed
 *                  successfully. Note that in #ANTSSM_GCM_DECRYPT mode,
 *                  this does not indicate that the data is authentic.
 * \return          #ANTSSM_ERR_GCM_BAD_INPUT 如果输入输出的buffer有问题，或者返回具体加解密的错误
 *                  if the lengths or pointers are
 *                  not valid or a cipher-specific error code if the encryption
 *                  or decryption failed.
 */
int mpaas_antssm_gcm_crypt_and_tag( mpaas_antssm_gcm_context *ctx,
                       int mode,
                       int length,
                       const unsigned char *iv,
                       int iv_len,
                       const unsigned char *add,
                       int add_len,
                       const unsigned char *input,
                       unsigned char *output,
                       unsigned char *tag,
                       int tag_len
                       );
                       
int mpaas_antssm_gcm_crypt_and_tag_jce( unsigned char *key,
                       int mode,
                       int length,
                       const unsigned char *iv,
                       int iv_len,
                       const unsigned char *add,
                       int add_len,
                       const unsigned char *input,
                       unsigned char *output,
                       unsigned char *tag,
                       int tag_len
                       );


/**
 * \brief           这个函数主要是执行了GCM的解密
 *                  This function performs a GCM authenticated decryption of a
 *                  buffer.
 *
 * \note            解密的output的buffer不能用input的，如果非要复用。一定要隔开至少8bytes的空间
 *                  For decryption, the output buffer cannot be the same as
 *                  input buffer. If the buffers overlap, the output buffer
 *                  must trail at least 8 Bytes behind the input buffer.
 *
 * \param ctx       gcm的context - The GCM context. This must be initialized.
 * \param length    output的长度，应该等于input的长度才可以
 *                  The length of the ciphertext to decrypt, which is also
 *                  the length of the decrypted plaintext.
 * \param iv        The initialization vector. This must be a readable buffer
 *                  of at least \p iv_len Bytes.
 * \param iv_len    初始向量的长度 - The length of the IV.
 * \param add       用于验证的额外数据的buffer，长度最少需要是字节级的·
 *                  The buffer holding the additional data. This must be of at
 *                  least that size in Bytes.
 * \param add_len   额外数据的长度 - The length of the additional data.
 * \param input     输入的buffer，必须比0大，并且最小是字节级别的输入。The buffer holding the input data. If \p length is greater
 *                  than zero, this must be a readable buffer of at least that
 *                  size in Bytes.
 * \param output    输出的buffer，必须比0大，并且最小是字节级别的输入。The buffer for holding the output data. If \p length is greater
 *                  than zero, this must be a writable buffer of at least that
 *                  size in Bytes.
 * \param tag_len   tag的长度，注意必须是2-16字节的长度。，否则会报错。The length of the tag to generate.
 * \param tag       tag存储的buffer，这个必须是可读取的并且最少tag_len长度。The buffer for holding the tag. This must be a readable
 *                  buffer of at least \p tag_len Bytes.
 * \return          \c 0 返回值，如果认证是成功的 - if successful and authenticated.
 * \return          #ANTSSM_ERR_GCM_AUTH_FAILED 返回值代表验证失败
 * \return          #ANTSSM_ERR_GCM_BAD_INPUT  - 代表如果输入输出的buffer有问题，或者返回具体加解密的错误 
 *                  if the lengths or pointers are
 *                  not valid or a cipher-specific error code if the decryption
 *                  failed.
 */
int mpaas_antssm_gcm_auth_decrypt( mpaas_antssm_gcm_context *ctx,
                      int length,
                      const unsigned char *iv,
                      int iv_len,
                      const unsigned char *add,
                      int add_len,
                      const unsigned char *tag,
                      int tag_len,
                      const unsigned char *input,
                      unsigned char *output );


/**
 * \brief           这个函数主要是进行GCM的加密解密操作的开始,
 *                  请注意,不推荐直接使用,可以考虑使用mpaas_antssm_gcm_crypt_and_tag函数.
 *                  This function starts a GCM encryption or decryption
 *                  operation. 
 *
 * \param ctx       gcm加密context，必须init - The GCM context. This must be initialized.
 * \param mode      加密或解密，参数为ANTSSM_GCM_ENCRYPT / ANTSSM_GCM_DECRYPT：The operation to perform: #ANTSSM_GCM_ENCRYPT or
 *                  #ANTSSM_GCM_DECRYPT.
 * \param iv        初始向量 - The initialization vector. This must be a readable buffer of
 *                  at least \p iv_len Bytes.
 * \param iv_len    初始向量长度 - The length of the IV.
 * \param add       用于验证的additional data长度，如果使用NULL就可以不验证 The buffer holding the additional data, or \c NULL
 *                  if \p add_len is \c 0.
 * \param add_len   额外数据长度，如果前面是NULL这里是 0 The length of the additional data. If \c 0,
 *                  \p add may be \c NULL.
 *
 * \return          \c 0 代表成功 - on success.
 */
int mpaas_antssm_gcm_starts( mpaas_antssm_gcm_context *ctx,
                int mode,
                const unsigned char *iv,
                int iv_len,
                const unsigned char *add,
                int add_len );

/*
 * \brief           这个函数主要是给gcm加密喂送加密流给正在进行中的gcm操作。请注意，这个函数应该要
 *                  输入16字节的整数倍的数据，只有最后一个在调用finish之前的update可以输入少于16字节的数据
 *                  This function feeds an input buffer into an ongoing GCM
 *                  encryption or decryption operation.
 *    `             The function expects input to be a multiple of 16
 *                  Bytes. Only the last call before calling
 *                  mpaas_antssm_gcm_finish() can be less than 16 Bytes.
 *
 * \note            当解密的时候，输出的buffer与input的输入不能一致。如果buffer复用的话，要保证相隔8个字节
 *                  For decryption, the output buffer cannot be the same as
 *                  input buffer. If the buffers overlap, the output buffer
 *                  must trail at least 8 Bytes behind the input buffer.
 *
 * \param ctx       GCM的context， 必须先初始化才可以 - The GCM context. This must be initialized.
 * \param length    input长度，必须是16的倍数，除了最后一个update可以不是16的倍数(因此数据量小于2^36 - 2^5 bytes可以一次性输入).
 *                  The length of the input data. This must be a multiple of
 *                  16 except in the last call before mpaas_antssm_gcm_finish().
 * \param input     输入的buffer - The buffer holding the input data. If \p length is greater
 *                  than zero, this must be a readable buffer of at least that
 *                  size in Bytes.
 * \param output    输出的buffer - The buffer for holding the output data. If \p length is
 *                  greater than zero, this must be a writable buffer of at
 *                  least that size in Bytes.
 *
 * \return         \c 0 代表成功 on success.
 * \return         #ANTSSM_ERR_GCM_BAD_INPUT 代表失败 - on failure.
 */
int mpaas_antssm_gcm_update( mpaas_antssm_gcm_context *ctx,
                int length,
                const unsigned char *input,
                unsigned char *output );

/**
 * \brief           这个函数主要是完成了GCM的操作，并且生成用于验证的tag它包含了gcm所有的流，而且含有tag，请注意tag的最大体积是16字节 
 *                  ====================
 *                  This function finishes the GCM operation and generates
 *                  the authentication tag.
 *                  It wraps up the GCM stream, and generates the
 *                  tag. The tag can have a maximum length of 16 Bytes.
 *
 * \param ctx       gcm的context - The GCM context. This must be initialized.

 * \param tag_len   tag的长度，注意必须是2-16字节的长度。，否则会报错。
 *                  The length of the tag to generate.
 * \param tag       tag存储的buffer，这个必须是可读取的并且最少tag_len长度。The buffer for holding the tag. This must be a readable
 *                  buffer of at least \p tag_len Bytes.
 *
 * \return          \c 0 on success.
 * \return          #ANTSSM_ERR_GCM_BAD_INPUT on failure.
 */
int mpaas_antssm_gcm_finish( mpaas_antssm_gcm_context *ctx,
                unsigned char *tag,
                int tag_len );

#endif //#if defined(ANTSSM_GCM)



#if defined(ANTSSM_GCM_SM4_FAST)
////////////////////以下函数为GCM-AVX小模块专用函数，基于SM4-CTR请确保相关内容开启。这个小模块只支持SM4算法。且最好系统支持AVX（不支持AVX也可以用，就是速度比较慢）/////////////////////////////////////////////////////

/**
 * \brief           这是GCM-AVX初始化，主要是为了保证context初始化并且准备context，以及函数mpaas_antssm_sm4_asm_gcm_setkey() 和mpaas_antssm_gcm_free()的正常使用
 *                  请注意这个函数不会绑定具体的加密模式也不设置key，如果要处理相关内容，请使用函数mpaas_antssm_sm4_asm_gcm_setkey()。

 */
void mpaas_antssm_sm4_asm_gcm_init(mpaas_antssm_sm4_asm_gcm_context *ctx);

/**
 * \brief           主要用于清理GCM-avx的context
 *
 * \param ctx       用于清理的ctx，如果是NULL，则直接无效果
 *                  
 */
void mpaas_antssm_sm4_asm_gcm_free(mpaas_antssm_sm4_asm_gcm_context *ctx);

/**
 * \brief           这个函数是给结构体mpaas_antssm_sm4_asm_gcm_context初始化的。
 * \return          \c 0 表示成功 - on success.
 * \return          如果错误会返回特定的code - 参照 error.h - A cipher-specific error code on failure.
 */
int mpaas_antssm_sm4_asm_gcm_setkey( 
                            mpaas_antssm_sm4_asm_gcm_context *ctx,
                            const unsigned char *key,
                            unsigned int keybits
                            );



/**
 * \brief 如无必要，不要直接调用此函数，这个函数是来自于sm4_asm的函数改造。因为需要传入input_cnt，原函数 mpaas_antssm_sm4_avx_ctr_process只能默认设为0.
 * 
*/
void
sm4_avx_gcm_process(const uint32_t *rk, const uint8_t *iv, const uint8_t *pi,
                    uint8_t *po, uint32_t len, uint32_t input_cnt);



/**
 * \brief           gcm-avx第一层函数,sm4_avx_gcm的外部入口，加密并生成用于验证的tag，
 *                  注意！使用之前务必调用set_key，并且在set的同时在config.h中enable gcm模式
 *                  函数体在gcm_avx.c中
 * \param ctx       gcm-avx的context，这个必须先init
 * 
 * \param iv        初始向量，必须是可读的buffer并且最少有IV_LEN的长度才可以
 *                  
 * \param iv_len    初始向量的长度,注意初始向量
 * 
 * \param plain     用于加密的明文，要求输入缓存长度最少是plainLen，且输入是字节级的。如果没有明文数据，应该置为NULL。
 * 
 * \param plainLen  密文长度，如果没有密文，那么应该置为0
 * 
 * \param cipherbuf 用于存放密文的Buffer，要求输入缓存长度最少是plainLen，即和密文相等。且输入是字节级的。
 *  *
 * \param add       用于加密的明文Buffer，要求输入缓存长度是add_len，且输入是字节级的。如果没有额外的验证数据，应该置为NULL。
 *                  
 * \param add_len   额外数据的长度，如果没有额外数据，应该置为0.
 *
 * \param tag_len   tag的长度，注意必须是4-16字节的长度，否则会报错。推荐的长度是最长的16字节。
 * 
 * \param tag       tag存储的buffer，这个必须是可读取的并且最少tag_len长度。
 *
 * \return          \c 0 返回值-如果加解密成功，ANTSSM_ERR_GCM_BAD_INPUT（-14）表示参数范围有错。
 * 
 */
int mpaas_antssm_sm4_asm_encrypt_gcm(mpaas_antssm_sm4_asm_gcm_context *ctx,
                               const unsigned char *iv, const int iv_len,
                               const unsigned char *plain, const int plainLen, unsigned char *cipherbuf,
                               const unsigned char *add, const int add_len,
                               unsigned char *tag, const int tag_len
                               );

/**
 * \brief           sm4_avx_gcm的外部入口，解密对比验证tag.
 * 
 * \warning         注意！使用之前务必调用set_key，并且在set的同时在config.h中enable gcm-avx模式.
 *                          
 * \param ctx       gcm-avx的context，这个必须先init
 * 
 * \param iv        初始向量，必须是可读的buffer并且最少有IV_LEN的长度才可以
 *                  
 * \param iv_len    初始向量的长度,注意初始向量
 * 
 * \param plainbuf  用于存放明文的缓存，要求输入缓存长度最少是real_plainLen，且输入是字节级的。如果没有明文数据，应该置为NULL。
 * 
 * \param real_plainlen  明文的长度，不含任何填充位的原始长度。
 * 
 * \param cipher    存放输入密文，要求输入缓存长度最少是real_plainLen，即和明文相等。且输入是字节级的。
 *  *
 * \param add       用于加密的明文Buffer，要求输入缓存长度是add_len，且输入是字节级的。如果没有额外的验证数据，应该置为NULL。
 *                  
 * \param add_len   额外数据的长度，如果没有额外数据，应该置为0.
 *
 * \param tag_len   tag的长度，注意必须是4-16字节的长度，否则会报错。推荐的长度是最长的16字节。
 * 
 * \param tag       tag存储的buffer，这个必须是可读取的并且最少tag_len长度。
 *
 * \return          \c 0 返回值-如果加解密成功，\c -14 ANTSSM_ERR_GCM_BAD_INPUT 如果参数范围有错。
 * 
 */
int mpaas_antssm_sm4_asm_decrypt_gcm(mpaas_antssm_sm4_asm_gcm_context *ctx,
                                unsigned char *iv, int iv_len,
                                unsigned char *cipher,
                                unsigned char *plainbuf, int real_plainlen,
                                unsigned char *add, int add_len,
                                unsigned char *tag, int tag_len);

#endif // #if defined(ANTSSM_GCM_SM4_FAST)
/////////////////////////////////////////////

#ifdef __cplusplus
}
#endif


#endif //defined(ANTSSM_GCM) || defined(ANTSSM_GCM_SM4_FAST)