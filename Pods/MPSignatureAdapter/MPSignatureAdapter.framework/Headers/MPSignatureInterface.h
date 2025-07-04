//
//  MPSignatureInterface.h
//  MPSignatureAdapter
//
//  Created by JiaJun on 2023/3/24.
//  Copyright © 2023 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum {
    MPSecurityComponentTypeSG = 0,
    MPSecurityComponentTypeBS
} MPSecurityComponentType;

typedef enum {
    MPSignAlgorithmTypeNone = -1,
    MPSignAlgorithmTypeMD5 = 0,
    MPSignAlgorithmTypeSHA256 = 1,
    MPSignAlgorithmTypeHMACSHA256 = 2,
    MPSignAlgorithmTypeSM3 = 3,
    MPSignAlgorithmTypeHMACSHA1 = 4
} MPSignAlgorithmType;

typedef enum {
    MPCryptoAlgorithmTypeNone = -1,
    MPCryptoAlgorithmTypeAES128 = 0
} MPCryptoAlgorithmType;

@interface MPSignatureInterface : NSObject

/**
 *  获取单例
 */
+ (instancetype)sharedInstance;

/**
 * 安全组件类型
 */
- (MPSecurityComponentType)securityComponentType;

/**
 * 签名算法类型
 */
- (MPSignAlgorithmType)signAlgorithmType;

/**
 * 加密算法类型
 */
- (MPCryptoAlgorithmType)cryptoAlgorithmType;

/**
 * authCode
 */
- (NSString *)authCode;

@end

NS_ASSUME_NONNULL_END
