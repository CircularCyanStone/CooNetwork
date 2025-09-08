//
//  MPSignatureService.h
//  MPSignatureAdapter
//
//  Created by JiaJun on 2023/3/24.
//  Copyright © 2023 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPSignatureInterface.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const MP_TRUSTED_SIGN_RET_KEY_DJY_CA;
extern NSString* const MP_TRUSTED_SIGN_RET_KEY_DJY_SIGN;
extern NSString* const MP_TRUSTED_SIGN_RET_KEY_DJY_COLOR;
extern NSString* const MP_TRUSTED_SIGN_RET_KEY_DJY_ERROR;
extern NSString* const MP_TRUSTED_SIGN_RET_KEY_SG_SWITCH;

@interface MPSignatureService : NSObject

/**
 *  获取单例
 */
+ (instancetype)sharedInstance;

/// 签名
/// - Parameters:
///   - signKey: signKey
///   - authCode: authCode
///   - content: 待签名内容
- (NSString *)signBySignKey:(NSString *)signKey autoCode:(NSString *)authCode content:(NSString *)content;

/// 签名
/// - Parameters:
///   - signAlgorithmType: 签名算法
///   - signKey: signKey
///   - authCode: authCode
///   - content: 待签名内容
- (NSString *)signByAlgorithmType:(MPSignAlgorithmType)signAlgorithmType signKey:(NSString *)signKey autoCode:(NSString *)authCode content:(NSString *)content;

/// 可信签名
/// - Parameters:
///   - signKey: signKey
///   - signApi: signApi
///   - content: 待签名内容
- (NSDictionary *)trustedSignBySignKey:(NSString *)signKey signApi:(NSString *)signApi content:(NSString *)content;

/// 静态解密
/// - Parameters:
///   - data: 待解密内容
///   - key: key
- (NSData *)staticDecryptData:(NSData *)data key:(NSString *)key;

/// 动态加密
/// - Parameters:
///   - data: 待加密内容
- (NSData *)dynamicEncryptByteArray:(NSData *)data;


/// 动态解密
/// - Parameter data: 待解密内容
- (NSData *)dynamicDecryptByteArray:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
