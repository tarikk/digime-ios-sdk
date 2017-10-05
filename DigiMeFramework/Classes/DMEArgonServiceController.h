//
//  DMEArgonServiceController.h
//  digi.me
//
//  Created by digi.me on 17/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DigiMeFramework.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DMEArgonServiceControllerDelegate <NSObject>

@required
- (void)digimeFrameworkLogWithMessage:(NSString*)message;
- (void)digimeFrameworkDidChangeOperationState:(DigiMeFrameworkOperationState)state;
- (void)digimeFrameworkJsonFilesDownloadProgress:(float)progress;
@end

@interface DMEArgonServiceController : NSObject

@property (nonatomic, weak) id<DMEArgonServiceControllerDelegate> delegate;
@property (nonatomic, readwrite) BOOL isDownloadingData;

- (void)sessionKeyCreateWithAppID:(nonnull NSString*)appID
                   withContractID:(nonnull NSString*)contractID
                   withCompletion:(void(^)(NSString* _Nullable sessionKey, NSTimeInterval expiry, NSError* _Nullable error))completion;

- (void)getDataWithCompletion:(void(^)(NSArray<NSString *>* _Nullable fileNames, NSDictionary* _Nullable filesWithContent, NSError* _Nullable error))completion;

- (BOOL)sessionKeyIsValid:(NSString*)sessionKey;

@end

NS_ASSUME_NONNULL_END
