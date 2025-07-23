//
//  MCCryptoMacro.h
//  MPaaSCryptoIsland
//
//  Created by yanjinquan on 2022/11/10.
//  Copyright © 2022 Alipay. All rights reserved.
//

#ifndef MCCryptoMacro_h
#define MCCryptoMacro_h
/*||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/
typedef enum FI_ct {
    FI_CT_rsa_aes,
    FI_CT_ecc_aes,
    FI_CT_sm2_sm4,
    FI_CT_sm2_ssm,
    FI_CT_sm2_sm4_antssm
} FI_ct_t;
/*========================================================================*/
typedef struct FI_buf {
    unsigned char *content;
    size_t         length;
} FI_buf_t;

#endif /* MCCryptoMacro_h */
