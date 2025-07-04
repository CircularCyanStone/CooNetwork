/*
 * Created by jinbei on 2020/3/11.
 */
#ifndef ANTSSM_FORMAT_H
#define ANTSSM_FORMAT_H

#if !defined(ANTSSM_CONFIG_FILE)
#include "config.h"
#else
#include ANTSSM_CONFIG_FILE
#endif

#include "rsa.h"
#include "sm2.h"
#include "pk.h"
#include "antcrypto.h"

int mpaas_antssm_format_rsa_private_key_to_byte(mpaas_antssm_rsa_context_t *ctx,
                                          unsigned char *data,
                                          size_t *data_len);

int mpaas_antssm_format_byte_to_rsa_private_key(mpaas_antssm_rsa_context_t *ctx,
                                          const unsigned char *data,
                                          size_t data_len);

int mpaas_antssm_format_sm2_private_key_to_byte(mpaas_antssm_sm2_context_t *ctx,
                                          unsigned char *data,
                                          size_t *data_len);

int mpaas_antssm_format_byte_to_sm2_private_key(mpaas_antssm_sm2_context_t *ctx,
                                          const unsigned char *data,
                                          size_t data_len);

int mpaas_antssm_format_ecdsa_private_key_to_byte(mpaas_antssm_ecdsa_context_t *ctx,
                                            unsigned char *data,
                                            size_t *data_len);

int mpaas_antssm_format_byte_to_ecdsa_private_key(mpaas_antssm_ecdsa_context_t *ctx,
                                            const unsigned char *data,
                                            size_t data_len);

int mpaas_antssm_format_private_key_to_byte(mpaas_antssm_pk_context_t *pk, int algorithm,
                                      unsigned char *data, size_t *data_len);

int mpaas_antssm_format_byte_to_private_key(mpaas_antssm_pk_context_t *pk, int algorithm,
                                      const unsigned char *data,
                                      size_t data_len);

int mpaas_antssm_format_byte_to_rsa_public_key(mpaas_antssm_rsa_context_t *ctx,
                                         const unsigned char *data,
                                         size_t data_len);

int mpaas_antssm_format_byte_to_sm2_public_key(mpaas_antssm_sm2_context_t *ctx,
                                         const unsigned char *data,
                                         size_t data_len);

int mpaas_antssm_format_byte_to_ecdsa_public_key(mpaas_antssm_ecdsa_context_t *ecdsa,
                                           const unsigned char *data,
                                           size_t data_len);

#endif //ANTSSM_FORMAT_H
