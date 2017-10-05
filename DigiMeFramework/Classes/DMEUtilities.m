//
//  DMEUtilities.m
//  DigiMeFramework
//
//  Created on 27/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "DMEUtilities.h"

@implementation DMEUtilities

+ (UIViewController *)topmostViewController
{
    return [self topmostViewControllerFromRootViewController:[UIApplication sharedApplication].delegate.window.rootViewController];
}

+ (UIViewController *)topmostViewControllerFromRootViewController:(UIViewController *)rootViewController
{
    if (rootViewController == nil)
    {
        return nil;
    }
    
    if ([rootViewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        return [self topmostViewControllerFromRootViewController:[navigationController.viewControllers lastObject]];
    }
    
    if ([rootViewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tabController = (UITabBarController *)rootViewController;
        return [self topmostViewControllerFromRootViewController:tabController.selectedViewController];
    }
    
    if (rootViewController.presentedViewController) {
        return [self topmostViewControllerFromRootViewController:rootViewController.presentedViewController];
    }
    
    return rootViewController;
}

+ (UIColor *)SSError
{
    return [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:1.0];
}

+ (UIColor *)SSWarning
{
    return [UIColor colorWithRed:245.0f/255.0f green:166.0f/255.0f blue:35.0f/255.0f alpha:1.0f];
}

+ (UIColor *)SSInfo
{
    return [UIColor colorWithRed:74.0f/255.0f green:144.0f/255.0f blue:226.0f/255.0f alpha:1.0f];
}

@end
