#ifndef ANTSSM_GM_TEST_H
#define ANTSSM_GM_TEST_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 自测
 * @return
 */
int mpaas_antssm_gm_test_selftest(void);

/**
 * @brief 随机数测试
 * @return
 */
int mpaas_antssm_gm_test_rngtest(void);

/**
 * @brief 运行时随机数测试
 * @param rnddata
 * @param len
 * @return
 */
int mpaas_antssm_gm_test_rngtestrunning(unsigned char *rngdata, int rngdata_len);

/**
 * @brief root检测
 * @return
 */
int mpaas_antssm_gm_test_root_check(void);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_GM_TEST_H */
