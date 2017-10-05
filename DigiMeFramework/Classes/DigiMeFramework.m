//
//  DigiMeFramework.m
//  digi.me
//
//  Created by digi.me on 24/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "DigiMeFramework.h"
#import "DMEArgonServiceController.h"
#import "DMEUtilities.h"
#import "DMESecurityController.h"

#import "NSError+Helper.h"

NSString * kCARequestSessionKey = @"CARequestSessionKey";
NSString * kCARequestRegisteredAppID = @"CARequestRegisteredAppID";
NSString * kCADigimeResponse    = @"CADigimeResponse";

@interface DigiMeFramework() <DMEArgonServiceControllerDelegate>

@property (nonatomic, strong) DMEArgonServiceController* argonServiceController;

@end

@implementation DigiMeFramework

#pragma mark - Lifecycle
+(instancetype)sharedInstance
{
    static DigiMeFramework* client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        client = [[[self class] alloc] init];
    });
    
    return client;
}

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    [self digimeFrameworkDidChangeOperationState:StateFrameworkInit];
    self.argonServiceController          = [DMEArgonServiceController new];
    self.argonServiceController.delegate = self;
}

- (void)reset
{
    self.argonServiceController          = nil;
    self.argonServiceController          = [DMEArgonServiceController new];
    self.argonServiceController.delegate = self;
}

#pragma mark - URL handling. digi.me app callback
- (BOOL)digimeFrameworkApplication:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options
{
    if([url.absoluteString hasPrefix:kDigiMeFrameworkReceiversURLSchemaPrefix])
    {
        [self digimeFrameworkLogWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Calling Application Bundle ID: %@, URL scheme: %@, URL query: %@", nil), application, [url scheme], [url query]]];
        
        NSURLComponents* urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        NSArray*         queryItems    = urlComponents.queryItems;
        
        BOOL result = [[self valueForKey:kCADigimeResponse fromQueryItems:queryItems] boolValue];
        NSString* sessionKey = [self valueForKey:kCARequestSessionKey fromQueryItems:queryItems];
        
        if(![self.argonServiceController sessionKeyIsValid:sessionKey])
        {
            [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorSessionKeyMismatch];
        }
        
        if(result)
        {
            [self digimeFrameworkDidChangeOperationState:StatePermissionAccessRequestGranted];
            
            [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Digime Controller. Received data from digi.me app. Request is positive",nil)];
            
            [self digimeFrameworkDidChangeOperationState:StateDataRequestSent];
            
            [self.argonServiceController getDataWithCompletion:^(NSArray<NSString *>* _Nullable fileNames,
                                                                 NSDictionary* _Nullable filesWithContent,
                                                                 NSError* _Nullable error) {
                if(error)
                {
                    [self terminateWithError:error];
                }
                else if(fileNames && filesWithContent)
                {
                    [self digimeFrameworkDidChangeOperationState:StateDataRequestReceived];
                    
                    for (NSString* filename in fileNames)
                    {
                        NSString* file = [NSString stringWithFormat:@"%@",[filesWithContent objectForKey:filename]];
                        
                        if(!file)
                        {
                            [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Error. Missing data in the file: %@", filename )];
                        }
                    }
                    
                    if(fileNames.count != filesWithContent.count)
                    {
                        NSArray*        firstArray                  = fileNames.copy;
                        NSPredicate*    relativeComplementPredicate = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", filesWithContent.allKeys.copy];
                        NSArray*        diff                        = [firstArray filteredArrayUsingPredicate:relativeComplementPredicate];
                        [self digimeFrameworkLogWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Error. Missing file names: %@", nill),diff]];
                    }
                    
                    [self digimeFrameworkLogWithMessage:NSLocalizedString(@"All done. Forwarding json files.",nil)];
                    
                    [self finishPaRequestAndReturnData:fileNames filesWithContent:filesWithContent];
                }
                else
                {
                    [self terminateWithErrorID:ErrorDataGetDataIsNull];
                }
            }];
        }
        else
        {
            [self digimeFrameworkDidChangeOperationState:StatePermissionAccessRequestCancelled];
            [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppRejectedByUser];
        }
        
        return YES;
    }
    else
    {
        [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppSchemeIsNotCorrect];
        return NO;
    }
}

#pragma mark - Consent Access
- (void)digimeFrameworkInitiateDataRequestWithAppID:(nonnull NSString*)appID
                                         contractID:(nonnull NSString*)contractID
                                   rsaPrivateKeyHex:(nonnull NSString*)privateKeyHex
{
    NSAssert(privateKeyHex != nil, @"RSA private key is missing");
    BOOL result = [[DMESecurityController sharedInstance] storeRsaPrivateKeyToKeyChain:privateKeyHex];
    NSAssert(result != NO, @"Error saving RSA private key to local keychain");
    if(!result) [self terminateWithErrorID:ErrorSecurityRSAPrivateKeyDataIsInvalid];
    
    [self digimeFrameworkDidChangeOperationState:StateRequestingSessionKey];
    
    [self.argonServiceController sessionKeyCreateWithAppID:appID
                                            withContractID:contractID
                                            withCompletion:^(NSString* _Nullable sessionKey, NSTimeInterval expiry, NSError* _Nullable error) {
                                                
                                                if(error)
                                                {
                                                    [self terminateWithError:error];
                                                }
                                                else if (sessionKey && expiry > 0)
                                                {
                                                    [self digimeFrameworkDidChangeOperationState:StateSessionKeyReceived];
                                                    
                                                    NSURLQueryItem*  sessionKeyComponent     = [NSURLQueryItem queryItemWithName:kCARequestSessionKey value:sessionKey];
                                                    NSURLQueryItem*  registereAppIdComponent = [NSURLQueryItem queryItemWithName:kCARequestRegisteredAppID value:appID];
                                                    NSURLComponents* components              = [NSURLComponents new];
                                                    
                                                    [components setQueryItems: @[sessionKeyComponent,registereAppIdComponent]];
                                                    [components setScheme:kDigiMeFrameworkSendersURLSchema];
                                                    [components setHost:@"data"];
                                                    
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        
                                                        UIApplication*   ourApplication      = [UIApplication sharedApplication];
                                                        NSURL*           url                 = components.URL;
                                                        if ([ourApplication canOpenURL:url])
                                                        {
                                                            if ([ourApplication respondsToSelector:@selector(openURL:options:completionHandler:)])
                                                            {
                                                                NSDictionary *options = @{UIApplicationOpenURLOptionUniversalLinksOnly : @NO};
                                                                
                                                                [ourApplication openURL:url options:options completionHandler:^(BOOL success) {
                                                                    
                                                                    if(success)
                                                                    {
                                                                        [self digimeFrameworkDidChangeOperationState:StatePermissionAccessRequestSent];
                                                                        [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Connected with digi.me app. Data was bypassed successfully",nil)];
                                                                    }
                                                                    else
                                                                    {
                                                                        [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppResultFailed];
                                                                    }
                                                                }];
                                                            }
                                                            else
                                                            {
                                                                BOOL success = [ourApplication openURL:url];
                                                                
                                                                if(success)
                                                                {
                                                                    [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Connected with digi.me app. Data was bypassed successfully",nil)];
                                                                }
                                                                else
                                                                {
                                                                    [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppResultFailed];
                                                                }
                                                            }
                                                        }
                                                        else
                                                        {
                                                            [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppNotAvailable];
                                                        }
                                                    });
                                                }
                                                else
                                                {
                                                    [self terminateWithErrorID:ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppDataIsNull];
                                                }
                                                
                                            }];
}

#pragma mark - Framwork Delegate methods calls
-(void)digimeFrameworkLogWithMessage:(NSString*)message
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkLogWithMessage:)])
    {
        [self.delegate digimeFrameworkLogWithMessage:message];
    }
}

- (void)digimeFrameworkDidChangeOperationState:(DigiMeFrameworkOperationState)state
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkDidChangeOperationState:)])
    {
        [self.delegate digimeFrameworkDidChangeOperationState:state];
    }
}

- (void)digimeFrameworkJsonFilesDownloadProgress:(float)progress
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkJsonFilesDownloadProgress:)])
    {
        [self.delegate digimeFrameworkJsonFilesDownloadProgress:progress];
    }
}

#pragma mark - Private methods
-(void)terminateWithError:(NSError*)error
{
    if (error && error.code == ErrorSessionCreateAppIdRevoke)
    {
        [self alertWithMessage:NSLocalizedString(@"Sorry, this application is no longer valid for Consent Access", nil)];
    }
    
    if (error && error.code == ErrorSessionCreateContractHasExpired)
    {
        [self alertWithMessage:NSLocalizedString(@"Sorry, Consent Access contract has expired", nil)];
    }
    
    if(error && self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkReceiveDataWithFileNames:filesWithContent:error:)])
    {
        [self digimeFrameworkLogWithMessage:[NSString stringWithFormat:@"Error. %@",error.localizedDescription]];
        [self.delegate digimeFrameworkReceiveDataWithFileNames:nil filesWithContent:nil error:error];
    }
}

-(void)terminateWithErrorID:(DigiMeFrameworkErrorCode)errorCode
{
    NSError* error = [[NSError alloc]errorForErrorCode:errorCode];
    
    if(error && self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkReceiveDataWithFileNames:filesWithContent:error:)])
    {
        [self digimeFrameworkLogWithMessage:error.localizedDescription];
        [self.delegate digimeFrameworkReceiveDataWithFileNames:nil filesWithContent:nil error:error];
    }
}

-(void)finishPaRequestAndReturnData:(NSArray<NSString *>*) fileNames
                   filesWithContent:(NSDictionary*) filesWithContent
{
    [self digimeFrameworkDidChangeOperationState:StateDataReceivedAllDone];
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkReceiveDataWithFileNames:filesWithContent:error:)])
    {
        [self.delegate digimeFrameworkReceiveDataWithFileNames:fileNames filesWithContent:filesWithContent error:nil];
    }
    
    [self reset];
}

#pragma mark - Utilities
- (NSString *)valueForKey:(NSString *)key fromQueryItems:(NSArray *)queryItems
{
    NSPredicate*    predicate = [NSPredicate predicateWithFormat:@"name=%@", key];
    NSURLQueryItem* queryItem = [[queryItems filteredArrayUsingPredicate:predicate] firstObject];
    return queryItem.value;
}

-(void)alertWithMessage:(NSString*)message
{
    UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"digi.me" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction*     defaultAction   = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
    
    [alertController addAction:defaultAction];
    
    id rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if([rootViewController isKindOfClass:[UINavigationController class]])
    {
        rootViewController = ((UINavigationController *)rootViewController).viewControllers.firstObject;
    }
    if([rootViewController isKindOfClass:[UITabBarController class]])
    {
        rootViewController = ((UITabBarController *)rootViewController).selectedViewController;
    }
    [rootViewController presentViewController:alertController animated:YES completion:nil];
}

@end

