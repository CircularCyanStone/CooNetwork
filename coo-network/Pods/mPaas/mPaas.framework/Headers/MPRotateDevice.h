//
//  MPRotateDevice.h
//  mPaas
//
//  Created by yangwei on 2022/9/6.
//  Copyright © 2022 Alibaba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPRotateDevice : NSObject

+ (void)setDeviceOrientationAfterIOS16:(UIInterfaceOrientationMask)interfaceOrientations;

+ (void)setDeviceOrientationAfterIOS16:(UIInterfaceOrientationMask)interfaceOrientations currentViewcontroller:(UIViewController *)vc;

@end

NS_ASSUME_NONNULL_END
