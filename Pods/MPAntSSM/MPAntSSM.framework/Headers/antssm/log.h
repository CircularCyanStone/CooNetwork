#ifndef ANTSSM_LOG_H
#define ANTSSM_LOG_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stdio.h>
#include <stdarg.h>

#include "log_internal.h"
#include "version.h"

#define ANTSSM_TRACEID_BUFFER_LENGTH (16)
#define ANTSSM_TRACEID_LENGTH       (2 * ANTSSM_TRACEID_BUFFER_LENGTH + 1)

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 注入日志实现
 */
int mpaas_antssm_log_setup(const char *name,
                     void *impl_ctx,
                     int (*mpaas_antssm_log_digest_function)(void *ctx,
                                                       const char *format,
                                                       va_list args),
                     int (*mpaas_antssm_log_debug_function)(void *ctx,
                                                      const char *format,
                                                      va_list args),
                     int (*mpaas_antssm_log_info_function)(void *ctx,
                                                     const char *format,
                                                     va_list args),
                     int (*mpaas_antssm_log_warn_function)(void *ctx,
                                                     const char *format,
                                                     va_list args),
                     int (*mpaas_antssm_log_error_function)(void *ctx,
                                                      const char *format,
                                                      va_list args));

int mpaas_antssm_log_hexify(const unsigned char *ibuf, int ibuflen, char *obuf,
                      int obuflen);

int mpaas_antssm_log_get_rnd_traceid(char *buf, int len);
/**
 * 日志抽象接口，供其他模块调用进行日志记录
 */
/* 获取 【设备序列号】与 【软模块版本】 */
#ifdef ANTSSM_LOG_DIGEST_C
#define mpaas_antssm_tracelog_digest(traceid, status, format, ...)                   \
do {                                                                        \
    char * version = ANTSSM_VERSION_STRING_FULL;                               \
    mpaas_antssm_log_digest_internal("%s,%s,%s,%s,0x%x," format, "digestlog", version,traceid, __func__, status, __VA_ARGS__);   \
} while (0)
#else
#define mpaas_antssm_tracelog_digest(traceid, status, format, ...)
#endif /* ANTSSM_LOG_DIGEST_C */

#ifdef ANTSSM_LOG_DETAIL_C
#define mpaas_antssm_tracelog_debug(traceid, format, ...)                            \
do {                                                                        \
    mpaas_antssm_log_debug_internal("%s,%s,L%d,%s," format, traceid, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_tracelog_info(traceid, format, ...)                             \
do {                                                                        \
    mpaas_antssm_log_info_internal("%s,%s,L%d,%s," format, traceid, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_tracelog_warn(traceid, format, ...)                             \
do {                                                                        \
    mpaas_antssm_log_warn_internal("%s,%s,L%d,%s," format, traceid, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_tracelog_error(traceid, format, ...)                            \
do {                                                                        \
    mpaas_antssm_log_error_internal("%s,%s,L%d,%s," format, traceid, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#ifdef ANTSSM_LOG_ENTER_EXIT
#define mpaas_antssm_tracelog_enter(traceid)                                         \
do {                                                                        \
    mpaas_antssm_tracelog_info(traceid, "%s", "enter");                              \
} while (0)

#define mpaas_antssm_tracelog_exit(traceid, ret)                                     \
do {                                                                        \
    mpaas_antssm_tracelog_info(traceid, "exit[ret=0x%x]", ret);                      \
} while (0)
#else
#define mpaas_antssm_tracelog_enter(traceid)
#define mpaas_antssm_tracelog_exit(traceid, ret)
#endif /* ANTSSM_LOG_ENTER_EXIT */

#define mpaas_antssm_log_debug(format, ...)                                          \
do {                                                                        \
    mpaas_antssm_log_debug_internal("%s,L%d,%s," format, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_log_info(format, ...)                                           \
do {                                                                        \
    mpaas_antssm_log_info_internal("%s,L%d,%s," format, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_log_warn(format, ...)                                           \
do {                                                                        \
    mpaas_antssm_log_warn_internal("%s,L%d,%s," format, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#define mpaas_antssm_log_error(format, ...)                                          \
do {                                                                        \
    mpaas_antssm_log_error_internal("%s,L%d,%s," format, __FILE__, __LINE__, __func__,  __VA_ARGS__); \
} while (0)

#ifdef ANTSSM_LOG_ENTER_EXIT
#define mpaas_antssm_log_enter()                                                     \
do {                                                                        \
    mpaas_antssm_log_info_internal("%s,L%d,%s,%s", __FILE__, __LINE__, __func__,  "enter"); \
} while (0)

#define mpaas_antssm_log_exit(ret)                                                   \
do {                                                                        \
    mpaas_antssm_log_info_internal("%s,L%d,%s,exit[ret=0x%x]", __FILE__, __LINE__, __func__, ret); \
} while (0)
#else
#define mpaas_antssm_log_enter()
#define mpaas_antssm_log_exit(ret)
#endif /* ANTSSM_LOG_ENTER_EXIT */

#else /* ANTSSM_LOG_DETAIL_C */
#define mpaas_antssm_tracelog_debug(traceid, format, ...)
#define mpaas_antssm_tracelog_info(traceid, format, ...)
#define mpaas_antssm_tracelog_warn(traceid, format, ...)
#define mpaas_antssm_tracelog_error(traceid, format, ...)
#define mpaas_antssm_tracelog_enter(traceid)
#define mpaas_antssm_tracelog_exit(traceid, ret)
#define mpaas_antssm_log_debug(format, ...)
#define mpaas_antssm_log_info(format, ...)
#define mpaas_antssm_log_warn(format, ...)
#define mpaas_antssm_log_error(format, ...)
#define mpaas_antssm_log_enter()
#define mpaas_antssm_log_exit(ret)
#endif /* ANTSSM_LOG_DETAIL_C */

#ifdef __cplusplus
}
#endif
#endif /* ANTSSM_LOG_H */
