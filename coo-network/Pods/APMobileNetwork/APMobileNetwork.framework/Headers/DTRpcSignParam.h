//
//  DTRpcSignMethod.h
//  APMobileNetwork
//
//  Created by yizhangbiao on 2022/2/18.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#define RPC_WALLET_MAX_SIGN_TYPE 1024
typedef enum DTRpcSignType
{
    kDTRpcSignTypeDefault = 0,
    kDTRpcSignType1 = 1, //SIGN_TYPE_MD5
    kDTRpcSignType2 = 2, //SIGN_TYPE_ATLAS
    kDTRpcSignType3 = 3, //SIGN_TYPE_HMAC_SHA1
    kDTRpcSignTeeSDK = 4, //蚂蚁自研
    kDTRpcSignTypeEnd = 1024,
} DTRpcSignType;

typedef enum DTRpcSignStatus
{
    kDTRpcSignDefault = 0,
    kDTRpcSignSucc = 1,
    kDTRpcSignUnkonw = 2,
    kDTRpcSignComponentInitError = 3, //签名组件初始化失败
    kDTRpcSignTypeError       = 4, //签名Version错误，超出阈值
}DTRpcSignStatus;

@interface DTRpcSignParam : NSObject

@property(nonatomic, assign) DTRpcSignType signType;

@property(nonatomic, strong) NSString * signBody;

@property(nonatomic, strong) NSString * signKey;

@property(nonatomic, strong) NSString * operationType;

@property(nonatomic, assign) BOOL isUseTeeSDK;

@property(nonatomic, assign) BOOL isTeeSDKDegrade;

+(BOOL)checkSignVersion:(DTRpcSignType)signType;

+(BOOL)checkSignVersionInWallet:(DTRpcSignType)signType;
@end

@interface DTRpcSignResult : NSObject

@property(nonatomic, assign) DTRpcSignStatus signStatus;

@property(nonatomic, strong) NSString * signString;

@property(nonatomic, strong) NSString * signErrorMsg;

@property(nonatomic, strong) NSString * miniwua;

@property(nonatomic, strong) NSString * teeLib;

@end
