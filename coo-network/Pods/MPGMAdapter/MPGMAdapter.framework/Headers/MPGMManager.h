//
//  MPGMManager.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/7/16.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPGMInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPGMManager : NSObject

+ (instancetype)sharedInstance;

/// 校验License
/// @param gmRequestType 国密请求类型
- (BOOL)verifyGMLicense:(MPAASGMRequestType)gmRequestType;

/// 更新失败记录
/// @param url URL
/// @param error 错误
- (NSNumber *)updateFailedTimesOfRequest:(NSURLRequest *)request error:(NSError *)error;

/// 判断请求是否超出最大失败次数
/// @param request 请求
- (BOOL)exceedMaxFailedTimesOfRequest:(NSURLRequest *)request;

/// 获取枚举Key
/// @param requestType 国密请求类型
- (NSString *)keyFromComponent:(MPAASGMRequestType)requestType;

@end

NS_ASSUME_NONNULL_END
