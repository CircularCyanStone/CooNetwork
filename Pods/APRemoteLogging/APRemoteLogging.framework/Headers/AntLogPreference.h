//
//  AntLogPreference.h
//  APRemoteLogging
//
//  Created by 卡迩 on 2018/4/8.
//  Copyright © 2018年 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Preference类. 默认实现为使用NSUserDefault. 
 */
@interface AntLogPreference : NSObject

/**
 * 获取一个业务下的一个key对应的value
 * @param key key值
 * @param business 业务标识
 * @return 业务下的一个key对应的value
 */
+ (id)objectForKey:(NSString *)key business:(NSString *)business;

/**
 * 设置一个业务下的一个key对应的value
 * @param obj value对象
 * @param key key值
 * @param business 业务标识
 */
+ (void)setObject:(id)obj forKey:(NSString *)key business:(NSString *)business;

@end
