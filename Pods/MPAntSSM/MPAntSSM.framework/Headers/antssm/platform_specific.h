#ifndef ANTSSM_PLATFORM_SPECIFIC_H
#define ANTSSM_PLATFORM_SPECIFIC_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

/**
 * @brief 平台配置
 */
#define PLATFORM_LINUX 1
#define PLATFORM_ANDROID 4
// 默认Linux平台
#ifndef PLATFORM
#define PLATFORM PLATFORM_LINUX
#endif

#ifndef HUNXIAOCOMMAND
#define HUNXIAOCOMMAND __attribute__((__annotate__(("obfus-level=1"))))
#endif

#define FUNON 1
#define FUNOFF 0

// 是否开启真随机数
#ifndef TRUERANDOM
#define TRUERANDOM FUNOFF
#endif

// 是否开启自测
#ifndef SELFTEST
#define SELFTEST FUNOFF
#endif

// 是否开启完整性检测
#ifndef INTEGRITYTEST
#define INTEGRITYTEST FUNOFF
#endif

// 是否开启ROOT检测
#ifndef ROOTTEST
#define ROOTTEST FUNOFF
#endif

// 是否开启随机数开机自检
#ifndef RANDOMTESTONSTART
#define RANDOMTESTONSTART FUNOFF
#endif

// 是否开启随机数运行时自检
#ifndef RANDOMTESTONRUNNING
#define RANDOMTESTONRUNNING FUNOFF
#endif

// 是否开启设备指纹
#ifndef DEVICEFINGER
#define DEVICEFINGER FUNOFF
#endif

//
#ifndef FULLTIMESRNDIO
#define FULLTIMESRNDIO FUNOFF
#endif

//
#ifndef FULLNAMEWITHOSNAME
#define FULLNAMEWITHOSNAME FUNON
#endif

#if PLATFORM == PLATFORM_LINUX || PLATFORM == PLATFORM_ANDROID
#include <pthread.h>
#define mpaas_antssm_PTHREAD_MUTEX_INITIALIZER PTHREAD_MUTEX_INITIALIZER
#define mpaas_antssm_pthread_t pthread_t
#define mpaas_antssm_pthread_cond_t pthread_cond_t
#define mpaas_antssm_pthread_mutex_t pthread_mutex_t
#define mpaas_antssm_pthread_attr_t pthread_attr_t
#define mpaas_antssm_pthread_condattr_t pthread_condattr_t
#endif


#if PLATFORM == PLATFORM_LINUX || PLATFORM == PLATFORM_ANDROID
#define WHITE_FILE1 "804e88828d522afb26b3dfb6b1de71081b9287c5"
#define WHITE_FILE2 "80789d0a21a0837db1ff139404a95dca2af95971"
#define WHITE_FILE3 "80aef0619e31b172b9926880de61ffe9c8b00294"
#endif

int mpaas_antssm_rbg_random(void *ctx, unsigned char *buffer, size_t buffer_len);

int mpaas_antssm_customrandom(void *state, unsigned char *output, size_t len);

int mpaas_antssm_pthread_create(mpaas_antssm_pthread_t *thread, const mpaas_antssm_pthread_attr_t *attr,
                          void *(*start_routine)(void *), void *arg);

int mpaas_antssm_pthread_detach(mpaas_antssm_pthread_t thread);

int mpaas_antssm_pthread_join(mpaas_antssm_pthread_t thread, void **retval);

void mpaas_antssm_pthread_exit(void *retval);

int mpaas_antssm_pthread_cancel(mpaas_antssm_pthread_t thread);

int mpaas_antssm_pthread_cond_init(mpaas_antssm_pthread_cond_t *cond,
                             const mpaas_antssm_pthread_condattr_t *attr);

int mpaas_antssm_pthread_cond_destroy(mpaas_antssm_pthread_cond_t *cond);

int mpaas_antssm_pthread_cond_timedwait(mpaas_antssm_pthread_cond_t *cond,
                                  mpaas_antssm_pthread_mutex_t *mutex,
                                  const struct timespec *abstime);

int mpaas_antssm_pthread_cond_signal(mpaas_antssm_pthread_cond_t *cond);

int mpaas_antssm_pthread_cond_broadcast(mpaas_antssm_pthread_cond_t *cond);

int mpaas_antssm_pthread_mutex_init(mpaas_antssm_pthread_mutex_t *mutex, void *attr);

int mpaas_antssm_pthread_mutex_destroy(mpaas_antssm_pthread_mutex_t *mutex);

int mpaas_antssm_pthread_mutex_lock(mpaas_antssm_pthread_mutex_t *mutex);

int mpaas_antssm_pthread_mutex_unlock(mpaas_antssm_pthread_mutex_t *mutex);

int mpaas_antssm_getplatformfinger(char finger[32]);

int mpaas_antssm_default_RNG(unsigned char *dest, size_t size);

#ifdef __cplusplus
}
#endif
#endif /* ANTSSM_PLATFORM_SPECIFIC_H */
