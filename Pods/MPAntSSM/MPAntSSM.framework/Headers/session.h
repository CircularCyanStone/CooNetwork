#ifndef ANTSSM_SESSION_H
#define ANTSSM_SESSION_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "hashmap.h"
#include "key_rep.h"
#include "white_box.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int init_flag;                          /*!< 上下文初始化标志 */
    int login_flag;                         /*!< 登陆状态 */
    int status;                             /*!< 自检状态 */
    mpaas_antssm_white_box_context_t white_box;   /*!< 白盒 */
    mpaas_antssm_white_box_context_t white_box_internal[4]; /*!< 内部白盒，0：internal encrypt symmetric key 1-3:white box  */
    mpaas_antssm_hashmap_t hashmap;               /*!< map */
    unsigned char session_key_share[32];    /*!< 会话密钥分量  */
    char sessionid[64];                     /*!< 会话标识 */
#ifdef ANTSSM_HASHMAP_SECRET_AUTO_DESTROY
    mpaas_antssm_hashmap_secret_context hashmap_secret;
#endif
} mpaas_antssm_session_t;

int mpaas_antssm_session_init(mpaas_antssm_session_t *ctx);

int mpaas_antssm_session_init_with_whitebox(mpaas_antssm_session_t *session, unsigned char *white_box );

int mpaas_antssm_session_setup(mpaas_antssm_session_t *ctx, const char *dir);

int mpaas_antssm_session_free(mpaas_antssm_session_t *ctx);

mpaas_antssm_session_t *mpaas_antssm_session_get();

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_SESSION_H */
