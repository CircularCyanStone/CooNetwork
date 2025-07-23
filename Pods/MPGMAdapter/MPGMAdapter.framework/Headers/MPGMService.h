//
//  MPGMService.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/7/10.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPGMDelegate.h"
#import "MPGMInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPGMService : NSObject

+ (instancetype)sharedInstance;

- (instancetype)init NS_UNAVAILABLE;

/// 初始化国密SSL请求服务
+ (void)initService;

/// 设置默认自定义网络请求处理器
/// @param processor 处理器
+ (void)setupDefaultCustomProcessor:(id<MPGMDelegate>)processor;

/// 设置组件的自定义网络请求处理器
/// @param processor 处理器
/// @param component 组件
+ (void)setupCustomProcessor:(id<MPGMDelegate>)processor forComponent:(MPAASGMRequestComponent)component;

/// 获取默认的处理器
- (id<MPGMDelegate>)defaultCustomProcessor;

/// 获取组件的处理器
- (id<MPGMDelegate>)customProcessForComponent:(MPAASGMRequestComponent)component;

@end

NS_ASSUME_NONNULL_END
