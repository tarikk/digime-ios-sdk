//
//  NSError+Helper.h
//  DigiMe
//
//  Created on 27/05/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DigiMeFramework.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSError (Helper)

- (NSError*)errorForErrorCode:(DigiMeFrameworkErrorCode)errorCode;

@end

NS_ASSUME_NONNULL_END
