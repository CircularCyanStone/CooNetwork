/*
 * encoding: utf-8
 * author: 072224 胡军伟（苍茫）
 * content: iOS平台接口定义
 * history: 2017-10-02 初次完成
 */
#if !defined(FI_ios)
    #define FI_ios
    /*########################################################################*/
    #include <stdint.h>
    #include <stdbool.h>
    #include <stddef.h>
    #include "MCCryptoMacro.h"
    /*========================================================================*/
    #if defined(__cplusplus)
    extern "C" {
    #endif
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    //若成功，则返回一个handle；否则返回0。
    uintptr_t FI_create();
    /*------------------------------------------------------------------------*/
    void FI_destroy(uintptr_t handle);
    /*------------------------------------------------------------------------*/
    //返回是否成功。若失败，可调用FI_error获取信息。
    bool FI_init(uintptr_t   handle,
                 const char *pem_rsa,
                 const char *pem_ecc,
                 const char *pem_sm2,
                 const char *iv,
                 ::size_t   len_iv);
    /*------------------------------------------------------------------------*/
    //入参bin_key和len_key表示的是原始密钥。
    //入参bin_data和len_data表示的是明文。
    //出参key是调用FI_decode函数要传入的密钥。
    //出参data是要发送给服务端的密文。
    //出参ext是要发送给服务端的用于计算密钥的附加信息。
    //返回是否成功。若失败，可调用FI_error获取信息。
    //key、data、ext用完后记得手动调free函数释放其content成员指向的内存。
    bool FI_encode(uintptr_t            handle,
                   const unsigned char *bin_key,
                   size_t               len_key,
                   const unsigned char *bin_data,
                   size_t               len_data,
                   FI_ct_t              ct,
                   FI_buf_t            *key,
                   FI_buf_t            *data,
                   FI_buf_t            *ext);
    /*------------------------------------------------------------------------*/
    //入参bin_key和len_key表示的是FI_encode函数返回的密钥，不是原始的。
    //入参bin_data和len_data表示的是密文。
    //出参data是明文。
    //返回是否成功。若失败，可调用FI_error获取信息。
    //data用完后记得手动调free函数释放其content成员指向的内存。
    bool FI_decode(uintptr_t            handle,
                   const unsigned char *bin_key,
                   size_t               len_key,
                   const unsigned char *bin_data,
                   size_t               len_data,
                   FI_ct_t              ct,
                   FI_buf_t            *data);
    /*------------------------------------------------------------------------*/
    const char *FI_error(uintptr_t handle);
    
    //入参bin_key和len_key表示的是原始密钥。
    //入参bin_data和len_data表示的是明文。
    //出参data是要发送给服务端的密文。
    //返回是否成功。若失败，可调用FI_error获取信息。
    //data用完后记得手动调free函数释放其content成员指向的内存。
    bool FI_encryptSm4(uintptr_t            handle,
                       const unsigned char *bin_key,
                       size_t               len_key,
                       const unsigned char *bin_data,
                       size_t               len_data,
                       FI_buf_t            *data);
    
    //入参bin_key和len_key表示的是FI_encode函数返回的密钥，不是原始的。
    //入参bin_data和len_data表示的是密文。
    //出参data是明文。
    //返回是否成功。若失败，可调用FI_error获取信息。
    //data用完后记得手动调free函数释放其content成员指向的内存。
    bool FI_decryptSm4(uintptr_t            handle,
                       const unsigned char *bin_key,
                       size_t               len_key,
                       const unsigned char *bin_data,
                       size_t               len_data,
                       FI_buf_t            *data);
    
    /*::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::*/
    #if defined(__cplusplus)
    }
    #endif
    /*########################################################################*/
#endif
