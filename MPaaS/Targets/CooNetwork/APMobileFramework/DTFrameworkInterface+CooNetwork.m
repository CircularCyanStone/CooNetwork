//
//  DTFrameworkInterface+CooNetwork.m
//  CooNetwork
//
//  Created by coo on 2025/07/04. All rights reserved.
//

#import "DTFrameworkInterface+CooNetwork.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation DTFrameworkInterface (CooNetwork)

- (BOOL)shouldLogReportActive
{
    return YES;
}

- (NSTimeInterval)logReportActiveMinInterval
{
    return 0;
}

- (BOOL)shouldLogStartupConsumption
{
    return YES;
}

- (BOOL)shouldAutoactivateBandageKit
{
    return YES;
}

- (BOOL)shouldAutoactivateShareKit
{
    return YES;
}

- (DTNavigationBarBackTextStyle)navigationBarBackTextStyle
{
    return DTNavigationBarBackTextStyleAlipay;
}

@end

#pragma clang diagnostic pop

