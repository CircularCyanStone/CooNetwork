#ifndef ANTSSM_SESSION_KEY_H
#define ANTSSM_SESSION_KEY_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "stdlib.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief  根据登陆口令生成登陆token
 *
 * \param  password  [IN]  登陆口令
 * \param  password_len  [IN]  登陆口令长度
 * \param  token  [OUT]  token
 * \param  token_len  [IN/OUT]  IN: token缓冲区长度
 *                              OUT: token长度
 *
 * \return  状态码[0:成功; 其他:错误码]
 */
int mpaas_antssm_session_gen_token(const unsigned char *password, size_t password_len,
                             unsigned char *token, size_t *token_len);

/**
 * \brief  登陆软件密码模块
 *
 * \param  token  [IN]  登陆凭证
 * \param  token_len  [IN]  登陆凭证长度
 *
 * \return  状态码[0:正常; 其他:错误码]
 */
int mpaas_antssm_session_login(const unsigned char *token, size_t token_len);

/**
 * \brief  登出软件密码模块
 *
 * \return  返回码[0:正常;其他:错误]
 */
int mpaas_antssm_session_logout();

/**
 * \brief  修改软件密码模块登陆口令
 *
 * \param  old_password  原登陆口令
 * \param  new_password  新登陆口令
 *
 * \return  状态码[0:正常; 其他:错误码]
 */
int mpaas_antssm_session_modify_password(const unsigned char *old_password,
                                   size_t old_password_len,
                                   const unsigned char *new_password,
                                   size_t new_password_len);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_SESSION_KEY_H */
