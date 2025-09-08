//
//  APDAOHistoryManager.h
//  MPDataCenter
//
//  Created by shenmo on 24/05/2017.
//  Copyright © 2017 Alipay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APDAOResult.h"

@protocol APDAOHistoryManager <NSObject>

- (APDAOResult*)addEvent:(NSString*)event;

@end

extern NSString* const APDAOHistoryConfigXMLContent;
extern NSString* const APDAOHistoryConfigTableName;
