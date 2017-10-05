//
//  DMEUtilities.h
//  DigiMeFramework
//
//  Created on 27/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DMEUtilities : NSObject

+ (UIViewController *)topmostViewController;
+ (UIColor*) SSWarning;
+ (UIColor*) SSError;
+ (UIColor*) SSInfo;

@end
