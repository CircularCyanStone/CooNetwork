//
//  MPGMInterface.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/7/10.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MPAASGMRequestType) {
    MPAASGMRequestTypeDefault  = 0,    // 默认
    MPAASGMRequestTypeCustom   = 1,    // 自定义
    MPAASGMRequestTypeSec      = 2,    // 信安世纪
    MPAASGMRequestTypeAnt      = 3,    // mPaaS
};

typedef NS_OPTIONS(NSUInteger, MPAASGMRequestComponent) {
    MPAASGMRequestComponentNone      = 0,         // 默认
    MPAASGMRequestComponentRpc       = 1 << 0,    // RPC
    MPAASGMRequestComponentMds       = 1 << 1,    // MDS
    MPAASGMRequestComponentWebview   = 1 << 2,    // H5
    MPAASGMRequestComponentMas       = 1 << 3     // MAS
};

typedef NS_ENUM(NSUInteger, MPAASGMFilterMode) {
    MPAASGMFilterModeDefault     = 0,    // 默认
    MPAASGMFilterModeWhiteList   = 1,    // 白名单模式
    MPAASGMFilterModeBlackList   = 2,    // 黑名单模式
};

@interface MPGMInterface : NSObject

+ (instancetype)sharedInstance;

/// 国密SSL请求方式
- (MPAASGMRequestType)gmRequestType;

/// 需要发起国密SSL请求的组件
- (MPAASGMRequestComponent)gmRequestComponents;

/// 最大请求失败次数
- (NSInteger)maxFailedTimesOfRequest;

// 判断最大请求失败次数时是否只校验域名
- (BOOL)verifyHostOfRequest;

// 过滤器模式
- (MPAASGMFilterMode)gmFilterMode;

// 需要过滤的域名数组
- (NSArray *)gmHostFilterArray;

@end

NS_ASSUME_NONNULL_END
