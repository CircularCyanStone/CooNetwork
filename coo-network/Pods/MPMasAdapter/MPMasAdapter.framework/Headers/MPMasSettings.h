//
//  MPMasSettings.h
//  MPMasAdapter
//
//  Created by kuoxuan on 2023/3/21.
//  Copyright © 2023 mPaaS. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPMasSettings : NSObject

+ (instancetype)sharedInstance;

/**
 自定义设置 clientID，需自定义时在Category中重写
 */
- (NSString *)clientId;

/**
 自定义设置行为日志的扩展字段（44字段)的内容，请传入字典参数，最终在埋点中转换为key^value形式
 需自定义时在Category中重写
 */
- (NSDictionary *)foundationExtended;

/**
 获取卡死时长阈值，需自定义时在Category中重写，建议 anrTimeThreshold / anrCheckInterval 等于整数
 */
- (NSUInteger)anrTimeThreshold;

/**
 获取卡死检测间隔时长，需自定义时在Category中重写，建议 anrTimeThreshold / anrCheckInterval 等于整数
 */
- (NSTimeInterval)anrCheckInterval;

/**
 获取启动卡死时间阈值，需自定义时在Category中重写
 */
- (NSUInteger)startupAnrTimeThreshold;

/**
 是否开启自动化点击埋点，默认开启，需自定义时在Category中重写
 */
+ (BOOL)enableAutoClick;

@end

NS_ASSUME_NONNULL_END
