#ifndef ANTSSM_KEY_REP_H
#define ANTSSM_KEY_REP_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stdlib.h>
#include <stdint.h>

#include "platform_specific.h"


// Linux系统文件名最长为128个字符
#define SSM_KEY_REP_FILE_NAME_MAX_LENGTH  (128)
// Linux系统文件路径最大长度为1024个字符
#define SSM_KEY_REP_FILE_PATH_MAX_LENGTH  (1024)
#define SSM_KEY_REP_PATH_MAX_LENGTH  (SSM_KEY_REP_FILE_PATH_MAX_LENGTH - SSM_KEY_REP_FILE_NAME_MAX_LENGTH - 1)
#define SSM_KEY_REP_ATTR_VALUE_MAX_LENGTH  (1024)

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 密钥仓库操作上下文
 */
typedef struct {
    unsigned char rootpath[SSM_KEY_REP_FILE_PATH_MAX_LENGTH];
    size_t rootpath_len;
} mpaas_antssm_key_rep_context_t;

typedef struct {
    uint32_t version;
    uint32_t type;
    uint32_t algorithm;
    uint32_t crypt_mode;
    uint32_t padding_mode;
    uint32_t md_algorithm;
    uint32_t update_iv;
} mpaas_antssm_key_rep_attr_t;


/**
 * @brief 初始化
 * @param ctx
 */
void mpaas_antssm_key_rep_init(mpaas_antssm_key_rep_context_t *ctx);

/**
 * @brief 释放资源
 * @param ctx
 */
void mpaas_antssm_key_rep_free(mpaas_antssm_key_rep_context_t *ctx);

/**
 * @brief 设置参数
 * @param ctx
 * @param dir
 * @param dirlen
 * @return
 */
int mpaas_antssm_key_rep_setup(mpaas_antssm_key_rep_context_t *ctx, const char *dir, size_t dirlen);

/**
 * @brief 存储密钥
 * @param ctx
 * @param filename
 * @param filenamelen
 * @param buf
 * @param buflen
 * @return
 */
int mpaas_antssm_key_rep_store_key(mpaas_antssm_key_rep_context_t *ctx,
                             const unsigned char *filename,
                             size_t filenamelen,
                             unsigned char *buf,
                             size_t buflen);

/**
 * @brief 查询密钥
 * @param ctx
 * @param filename
 * @param filenamelen
 * @param buf
 * @param buflen
 * @return
 */
int mpaas_antssm_key_rep_find_key(mpaas_antssm_key_rep_context_t *ctx,
                            const unsigned char *filename,
                            size_t filenamelen,
                            unsigned char *buf,
                            size_t *buflen);

/**
 * @brief 删除密钥
 * @param ctx
 * @param filename
 * @param filenamelen
 * @return
 */
int mpaas_antssm_key_rep_delete_key(mpaas_antssm_key_rep_context_t *ctx,
                              const unsigned char *filename,
                              size_t filenamelen);

void mpaas_antssm_key_rep_attr_init(mpaas_antssm_key_rep_attr_t *attr);

void mpaas_antssm_key_rep_attr_free(mpaas_antssm_key_rep_attr_t *attr);

int mpaas_antssm_key_rep_attr_store(mpaas_antssm_key_rep_context_t *rep, void *ptr);

int mpaas_antssm_key_rep_attr_load(void *key);

int mpaas_antssm_key_rep_attr_find(mpaas_antssm_key_rep_context_t *rep, mpaas_antssm_key_rep_attr_t *attr, const char *name);

int mpaas_antssm_key_rep_attr_remove(mpaas_antssm_key_rep_context_t *rep, const char *name);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_KEY_REP_H */
