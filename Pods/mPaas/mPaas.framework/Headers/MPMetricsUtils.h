//
//  DTMetricsUtils.h
//  APMobileNetwork
//
//  Created by JiaJun on 2021/11/21.
//  Copyright © 2021 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPaaS+ImportAPRemoteLogging.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPMetricsUtils : NSObject

+ (void)handleWithSessionMetrics:(NSURLSessionTaskMetrics *)metrics bizType:(mPaaSBizType)bizType identifier:(NSString *)identifier ext:(NSDictionary *)ext;

+ (void)handleWithMetrics:(NSDictionary *)dict bizType:(mPaaSBizType)bizType identifier:(NSString *)identifier ext:(NSDictionary *)ext;

@end

NS_ASSUME_NONNULL_END
