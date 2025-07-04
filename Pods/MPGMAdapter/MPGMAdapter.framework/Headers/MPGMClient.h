//
//  MPGMClient.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/8/3.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPGMClient : NSObject

/**
 * 发送请求
 */
+ (NSString *)sendTaskWithRequest:(NSURLRequest *)request
                completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end

NS_ASSUME_NONNULL_END
