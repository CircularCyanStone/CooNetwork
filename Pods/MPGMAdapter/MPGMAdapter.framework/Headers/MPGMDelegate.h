//
//  MPGMDelegate.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/7/9.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPGMProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MPGMDelegate <NSObject>

- (BOOL)GMProtocol:(MPGMProtocol *)protocol shouldBeginGMSSLRequest:(NSURLRequest *)request;

- (void)GMProtocol:(MPGMProtocol *)protocol willBeginGMSSLRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
