#ifndef ANTSSM_LOG_INTERNAL_H
#define ANTSSM_LOG_INTERNAL_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 日志内部调用接口，仅供日志模块内部调用
 */
int mpaas_antssm_log_digest_internal(const char *format, ...);

int mpaas_antssm_log_debug_internal(const char *format, ...);

int mpaas_antssm_log_info_internal(const char *format, ...);

int mpaas_antssm_log_warn_internal(const char *format, ...);

int mpaas_antssm_log_error_internal(const char *format, ...);

int mpaas_antssm_log_new_traceid(char *traceid, size_t traceid_len);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_LOG_INTERNAL_H */
