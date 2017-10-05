//
//  DigiMeFramework.h
//  digi.me
//
//  Created by digi.me on 24/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// use this receiver's schema prefix + the appId provided by digi.me and add this value into your app Info.plist for CFBundleURLSchemes key

// EXAMPLE:

// <key>CFBundleURLSchemes</key>
// <array>
// <string>digime-ca-YOURAPPID</string>
// </array>

static NSString * kDigiMeFrameworkReceiversURLSchemaPrefix = @"digime-ca-";
static NSString * kDigiMeFrameworkSendersURLSchema         = @"digime-ca-master";
static NSString * kDigiMeFrameworkErrorDomain              = @"me.digi.digime.pa";

typedef NS_ENUM(NSInteger, DigiMeFrameworkOperationState) {
    
    StateUndefined = 0,
    StateFrameworkInit,
    StateRequestingSessionKey,
    StateSessionKeyReceived,
    StatePermissionAccessRequestSent,
    StatePermissionAccessRequestGranted,
    StatePermissionAccessRequestCancelled,
    StateDataRequestSent,
    StateDataRequestReceived,
    StateDataReceivedAllDone,
};

typedef NS_ENUM(NSInteger, DigiMeFrameworkErrorCode) {
    
    ErrorUnknown                                                                   = 700000,
    ErrorUserCancelled                                                             = 700001,
    
    ErrorSessionCreateUnknown                                                      = 710000,
    ErrorSessionCreateBadResponse                                                  = 710001,
    ErrorSessionCreateSessionKeyNotReceived                                        = 710002,
    ErrorSessionCreateAppIdRevoke                                                  = 710403,
    ErrorSessionCreateContractHasExpired                                           = 710410,
    
    ErrorContractRequestUnknown                                                    = 720000,
    
    ErrorDataRequestUnknown                                                        = 730000,
    
    ErrorDataGetUnknown                                                            = 740000,
    ErrorDataGetDataIsNull                                                         = 740001,
    ErrorDataGetFilesListServerResponseWithError                                   = 740002,
    ErrorDataGetFilesListDataIsNotCorrect                                          = 740003,
    ErrorDataGetFileDataServerResponseWithError                                    = 740004,
    ErrorDataGetFileDataDataIsNotCorrect                                           = 740005,
    
    ErrorSchemaAppCommunicationsUnknown                                            = 750000,
    ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppNotAvailable            = 750001,
    ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppResultFailed            = 750002,
    ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppDataIsNull              = 750003,
    ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppSchemeIsNotCorrect  = 750004,
    ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppRejectedByUser      = 750005,
    ErrorSchemaAppCommunicationsErrorSessionKeyMismatch                            = 750006,
    
    ErrorSecurityRSAPrivateKeyDataIsInvalid                                        = 760000,
};

@protocol DigiMeFrameworkDelegate <NSObject>

@required
/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Get result JSON files
 ///------------------------------------------------------------------------------------------------------
 *
 * @param         fileNames         List of requested files
 * @param         filesWithContent  Dictionary of fileNames as keys to the actual content. Content will be
 *                                  encrypted with 3d party public key and base64 encoded.
 * @param         error             NSError object if somthing went worng.
 */
- (void)digimeFrameworkReceiveDataWithFileNames:(NSArray<NSString *>* _Nullable) fileNames
                               filesWithContent:(NSDictionary* _Nullable) filesWithContent
                                          error:(NSError* _Nullable) error;

@optional
/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Log output data
 ///------------------------------------------------------------------------------------------------------
 *
 * @param         message           Log output data
 */
- (void)digimeFrameworkLogWithMessage:(NSString*) message;

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Returns Framework Operation State
 ///------------------------------------------------------------------------------------------------------
 *
 * @param         state             Report back current state of the framework
 */
- (void)digimeFrameworkDidChangeOperationState:(DigiMeFrameworkOperationState)state;

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Returns progress of JSON files downloaded by Framework
 ///------------------------------------------------------------------------------------------------------
 *
 * @param         progress          Report back progress from 0 till 1
 */
- (void)digimeFrameworkJsonFilesDownloadProgress:(float)progress;

@end

@interface DigiMeFramework : NSObject

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Delegate Property
 ///------------------------------------------------------------------------------------------------------
 */
@property (nonatomic, assign) id<DigiMeFrameworkDelegate> delegate;

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** Singleton pattern to communicate with digi.me library
 ///------------------------------------------------------------------------------------------------------
 */
+ (instancetype)sharedInstance;

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Digi.me Framework *** 3rd Party Initiation to Create a PA Session Key
 ///------------------------------------------------------------------------------------------------------
 *
 * @param         appID             3rd Party registered app ID where min length: 5 and max length: 16
 * @param         contractID        3rd Party contract ID where min length: 1 and max length: 64
 * @param         privateKeyHex     3rd Party RSA private key to decrypt JFS json files
 */
- (void)digimeFrameworkInitiateDataRequestWithAppID:(nonnull NSString*) appID
                                         contractID:(nonnull NSString*) contractID
                                   rsaPrivateKeyHex:(nonnull NSString*) privateKeyHex;

/**
 ///------------------------------------------------------------------------------------------------------
 /// @name Consent Access    *** Custom Schema callback to receive actual json files
 ///------------------------------------------------------------------------------------------------------
 *
 * Bypass call from your app delegate to digi.me library 
 * if [url.absoluteString hasPrefix:kDigiMeFrameworkReceiversURLSchemaPrefix]
 *
 */
- (BOOL)digimeFrameworkApplication:(UIApplication *) application
                           openURL:(NSURL *) url
                           options:(NSDictionary *) options;
@end

NS_ASSUME_NONNULL_END
