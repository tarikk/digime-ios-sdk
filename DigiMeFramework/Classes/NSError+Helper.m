//
//  NSError+Helper.m
//  DigiMe
//
//  Created on 27/05/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "NSError+Helper.h"
#import "DMEUtilities.h"

@implementation NSError (Helper)

- (NSError*)errorForErrorCode:(DigiMeFrameworkErrorCode)errorCode
{
    NSString*       errorMessage = [self getLocalizedMessageForErrorCode:errorCode];
    NSDictionary*   userInfo     = @{NSLocalizedDescriptionKey: errorMessage};
    NSError*        error        = [NSError errorWithDomain:kDigiMeFrameworkErrorDomain code:errorCode userInfo:userInfo];
    return          error;
}

- (NSString*)getLocalizedMessageForErrorCode:(DigiMeFrameworkErrorCode)errorCode
{
    switch (errorCode) {
        case ErrorUnknown:
            return NSLocalizedString(@"digi.me Consent Access Unknown Error",nil);
            break;
            
        case ErrorUserCancelled:
            return NSLocalizedString(@"digi.me Consent Access User Cancelled",nil);
            break;
            
        case ErrorSessionCreateUnknown:
            return NSLocalizedString(@"digi.me Consent Access Create Session Unknown Error",nil);
            break;
 
        case ErrorSessionCreateBadResponse:
            return NSLocalizedString(@"digi.me Consent Access Create Session Bad Response",nil);
            break;

        case ErrorSessionCreateSessionKeyNotReceived:
            return NSLocalizedString(@"digi.me Consent Access Create Session Key Not Received",nil);
            break;
  
        case ErrorContractRequestUnknown:
            return NSLocalizedString(@"digi.me Consent Access Contract Request Unknown Error",nil);
            break;

        case ErrorDataRequestUnknown:
            return NSLocalizedString(@"digi.me Consent Access Data Request Unknown Error",nil);
            break;
            
        case ErrorDataGetUnknown:
            return NSLocalizedString(@"digi.me Consent Access Data Get Unknown Error",nil);
            break;
            
        case ErrorDataGetDataIsNull:
            return NSLocalizedString(@"digi.me Consent Access Data Get Data is NULL",nil);
            break;
            
        case ErrorDataGetFilesListServerResponseWithError:
            return NSLocalizedString(@"digi.me Consent Access Get Files List Server Response With Error",nil);
            break;
            
        case ErrorDataGetFilesListDataIsNotCorrect:
            return NSLocalizedString(@"digi.me Consent Access Get Files List Data Is Not Correct",nil);
            break;
            
        case ErrorDataGetFileDataServerResponseWithError:
            return NSLocalizedString(@"digi.me Consent Access File Data Server Response With Error",nil);
            break;
            
        case ErrorDataGetFileDataDataIsNotCorrect:
            return NSLocalizedString(@"digi.me Consent Access File Data Data Is Not Correct",nil);
            break;

        case ErrorSchemaAppCommunicationsUnknown:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Unknown Error",nil);
            break;
            
        case ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppNotAvailable:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Error Sending Data To Digime App Not Available",nil);
            break;
            
        case ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppResultFailed:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Error Sending Data To Digime App Result Failed",nil);
            break;
            
        case ErrorSchemaAppCommunicationsErrorSendingDataToDigimeAppDataIsNull:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Error Sending Data To Digime App Data Is Null",nil);
            break;
            
        case ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppSchemeIsNotCorrect:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Error Sending Data To Digime App Scheme Is Not Correct",nil);
            break;
            
        case ErrorSchemaAppCommunicationsErrorReceivingDataFromDigimeAppRejectedByUser:
            return NSLocalizedString(@"digi.me Consent Access Schema App Communications Error Sending Data To Digime App Rejected By User",nil);
            break;
            
        default:
            break;
    }
    
    return nil;
}

@end
