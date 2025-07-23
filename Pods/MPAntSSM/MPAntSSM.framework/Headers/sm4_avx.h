#ifndef __SM4_AVX__H
#define __SM4_AVX__H

#include <stdint.h>


#ifdef __cplusplus
extern "C" {
#endif

void sm4_avx_process_4blocks(int enc, const uint32_t *rk, const uint8_t *src,
                             uint8_t *dst);

void sm4_avx2_process_8blocks(int enc, const uint32_t *rk, const uint8_t *in,
                              uint8_t *out);

void sm4_avx512_process_16blocks(int enc, const uint32_t *rk, const uint8_t *src,
                                 uint8_t *dst);

void
mpaas_antssm_sm4_avx_ctr_process(const uint32_t *rk, const uint8_t *iv, const uint8_t *pi,
                    uint8_t *po, uint32_t len);

void sm4_avx_ctr(const uint32_t cnt, const uint32_t *rk, const uint8_t *iv,
                 const uint8_t *src, uint8_t *dst, uint32_t len);

void sm4_avx2_ctr(const uint32_t cnt, const uint32_t *rk, const uint8_t *iv,
                  const uint8_t *src, uint8_t *dst, uint32_t len);

void sm4_avx512_ctr(const uint32_t cnt, const uint32_t *rk, const uint8_t *iv,
                    const uint8_t *src, uint8_t *dst, uint32_t len);

int update_T_avx(uint8_t T[4][16]);
int sm4_avx_xts_4blocks( const uint32_t rk1[32],
                 int mode,
                 uint8_t T[4][16],
                 uint8_t *input,
                 uint8_t *output);

int update_T_avx2(uint8_t T[8][16]);
int sm4_avx2_xts_8blocks(const uint32_t rk1[32],
                         int mode,
                         uint8_t T[8][16],
                         uint8_t *input,
                         uint8_t *output);

int update_T_avx512(uint8_t T[16][16]);
int sm4_avx512_xts_16blocks(const uint32_t rk1[32],
                         int mode,
                         uint8_t T[16][16],
                         uint8_t *input,
                         uint8_t *output);

#ifdef __cplusplus
}
#endif

#endif //__SM4_AVX__H
