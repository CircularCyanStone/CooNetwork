//
//  antcrypto_mpaas.h
//  MPAntSSM
//
//  Created by JiaJun on 2023/3/13.
//  Copyright © 2023 Alipay. All rights reserved.
//

#ifndef antcrypto_mpaas_h
#define antcrypto_mpaas_h

#ifdef __cplusplus
extern "C" {
#endif

#include "antcrypto.h"

#define AK_Login_with_whitebox                  mpaas_AK_Login_with_whitebox
#define AK_Logout                               mpaas_AK_Logout
#define AK_GetRandom                            mpaas_AK_GetRandom
#define AK_ImportObject                         mpaas_AK_ImportObject
#define AK_DeleteObject                         mpaas_AK_DeleteObject
#define AK_Encrypt                              mpaas_AK_Encrypt
#define AK_Encrypt_exIV                         mpaas_AK_Encrypt_exIV
#define AK_Decrypt                              mpaas_AK_Decrypt

#define AK_DIRECTORY                            mpaas_AK_DIRECTORY
#define AK_TEMP_PUBLIC_KEY                      mpaas_AK_TEMP_PUBLIC_KEY
#define AK_TEMP_SYMMETRIC_KEY                   mpaas_AK_TEMP_SYMMETRIC_KEY
#define AK_SM2                                  mpaas_AK_SM2
#define AK_SM4                                  mpaas_AK_SM4
#define AK_PUBLIC_X509_PEM                      mpaas_AK_PUBLIC_X509_PEM
#define AK_KEY_FORMAT_RAW                       mpaas_AK_KEY_FORMAT_RAW

#define antssm_ecp_keypair_t                    mpaas_antssm_ecp_keypair_t
#define antssm_ecp_keypair_free                 mpaas_antssm_ecp_keypair_free
#define antssm_ecp_cal_key_with_public_key      mpaas_antssm_ecp_cal_key_with_public_key
#define antssm_ecp_cal_key_with_private_key     mpaas_antssm_ecp_cal_key_with_private_key
#define antssm_sm2_kap_compute_key              mpaas_antssm_sm2_kap_compute_key
#define antssm_mpi_write_binary                 mpaas_antssm_mpi_write_binary
#define antssm_md_info_from_type                mpaas_antssm_md_info_from_type
#define random_default                          mpaas_antssm_random_default

#ifdef __cplusplus
}
#endif

#endif /* antcrypto_mpaas_h */
