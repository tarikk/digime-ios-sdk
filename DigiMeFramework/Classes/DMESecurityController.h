//
//  DMESecurityController.h
//  digi.me
//
//  Created on 24/05/2017.
//  Copyright © 2017 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FileFormatOptions)
{
    FileFormatUnencrypted = 0,
    FileFormatEncrypted   = 1,
};

extern const NSInteger kTypeDescriptorByteLength;

@interface DMESecurityController : NSObject

+ (instancetype)sharedInstance;

- (NSURLSessionAuthChallengeDisposition)authenticateURLChallenge:(NSURLAuthenticationChallenge *)challenge;

- (NSData*)getDataFromEncryptedBytes:(NSData*)encryptedData privateKeyData:(NSData*)privateKeyData;

- (NSData*)base64DataFromString:(NSString *)string;

- (BOOL)storeRsaPrivateKeyToKeyChain:(NSString*)privateKeyHex;

- (NSData*)rsaPrivateKeyDataGet;

- (void)logTestOutput;

@end

NS_ASSUME_NONNULL_END
