//
//  MPGMProtocol.h
//  MPGMAdapter
//
//  Created by JiaJun on 2022/7/10.
//  Copyright © 2022 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPGMInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface MPGMProtocol : NSURLProtocol

@property (nonatomic, assign) MPAASGMRequestComponent component;

@property (nonatomic, strong) NSMutableDictionary *userInfo;

- (BOOL)canLoading;

- (void)startLoadingWithCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

- (void)startRequestWithCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
