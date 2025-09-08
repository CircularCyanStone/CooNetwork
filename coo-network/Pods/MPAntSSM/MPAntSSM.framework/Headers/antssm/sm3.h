#ifndef ANTSSM_SM3_H
#define ANTSSM_SM3_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include <stddef.h>
#include <stdint.h>

#include "log.h"

#if !defined(ANTSSM_SM3_ALT)
#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          SM3 context structure
 */
typedef struct {
    uint32_t state[8];
    uint32_t Nl, Nh;
    unsigned char buffer[64];
    unsigned int num;
    int processnum;
    char traceid[ANTSSM_TRACEID_LENGTH];
} mpaas_antssm_sm3_context_t;

/**
 * \brief          Initialize SM3 context
 *
 * \param ctx      SM3 context to be initialized
 */
void mpaas_antssm_sm3_init(mpaas_antssm_sm3_context_t *ctx);

/**
 * \brief          Clear SM3 context
 *
 * \param ctx      SM3 context to be cleared
 */
void mpaas_antssm_sm3_free(mpaas_antssm_sm3_context_t *ctx);

/**
 * \brief          Clone (the state of) an SM3 context
 *
 * \param dst      The destination context
 * \param src      The context to be cloned
 */
void mpaas_antssm_sm3_clone(mpaas_antssm_sm3_context_t *dst,
                      const mpaas_antssm_sm3_context_t *src);

/**
 * \brief          SM3 context setup
 *
 * \param ctx      context to be initialized
 */
void mpaas_antssm_sm3_starts(mpaas_antssm_sm3_context_t *ctx);

/**
 * \brief          SM3 process buffer
 *
 * \param ctx      SM3 context
 * \param input    buffer holding the  data
 * \param ilen     length of the input data
 */
void mpaas_antssm_sm3_update(mpaas_antssm_sm3_context_t *ctx, const unsigned char *data,
                       size_t len);

/**
 * \brief          SM3 final digest
 *
 * \param ctx      SM3 context
 * \param output   SM3 checksum result
 */
void mpaas_antssm_sm3_finish(mpaas_antssm_sm3_context_t *ctx, unsigned char output[32]);

/* Internal use */
void mpaas_antssm_sm3_process(mpaas_antssm_sm3_context_t *ctx, const unsigned char in[64]);

#ifdef __cplusplus
}
#endif

#else  /* ANTSSM_SM3_ALT */
#include "sm3_alt.h"
#endif /* ANTSSM_SM3_ALT */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * \brief          Output = SM3( input buffer )
 *
 * \param input    buffer holding the  data
 * \param ilen     length of the input data
 * \param output   SM3 checksum result
 */
void mpaas_antssm_sm3(const unsigned char *input, size_t ilen, unsigned char output[32]);

/**
 * \brief          Checkup routine
 *
 * \return         0 if successful, or 1 if the test failed
 */
int mpaas_antssm_sm3_self_test(int verbose);

#ifdef __cplusplus
}
#endif

#endif /* ANTSSM_SM3_H */
