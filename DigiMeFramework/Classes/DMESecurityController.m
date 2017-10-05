//
//  DMESecurityController.m
//  digi.me
//
//  Created on 24/05/2017.
//  Copyright © 2017 digi.me. All rights reserved.
//

#import "DMESecurityController.h"

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

#import "NSData+SSExtension.h"
#import "NSString+SSExtensions.h"

const size_t        kBUFFER_SIZE             = 64;
const size_t        kCIPHER_BUFFER_SIZE      = 1024;
const uint32_t      kPADDING                 = kSecPaddingNone;

static NSString* kPublicKeyIdentifier     = @"me.digi.digime.publickey";
static NSString* kPrivateKeyIdentifier    = @"me.digi.digime.privatekey";
static NSString* kErrorDomain             = @"me.digi.digime.security";

static const NSString* kDeviceUUID              = @"deviceUUID";
static const NSString* kLibraryID               = @"libraryID";
static const NSString* kLibraryPath             = @"libraryPath";
static const NSString* kPCloudReference         = @"pCloudReference";
static const NSString* kPCloudToken             = @"pCloudToken";
static const NSString* kPCloudType              = @"pCloudType";
static const NSString* kHash                    = @"hash";
static const NSString* kData1                   = @"data1";
static const NSString* kSalt                    = @"salt";
static const NSString* kIterations              = @"iterations";
static const NSString* kDsk                     = @"dsk";
static const NSString* kKiv                     = @"kiv";
static const NSString* kDiv                     = @"div";
static const NSString* kData2                   = @"data2";
static const NSString* kData2Length             = @"data2Length";

const NSInteger kTypeDescriptorByteLength = 16;

static const NSInteger __attribute__((unused)) kDataSymmetricKeyLength = 32;

static const NSInteger kHashLength                      = 64;
static const NSInteger kDataInitializationVectorLength  = 16;
static const NSInteger kDataSymmetricKeyLengthCA        = 256;
static const NSInteger kBASE64QUANTUM                   = 3;
static const NSInteger kBASE64QUANTUMREP                = 4;

@interface DMESecurityController()
{

}

@property (nonatomic, strong) NSArray<NSData*>* localCerts;

@end

@implementation DMESecurityController

#pragma mark - Lifecycle
+ (instancetype)sharedInstance
{
    static DMESecurityController * secController;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        secController = [[[self class] alloc] init];
    });
    
    return secController;
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
    NSMutableArray* certs = [NSMutableArray new];
    for (int i = 1; i<=3; i++)
    {
        NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:[NSString stringWithFormat:@"apiCert%d",i,nil] ofType:@"der"];
        if(path)
        {
            NSData* data = [NSData dataWithContentsOfFile:path];
            if(data)
            {
                [certs addObject:data];
            }
        }
    }
    self.localCerts = certs.copy;
}

#pragma mark - Error handling
- (NSError *) errorWithCCCryptorStatus: (CCCryptorStatus) status
{
    NSString * description = nil;
    NSString * reason      = nil;
    
    switch ( status )
    {
        case kCCSuccess:
            description = NSLocalizedString(@"Success", @"Error description");
            break;
            
        case kCCParamError:
            description = NSLocalizedString(@"Parameter Error", @"Error description");
            reason = NSLocalizedString(@"Illegal parameter supplied to encryption/decryption algorithm", @"Error reason");
            break;
            
        case kCCBufferTooSmall:
            description = NSLocalizedString(@"Buffer Too Small", @"Error description");
            reason = NSLocalizedString(@"Insufficient buffer provided for specified operation", @"Error reason");
            break;
            
        case kCCMemoryFailure:
            description = NSLocalizedString(@"Memory Failure", @"Error description");
            reason = NSLocalizedString(@"Failed to allocate memory", @"Error reason");
            break;
            
        case kCCAlignmentError:
            description = NSLocalizedString(@"Alignment Error", @"Error description");
            reason = NSLocalizedString(@"Input size to encryption algorithm was not aligned correctly", @"Error reason");
            break;
            
        case kCCDecodeError:
            description = NSLocalizedString(@"Decode Error", @"Error description");
            reason = NSLocalizedString(@"Input data did not decode or decrypt correctly", @"Error reason");
            break;
            
        case kCCUnimplemented:
            description = NSLocalizedString(@"Unimplemented Function", @"Error description");
            reason = NSLocalizedString(@"Function not implemented for the current algorithm", @"Error reason");
            break;
            
        default:
            description = NSLocalizedString(@"Unknown Error", @"Error description");
            break;
    }
    
    NSMutableDictionary * userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject: description forKey: NSLocalizedDescriptionKey];
    
    if ( reason != nil )
        [userInfo setObject: reason forKey: NSLocalizedFailureReasonErrorKey];
    
    NSError * result = [NSError errorWithDomain: kErrorDomain code: status userInfo: userInfo];
    
    return ( result );
}

#pragma mark - Random
- (NSData*)getRandomUnsignedCharacters:(int)length
{
    NSString* letters = [self getStringWithCharRange:'0' toChar:'9'];
    NSString* result  = nil;
    result = [self getRandom:length letters:letters];
    NSAssert(result != nil, @"random function returns an error");
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData*)getRandomAlpha:(int)length;
{
    NSString* letters = [self getStringWithCharRange:'a' toChar:'z'];
    NSString* result  = nil;
    result = [self getRandom:length letters:letters];
    NSAssert(result != nil, @"random function returns an error");
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData*)getRandomHex:(int)length;
{
    NSString* letters = [NSString stringWithFormat:@"%@%@"
                         ,[self getStringWithCharRange:'0' toChar:'9']
                         ,[self getStringWithCharRange:'a' toChar:'f']];
    
    NSString* result  = nil;
    result = [self getRandom:length letters:letters];
    NSAssert(result != nil, @"random function returns an error");
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData*)getRandomUpperLowerNumeric:(int)length;
{
    NSString* letters = [NSString stringWithFormat:@"%@%@%@"
                         ,[self getStringWithCharRange:'a' toChar:'z']
                         ,[self getStringWithCharRange:'A' toChar:'Z']
                         ,[self getStringWithCharRange:'0' toChar:'9']];
    
    NSString* result  = nil;
    result = [self getRandom:length letters:letters];
    NSAssert(result != nil, @"random function returns an error");
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString*)getRandom:(int)length letters:(NSString*)letters
{
    NSMutableString* randomString = [NSMutableString stringWithCapacity:length];
    
    for (int i = 0; i < length; i++)
    {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((int)[letters length])]];
    }
    
    return randomString.copy;
}

- (NSString*)getStringWithCharRange:(char)from toChar:(char)to
{
    NSMutableArray* array = [NSMutableArray new];
    
    for (char a = from; a <= to; a++)
    {
        [array addObject:[NSString stringWithFormat:@"%c", a]];
    }
    
    NSString* result = [array componentsJoinedByString:@""];
    NSAssert(result != nil, @"random string generator function returns an error");
    return result;
}

- (NSData *)randomDataOfLength:(size_t)length
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    
    int result __attribute__((unused)) = SecRandomCopyBytes(kSecRandomDefault,
                                    length,
                                    data.mutableBytes);
    NSAssert(result == 0, @"Unable to generate random bytes: %d", errno);
    
    return data;
}

#pragma mark - Hashing
- (NSData *)hashSha256:(NSData*)data
{
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    (void) CC_SHA256( [data bytes], (CC_LONG)[data length], hash );
    return ( [NSData dataWithBytes: hash length: CC_SHA256_DIGEST_LENGTH] );
}

- (NSData *)hashSha512:(NSData*)data
{
    unsigned char hash[CC_SHA512_DIGEST_LENGTH];
    (void) CC_SHA512( [data bytes], (CC_LONG)[data length], hash );
    return ( [NSData dataWithBytes: hash length: CC_SHA512_DIGEST_LENGTH] );
}

#pragma Mark - Base 64
- (NSData *)base64DataFromString: (NSString *)string
{
    unsigned char ch, accumulated[kBASE64QUANTUMREP], outbuf[kBASE64QUANTUM];
    const unsigned char *charString;
    NSMutableData *theData;
    const int OUTOFRANGE = 64;
    const unsigned char LASTCHARACTER = '=';
    
    if (string == nil)
    {
        return [NSData data];
    }
    
    for (int i = 0; i < kBASE64QUANTUMREP; i++) {
        accumulated[i] = 0;
    }
    
    charString = (const unsigned char *)[string UTF8String];
    
    theData = [NSMutableData dataWithCapacity: [string length]];
    
    short accumulateIndex = 0;
    for (int index = 0; index < [string length]; index++) {
        
        ch = decodeBase64[charString [index]];
        
        if (ch < OUTOFRANGE)
        {
            short ctcharsinbuf = kBASE64QUANTUM;
            
            if (charString [index] == LASTCHARACTER)
            {
                if (accumulateIndex == 0)
                {
                    break;
                }
                else if (accumulateIndex <= 2)
                {
                    ctcharsinbuf = 1;
                }
                else
                {
                    ctcharsinbuf = 2;
                }
                
                accumulateIndex = kBASE64QUANTUM;
            }
            //
            // Accumulate 4 valid characters (ignore everything else)
            //
            accumulated [accumulateIndex++] = ch;
            
            //
            // Store the 6 bits from each of the 4 characters as 3 bytes
            //
            if (accumulateIndex == kBASE64QUANTUMREP)
            {
                accumulateIndex = 0;
                
                outbuf[0] = (accumulated[0] << 2) | ((accumulated[1] & 0x30) >> 4);
                outbuf[1] = ((accumulated[1] & 0x0F) << 4) | ((accumulated[2] & 0x3C) >> 2);
                outbuf[2] = ((accumulated[2] & 0x03) << 6) | (accumulated[3] & 0x3F);
                
                for (int i = 0; i < ctcharsinbuf; i++)
                {
                    [theData appendBytes: &outbuf[i] length: 1];
                }
            }
            
        }
        
    }
    
    return theData;
}

static unsigned char decodeBase64[256] = {
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x00
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x10
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x20
    64, 64, 64, 62, 64, 64, 64, 63,
    52, 53, 54, 55, 56, 57, 58, 59,  // 0x30
    60, 61, 64, 64, 64,  0, 64, 64,
    64,  0,  1,  2,  3,  4,  5,  6,  // 0x40
    7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22,  // 0x50
    23, 24, 25, 64, 64, 64, 64, 64,
    64, 26, 27, 28, 29, 30, 31, 32,  // 0x60
    33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48,  // 0x70
    49, 50, 51, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x80
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0x90
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xA0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xB0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xC0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xD0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xE0
    64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64,  // 0xF0
    64, 64, 64, 64, 64, 64, 64, 64,
};


#pragma mark - AES
- (NSData *)encryptAes128UsingKey:(NSData*)keyData initializationVector:(NSData*)ivData data:(NSData*)data error:(NSError **)error
{
    CCCryptorStatus status = kCCSuccess;
    NSData * result = [self dataEncryptedUsingAlgorithm:kCCAlgorithmAES128
                                                    key:keyData
                                   initializationVector:ivData
                                                options:kCCOptionPKCS7Padding
                                              keyLength:kCCKeySizeAES128
                                                   data:data
                                                  error:&status];
    
    if ( result != nil )
        return ( result );
    
    if ( error != NULL )
        *error = [self errorWithCCCryptorStatus: status];
    
    return ( nil );
}

- (NSData *)decryptAes128UsingKey:(NSData*)keyData initializationVector:(NSData*)ivData data:(NSData*)data error:(NSError **)error
{
    CCCryptorStatus status = kCCSuccess;
    NSData * result = [self decryptedDataUsingAlgorithm:kCCAlgorithmAES128
                                                    key:keyData
                                   initializationVector:ivData
                                                options:0
                                              keyLength:kCCKeySizeAES128
                                                   data:data
                                                  error:&status];
    
    if ( result != nil )
        return ( result );
    
    if ( error != NULL )
        *error = [self errorWithCCCryptorStatus: status];
    
    return ( nil );
}

- (NSData *)encryptAes256UsingKey:(NSData*)keyData initializationVector:(NSData*)ivData data:(NSData*)data error:(NSError **)error
{
    CCCryptorStatus status = kCCSuccess;
    NSData * result = [self dataEncryptedUsingAlgorithm:kCCAlgorithmAES128
                                                    key:keyData
                                   initializationVector:ivData
                                                options:kCCOptionPKCS7Padding
                                              keyLength:kCCKeySizeAES256
                                                   data:data
                                                  error:&status];
    
    if ( result != nil )
        return ( result );
    
    if ( error != NULL )
        *error = [self errorWithCCCryptorStatus: status];
    
    return ( nil );
}

- (NSData *)decryptAes256UsingKey:(NSData*)keyData initializationVector:(NSData*)ivData data:(NSData*)data error:(NSError **)error
{
    CCCryptorStatus status = kCCSuccess;
    NSData * result = [self decryptedDataUsingAlgorithm:kCCAlgorithmAES128
                                                    key:keyData
                                   initializationVector:ivData
                                                options:kCCOptionPKCS7Padding
                                              keyLength:kCCKeySizeAES256
                                                   data:data
                                                  error:&status];
    if ( result != nil )
        return ( result );
    
    if ( error != NULL )
        *error = [self errorWithCCCryptorStatus: status];
    
    return ( nil );
}


- (NSData *) dataEncryptedUsingAlgorithm:(CCAlgorithm)algorithm
                                     key:(NSData*)keyData
                    initializationVector:(NSData*)ivData
                                 options:(CCOptions)options
                               keyLength:(NSInteger)keyLength
                                    data:(NSData*)data
                                   error:(CCCryptorStatus *)error
{
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = kCCSuccess;
    
    NSAssert([keyData length] == keyLength, @"The key length is wrong");
    
    status = CCCryptorCreate( kCCEncrypt, algorithm, options,
                             [keyData bytes], [keyData length], [ivData bytes],
                             &cryptor );
    
    if ( status != kCCSuccess )
    {
        if ( error != NULL )
            *error = status;
        return ( nil );
    }
    
    NSData * result = [self runCryptor:cryptor result:&status data:data];
    if ( (result == nil) && (error != NULL) )
        *error = status;
    
    CCCryptorRelease( cryptor );
    
    return ( result );
}

- (NSData *) decryptedDataUsingAlgorithm:(CCAlgorithm)algorithm
                                     key:(NSData*)keyData
                    initializationVector:(NSData*)ivData
                                 options:(CCOptions)options
                               keyLength:(NSInteger)keyLength
                                    data:(NSData*)data
                                   error:(CCCryptorStatus *)error
{
    CCCryptorRef cryptor = NULL;
    CCCryptorStatus status = kCCSuccess;

    NSAssert([keyData length] == keyLength, @"The key length is wrong");
    
    status = CCCryptorCreate( kCCDecrypt, algorithm, options,
                             [keyData bytes], [keyData length], [ivData bytes],
                             &cryptor );
    
    if ( status != kCCSuccess )
    {
        if ( error != NULL )
            *error = status;
        return ( nil );
    }
    
    NSData * result = [self runCryptor:cryptor result:&status data:data];
    if ( (result == nil) && (error != NULL) )
        *error = status;
    
    CCCryptorRelease( cryptor );
    
    return ( result );
}

- (NSData *)runCryptor: (CCCryptorRef) cryptor result: (CCCryptorStatus *) status data:(NSData*)data
{
    size_t bufsize = CCCryptorGetOutputLength( cryptor, (size_t)[data length], true );
    void * buf = malloc( bufsize );
    size_t bufused = 0;
    size_t bytesTotal = 0;
    *status = CCCryptorUpdate( cryptor, [data bytes], (size_t)[data length],
                              buf, bufsize, &bufused );
    if ( *status != kCCSuccess )
    {
        free( buf );
        return ( nil );
    }
    
    bytesTotal += bufused;
    
    // From Brent Royal-Gordon (Twitter: architechies):
    //  Need to update buf ptr past used bytes when calling CCCryptorFinal()
    *status = CCCryptorFinal( cryptor, buf + bufused, bufsize - bufused, &bufused );
    if ( *status != kCCSuccess )
    {
        free( buf );
        return ( nil );
    }
    
    bytesTotal += bufused;
    
    return ( [NSData dataWithBytesNoCopy: buf length: bytesTotal] );
}



#pragma mark - RSA
-(NSString*)encryptRSA:(NSString*) plainTextString publicKey:(SecKeyRef) publicKey
{
    OSStatus status             = noErr;
    size_t   cipherBufferSize   = SecKeyGetBlockSize(publicKey);
    uint8_t* cipherBuffer       = malloc(cipherBufferSize);
    uint8_t* nonce              = (uint8_t*)[plainTextString UTF8String];
    
    NSAssert([plainTextString length] <= cipherBufferSize, @"The text length is larger than key length");
    
    status = SecKeyEncrypt(publicKey,
                           kSecPaddingOAEP,
                           nonce,
                           strlen((char*)nonce),
                           &cipherBuffer[0],
                           &cipherBufferSize);
    
    NSAssert(status == noErr, @"RSA encryption failed");
    
    if(status != noErr)
        return nil;
    
    NSData* encryptedData = [NSData dataWithBytes:cipherBuffer length:cipherBufferSize];
    return [encryptedData base64EncodedStringWithOptions:0];
}

-(NSString*)decryptRSA:(NSString*) cipherString privateKey:(SecKeyRef) privateKey
{
    OSStatus status             = noErr;
    size_t   plainBufferSize    = SecKeyGetBlockSize(privateKey);
    uint8_t* plainBuffer        = malloc(plainBufferSize);
    NSData*  incomingData       = [[NSData alloc] initWithBase64EncodedString:cipherString options:0];
    uint8_t* cipherBuffer       = (uint8_t*)[incomingData bytes];
    size_t   cipherBufferSize   = SecKeyGetBlockSize(privateKey);
    
    status = SecKeyDecrypt(privateKey,
                           kSecPaddingOAEP,
                           cipherBuffer,
                           cipherBufferSize,
                           plainBuffer,
                           &plainBufferSize);
    
    NSAssert(status == noErr, @"RSA decryption failed");
    
    if(status != noErr)
        return nil;
    
    NSData*   decryptedData   = [NSData dataWithBytes:plainBuffer length:plainBufferSize];
    NSString* decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    return    decryptedString;
}

- (NSData*)encryptLongTextString:(NSString*)text publicKey:(SecKeyRef)publicKey
{
    NSCParameterAssert(text.length > 0);
    NSCParameterAssert(publicKey != NULL);
    
    NSData*         dataToEncrypt       = [text dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t*  bytesToEncrypt      = dataToEncrypt.bytes;
    size_t          cipherBufferSize    = SecKeyGetBlockSize(publicKey);
    const size_t    blockSize           = cipherBufferSize - 42;
    uint8_t*        cipherBuffer        = (uint8_t *) malloc(sizeof(uint8_t) * cipherBufferSize);
    NSMutableData*  result              = [[NSMutableData alloc] init];
    
    NSCAssert(cipherBufferSize > 42, @"block size is too small: %zd", cipherBufferSize);
    
    @try {
        
        for (size_t block = 0; block * blockSize < dataToEncrypt.length; block++)
        {
            OSStatus        status              = noErr;
            size_t          blockOffset         = block * blockSize;
            const uint8_t*  chunkToEncrypt      = (bytesToEncrypt + block * blockSize);
            const size_t    remainingSize       = dataToEncrypt.length - blockOffset;
            const size_t    subsize             = remainingSize < blockSize ? remainingSize : blockSize;
            size_t          actualOutputSize    = cipherBufferSize;
            
            status = SecKeyEncrypt(publicKey,
                                   kSecPaddingOAEP,
                                   chunkToEncrypt,
                                   subsize,
                                   cipherBuffer,
                                   &actualOutputSize);
            
            NSAssert(status == noErr, @"RSA encryption failed");
            
            if (status != noErr)
            {
                return nil;
            }
            
            [result appendBytes:cipherBuffer length:actualOutputSize];
        }
        
        return [result copy];
    }
    @finally
    {
        free(cipherBuffer);
    }
}

- (NSData*)decryptLongTextString:(NSData*)dataToDecrypt privateKey:(SecKeyRef)privateKey
{
    NSCParameterAssert(dataToDecrypt != NULL);
    NSCParameterAssert(privateKey != NULL);
    
    
    uint8_t*        bytesToDecrypt      = (uint8_t*)dataToDecrypt.bytes;
    size_t          cipherBufferSize    = SecKeyGetBlockSize(privateKey);
    const size_t    blockSize           = cipherBufferSize;
    uint8_t*        cipherBuffer        = (uint8_t *) malloc(sizeof(uint8_t) * cipherBufferSize);
    NSMutableData*  result              = [[NSMutableData alloc] init];
    
    NSCAssert(cipherBufferSize > 42, @"block size is too small: %zd", cipherBufferSize);
    
    @try {
        
        for (size_t block = 0; block * blockSize < dataToDecrypt.length; block++)
        {
            OSStatus        status              = noErr;
            size_t          blockOffset         = block * blockSize;
            const uint8_t*  chunkToDecrypt      = (bytesToDecrypt + block * blockSize);
            const size_t    remainingSize       = dataToDecrypt.length - blockOffset;
            const size_t    subsize             = remainingSize < blockSize ? remainingSize : blockSize;
            size_t          actualOutputSize    = cipherBufferSize;
            
            status = SecKeyDecrypt(privateKey,
                                   kSecPaddingOAEP,
                                   chunkToDecrypt,
                                   subsize,
                                   cipherBuffer,
                                   &actualOutputSize);
            
            NSAssert(status == noErr, @"RSA decryption failed");
            
            if (status != noErr)
            {
                return nil;
            }
            
            [result appendBytes:cipherBuffer length:actualOutputSize];
        }
        
        return [result copy];
    }
    @finally
    {
        free(cipherBuffer);
    }
}

- (BOOL)generateKeyPairWithPublicTagString:(NSString*)publicTagString privateTagString:(NSString*) privateTagString keySize:(NSNumber*)keySize isPermanent:(BOOL)isPermanent
{
    NSData* publicTag  = [[NSData alloc] initWithBytes:(const void *)[publicTagString UTF8String] length:[publicTagString length]];
    NSData* privateTag = [[NSData alloc] initWithBytes:(const void *)[privateTagString UTF8String] length:[privateTagString length]];
    
    NSDictionary* keyPairAttr = @{
                                  (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
                                  (__bridge id)kSecAttrKeySizeInBits            : keySize,
                                  (__bridge id)kSecPrivateKeyAttrs              : @{
                                          (__bridge id)kSecAttrIsPermanent      : [NSNumber numberWithBool:isPermanent],
                                          (__bridge id)kSecAttrApplicationTag   : privateTag
                                          },
                                  (__bridge id)kSecPublicKeyAttrs : @{
                                          (__bridge id)kSecAttrIsPermanent      : [NSNumber numberWithBool:isPermanent],
                                          (__bridge id)kSecAttrApplicationTag   : publicTag
                                          }
                                  };
    
    SecKeyRef publicKey  = NULL;
    SecKeyRef privateKey = NULL;
    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKey, &privateKey);
    
    if (publicKey)
        CFRelease(publicKey);
    if (privateKey)
        CFRelease(privateKey);
    
    if (status == noErr)
        return YES;
    
    return NO;
}

-(BOOL)saveRSAKeyWithKeyClass:(CFTypeRef) keyClass keyData:(NSData*)keyData keyTagString:(NSString*)keyTagString overwrite:(BOOL) overwrite
{
    CFDataRef ref       = NULL;
    NSData*   peerTag   = [[NSData alloc] initWithBytes:(const void *)[keyTagString UTF8String] length:[keyTagString length]];
    
    NSDictionary* attr = @{
                           (__bridge id)kSecClass               : (__bridge id)kSecClassKey,
                           (__bridge id)kSecAttrKeyType         : (__bridge id)kSecAttrKeyTypeRSA,
                           (__bridge id)kSecAttrKeyClass        : (__bridge id)keyClass,
                           (__bridge id)kSecAttrIsPermanent     : @YES,
                           (__bridge id)kSecAttrApplicationTag  : peerTag,
                           (__bridge id)kSecValueData           : keyData,
                           (__bridge id)kSecReturnPersistentRef : @YES,
                           (__bridge id)kSecReturnData          : @YES
                           };
    
    
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)attr, (CFTypeRef*)&ref);
    
    if (status == noErr)
        return YES;
    else if (status == errSecDuplicateItem && overwrite == YES)
        return [self updateRSAKeyWithKeyClass:keyClass keyData:keyData keyTagString:keyTagString];
    
    return NO;
}

-(BOOL) updateRSAKeyWithKeyClass:(CFTypeRef) keyClass keyData:(NSData*)keyData keyTagString:(NSString*)keyTagString
{
    NSData* peerTag = [[NSData alloc] initWithBytes:(const void *)[keyTagString UTF8String] length:[keyTagString length]];
    
    NSDictionary* matchingAttr = @{
                                   (__bridge id)kSecClass               : (__bridge id)kSecClassKey,
                                   (__bridge id)kSecAttrKeyType         : (__bridge id)kSecAttrKeyTypeRSA,
                                   (__bridge id)kSecAttrKeyClass        : (__bridge id)keyClass,
                                   (__bridge id)kSecAttrApplicationTag  : peerTag
                                   };
    OSStatus matchingStatus = SecItemCopyMatching((__bridge CFDictionaryRef)matchingAttr, NULL);
    
    if (matchingStatus == noErr) {
        NSDictionary* updateAttr = @{
                                     (__bridge id)kSecClass             : (__bridge id)kSecClassKey,
                                     (__bridge id)kSecAttrKeyType       : (__bridge id)kSecAttrKeyTypeRSA,
                                     (__bridge id)kSecAttrKeyClass      : (__bridge id)keyClass,
                                     (__bridge id)kSecAttrApplicationTag: peerTag
                                     };
        NSDictionary* update = @{
                                 (__bridge id)kSecValueData : keyData
                                 };
        OSStatus updateStatus = SecItemUpdate((__bridge CFDictionaryRef)updateAttr, (__bridge CFDictionaryRef)update);
        return updateStatus == noErr;
    }
    return NO;
}

-(SecKeyRef)loadRSAKeyWithKeyClass:(CFTypeRef)keyClass keyTagString:(NSString*)keyTagString
{
    NSData* peerTag = [[NSData alloc] initWithBytes:(const void *)[keyTagString UTF8String] length:[keyTagString length]];

    NSDictionary* attr = @{
                           (__bridge id)kSecClass               : (__bridge id)kSecClassKey,
                           (__bridge id)kSecAttrKeyType         : (__bridge id)kSecAttrKeyTypeRSA,
                           (__bridge id)kSecAttrKeyClass        : (__bridge id)keyClass,
                           (__bridge id)kSecAttrApplicationTag  : peerTag,
                           (__bridge id)kSecReturnRef           : @YES
                           };
    
    SecKeyRef keyRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attr, (CFTypeRef*)&keyRef);
    
    if (status == noErr)
        return keyRef;
    else
        return NULL;
}

-(NSData*)loadRSAKeyDataWithKeyClass:(CFTypeRef)keyClass  keyTagString:(NSString*)keyTagString
{
    NSData* peerTag = [[NSData alloc] initWithBytes:(const void *)[keyTagString UTF8String] length:[keyTagString length]];
    
    NSDictionary* attr = @{
                           (__bridge id)kSecClass               : (__bridge id)kSecClassKey,
                           (__bridge id)kSecAttrKeyType         : (__bridge id)kSecAttrKeyTypeRSA,
                           (__bridge id)kSecAttrKeyClass        : (__bridge id)keyClass,
                           (__bridge id)kSecAttrApplicationTag  : peerTag,
                           (__bridge id)kSecReturnData          : @YES
                           };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attr, (CFTypeRef*)&result);
    
    if (status == noErr && result)
        return (NSData*)CFBridgingRelease(result);
    else if (result)
        CFRelease(result);
    
    return nil;
}

- (BOOL)deleteRSAKeyWithKeyClass:(CFTypeRef)keyClass keyTagString:(NSString*)keyTagString
{
    NSData* peerTag = [[NSData alloc] initWithBytes:(const void *)[keyTagString UTF8String] length:[keyTagString length]];

    NSDictionary* attr = @{
                           (__bridge id)kSecClass               : (__bridge id)kSecClassKey,
                           (__bridge id)kSecAttrKeyType         : (__bridge id)kSecAttrKeyTypeRSA,
                           (__bridge id)kSecAttrKeyClass        : (__bridge id)keyClass,
                           (__bridge id)kSecAttrApplicationTag  : peerTag
                           };
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)attr);
    
    return status == noErr;
}

#pragma mark - digi.me Key Deriviation
- (NSData*)getPbkdf2Sha512Key:(NSData*)keyData
                         salt:(NSData*)saltData
                       rounds:(NSInteger)rounds
                        error:(NSError **)error
{
    NSDate *date = [NSDate date];
    NSDictionary *logMeta = @{
                              @"iterations" : @(rounds),
                              @"length"     : @(keyData.length),
                              @"saltLength" : @(saltData.length)
                              };
    
    CCCryptorStatus status      = kCCSuccess;
    NSMutableData*  hashKeyData = [NSMutableData dataWithLength:32];
    
    CCPseudoRandomAlgorithm prf = kCCPRFHmacAlgSHA512;
    
    status = CCKeyDerivationPBKDF(kCCPBKDF2,                // algorithm
                                  keyData.bytes,            // password
                                  keyData.length,           // passwordLength
                                  saltData.bytes,           // salt
                                  saltData.length,          // saltLen
                                  prf,                      // PRF
                                  (int)rounds,              // rounds
                                  hashKeyData.mutableBytes, // derivedKey
                                  hashKeyData.length);      // derivedKeyLen
    
    if (status != kCCSuccess)
    {
        *error = [self errorWithCCCryptorStatus: status];
        return nil;
    }
    
    double timePassed_ms = [date timeIntervalSinceNow] * -1000.0;
    NSMutableDictionary *successMeta = [NSMutableDictionary dictionaryWithDictionary:logMeta];
    [successMeta removeObjectForKey:@"saltLength"];
    [successMeta setObject:@(timePassed_ms) forKey:@"time"];
    [successMeta setObject:@([hashKeyData.description stringFromNSDataDescription].length) forKey:@"length"];
    
    return hashKeyData;
}


#pragma mark - Utility functions
- (NSData *)stripPublicKeyHeader:(NSData *)d_key
{
    // Skip ASN.1 public key header
    if(d_key == nil) return nil;
    
    unsigned int len = (unsigned int)[d_key length];
    if(!len) return nil;
    
    unsigned char *c_key = (unsigned char *)[d_key bytes];
    unsigned int idx = 0;
    
    if(c_key[idx++] != 0x30) return nil;
    if(c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    // PKCS #1 rsaEncryption szOID_RSA_RSA
    static unsigned char seqiod[] = {
        0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00
    };
    if(memcmp(&c_key[idx], seqiod, 15)) return nil;
    idx += 15;
    
    if(c_key[idx++] != 0x03) return nil;
    if(c_key[idx] > 0x80) idx += c_key[idx] - 0x80 + 1;
    else idx++;
    
    if(c_key[idx++] != '\0') return nil;
    
    // Now make a new NSData from this buffer
    return [NSData dataWithBytes:&c_key[idx] length:len-idx];
}

#pragma mark - digi.me Tests

- (void)logTestOutput
{
    [self testCAEncryptionVer2];
}

-(void)testCAEncryptionVer2
{
    NSString* publicKeyHex = @"3082010a0282010100c947db8ccf38c1f40a7cd9c4333e0368023f84d8be46d37ad5954e497000ae2d580a62e08de009313a829e82b24bba0caf0475dfaec0b36f4f84b62684f39aab69b31a4e027409d887ba88e34c8139539b2c6d2ee3fd9d23cac34330901c7ae98e4f2fad9edc0f1679571cc7259bd1a95ad6f308bf7d3cf33351324933f122bdce4006d5a0643223e759bf5fad8af59d626e8d7abc7198810e94d66c788c10329264acd6aa66153280d9c881cfe816a6fdefe85a2e2504328e76d8d642fcfcbab4b0b2ea184feb006eefe24db889b696382f122c44cece717fda7735aa12ce4e7bba914c8d45cbef9c3ab47cb8e3c40af32bf7eafd6b8aaee2f70c839362adeb0203010001";
    NSData* publicKeyData = [publicKeyHex stringConvertToBytesWhereStringIsHex:YES];
    BOOL result1 = [self saveRSAKeyWithKeyClass:kSecAttrKeyClassPublic keyData:publicKeyData keyTagString:kPublicKeyIdentifier overwrite:YES];
    NSLog(@"saveRSAKeyWithKeyClass: %@", result1 ? @"YES" : @"NO");
    
    NSString* privateKeyHex = @"308204a50201000282010100c947db8ccf38c1f40a7cd9c4333e0368023f84d8be46d37ad5954e497000ae2d580a62e08de009313a829e82b24bba0caf0475dfaec0b36f4f84b62684f39aab69b31a4e027409d887ba88e34c8139539b2c6d2ee3fd9d23cac34330901c7ae98e4f2fad9edc0f1679571cc7259bd1a95ad6f308bf7d3cf33351324933f122bdce4006d5a0643223e759bf5fad8af59d626e8d7abc7198810e94d66c788c10329264acd6aa66153280d9c881cfe816a6fdefe85a2e2504328e76d8d642fcfcbab4b0b2ea184feb006eefe24db889b696382f122c44cece717fda7735aa12ce4e7bba914c8d45cbef9c3ab47cb8e3c40af32bf7eafd6b8aaee2f70c839362adeb02030100010282010100b133bafd377e2f7acb34e97f0ae1e09bd3c6da0cfb4f5d65b9dd6d83c7c0419797f7e4deeee8bb0f0504f3c9fa7022c681daba6f87e90ccfc541001fdf529beba6edd00db7a932f5d760889d1bc07498bf7718547cd1cd6332623fa7e467be6a1a286ac03ea85bfc1c2d6e1f8163b1ec9815bef707a6995f3ee19014d44ec996a29559ae00abc0b0b61f1a147e1aac5f792b5469aa3c7ed8358b3e186af1d9aac25677b2c05f3c664e8885d558208a46f3e3843f405399c2b3bab30c65a725d7a198bd49ca0ad7e7752da99bd00290f70fc77a0f7973120ce140e57df5799d7115bca6c4d70da91fae4f3be72d53e5bfdc1fe15dd37f046d6589e3726ad8f48902818100ec6a39092fbfce6d051bb9b671362e26a285ae5aadc92214bd4673d9690e45b5ca19b11294b5908573de7ca2e7c1d83e212dfb70831d3a50199d1946a9e49e2bdd5ecf3c918d60db7aa2526f7ebd0c84e9408993e6a41341410c2a55771f9a61a40a8af7e4798eee1e98ccd7d1dd3f8eb86ce76518372fde301f103a5cb133cd02818100d9f4863a8998c59c14b2278fb45adf99b03af2d47082a55ab2585fd0f037e90e3320150bfe92ad1b92515e1930ea8f6e55172f8a1470b34ff7b67e3b034e15e993426f974a90ad5ad6273919d8d995bc0fd9547a8db60a8228ccaa07d9139b3dcc79fe5422f7b6026966751589d4b9b89ce0261c363179b9ccaef06a6d71a0970281802348932c98d0c28928cb0383840ff701531e2a7064217191b0d1f3f64da490a8d9f9cda09d4b1fbf9b14687b93a52d95d033e1a3e01d9b975acb447b745da7719a7f4ce4984086651b3f60983d4d0fb242719c56d384474f64dae0f2926dc807ac88da46b6f5a16c4e6ab59fbc358e07c9e48f005a85da020a2288b47d23013d02818100d4cf72b8795d57a55c77cf34fb4eb780a2980c3ded55430ad9947c89cfe367855bd9f972eab060a1c92df588f7402fa7f5215c63a02da287744115e39d088350bb5e6502fde561be8dd76263a05e635b6ac6333c2e5e0ec8a3f9a213639b473b020a2390174c72c4cc112445517d0991fe6ac60b49c6e929c777107b7a3d362502818100df9d7183ca83afd0c9f22ad3f5e6fd08fa5f82092c62a0d804af11ae734519633a8ade6ff18efe86d588d8cfc396b40b2591f85a99153d84ef4f980b3d471290717a1d6329a369d16d180f8fdd1fca23e3140f5899ef49cd5ce747491aa63d0aab67922367d778cf84ac46b03232beacc4c0e20718fdbb88d367d48c975ca3f4";
    NSData* privateKeyData = [privateKeyHex stringConvertToBytesWhereStringIsHex:YES];
    BOOL result2 = [self saveRSAKeyWithKeyClass:kSecAttrKeyClassPrivate keyData:privateKeyData keyTagString:kPrivateKeyIdentifier overwrite:YES];
    NSLog(@"saveRSAKeyWithKeyClass: %@", result2 ? @"YES" : @"NO");
    
    NSString*   ca_file_path    = [[NSBundle mainBundle]pathForResource:@"ca_file_encryption_v2" ofType:@"valid"];
    NSData*     ca_file_data    = [NSData dataWithContentsOfFile:ca_file_path];
    
    NSData* jfsData = [self getDataFromEncryptedBytes:ca_file_data privateKeyData:privateKeyData];
    
    NSAssert(jfsData != nil, @"JFS data cannot be nil");
    
    NSError* error;
    NSDictionary* jfsFileDictionary = [NSJSONSerialization JSONObjectWithData:jfsData options:kNilOptions error:&error];
    NSLog(@"%@",jfsFileDictionary);
}

#pragma mark - Decrypt file content
- (NSData*)getDataFromEncryptedBytes:(NSData*)encryptedData privateKeyData:(NSData*)privateKeyData
{
    [self saveRSAKeyWithKeyClass:kSecAttrKeyClassPrivate keyData:privateKeyData keyTagString:kPrivateKeyIdentifier overwrite:YES];
    SecKeyRef privateKey = [self loadRSAKeyWithKeyClass:kSecAttrKeyClassPrivate keyTagString:kPrivateKeyIdentifier];
    
    NSAssert(encryptedData.length >= 352, @"CA raw file size is wrong");
    NSAssert(0 == (encryptedData.length %16), @"CA raw file size mod 16 is wrong");
    NSData* encryptedDsk = [encryptedData subdataWithRange:NSMakeRange(0,256)];

    OSStatus status             = noErr;
    size_t   plainBufferSize    = SecKeyGetBlockSize(privateKey);
    uint8_t* plainBuffer        = malloc(plainBufferSize);
    uint8_t* cipherBuffer1      = (uint8_t*)[encryptedDsk bytes];
    size_t   cipherBufferSize1  = SecKeyGetBlockSize(privateKey);
    
    status = SecKeyDecrypt(privateKey,
                           kSecPaddingOAEP,
                           cipherBuffer1,
                           cipherBufferSize1,
                           plainBuffer,
                           &plainBufferSize);
    
    NSAssert(status == noErr, @"RSA decryption failed");
    
    NSData* decryptedDsk = [NSData dataWithBytes:plainBuffer length:plainBufferSize];
    NSAssert(decryptedDsk.length == kDataSymmetricKeyLength, @"Decrypted DSK size is wrong");
    
    NSData* div = [encryptedData subdataWithRange:NSMakeRange(kDataSymmetricKeyLengthCA,kDataInitializationVectorLength)];
    NSData* fileData = [encryptedData subdataWithRange:NSMakeRange((kDataSymmetricKeyLengthCA+kDataInitializationVectorLength),encryptedData.length-(kDataSymmetricKeyLengthCA+kDataInitializationVectorLength))];
    
    NSError* error;
    NSData* jfsDataWithHash = [self decryptAes256UsingKey:decryptedDsk
                                     initializationVector:div
                                                     data:fileData
                                                    error:&error];
    NSAssert(error == nil, @"An error occured");
    
    NSData* jfsDataHash __attribute__((unused)) = [jfsDataWithHash subdataWithRange:NSMakeRange(0, kHashLength)];
    NSData* jfsData = [jfsDataWithHash subdataWithRange:NSMakeRange(kHashLength, jfsDataWithHash.length - kHashLength)];
    NSData* newJfsDataHash __attribute__((unused)) = [self hashSha512:jfsData];
    
    NSAssert(jfsData != nil, @"JFS data cannot be nil");
    NSAssert([newJfsDataHash isEqualToData:jfsDataHash], @"Hash doesn't match");
    
    return jfsData;
}

#pragma mark - Certificate Pinning
- (NSURLSessionAuthChallengeDisposition)authenticateURLChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust])
    {
#if DEBUG
        return NSURLSessionAuthChallengePerformDefaultHandling;
#else
        do
        {
            // in the future will be an array of certs to compare with... one for now
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            if (nil == serverTrust)
            {
                break; /* failed */
            }
            
            OSStatus status = SecTrustEvaluate(serverTrust, NULL);
            if (errSecSuccess != status)
            {
                break; /* failed */
            }
            
            SecCertificateRef serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
            if (nil == serverCertificate)
            {
                break; /* failed */
            }
            
            CFDataRef serverCertificateData = SecCertificateCopyData(serverCertificate);
            if (nil == serverCertificateData)
            {
                break; /* failed */
            }
            
            const UInt8* const data = CFDataGetBytePtr(serverCertificateData);
            const CFIndex size = CFDataGetLength(serverCertificateData);
            NSData* remoteCert = [NSData dataWithBytes:data length:(NSUInteger)size];
            if (remoteCert == nil || [remoteCert isEqual:[NSNull class]])
            {
                break; /* failed */
            }
            
            if(![self isRemoteCertIsEqualToAnyLocalCert:self.localCerts remoteCert:remoteCert])
            {
                break; /* failed */
            }
            
            // The only good exit point
            return NSURLSessionAuthChallengeUseCredential;
        } while(0);
        
        // Bad dog
        return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
#endif
    }
    
    return NSURLSessionAuthChallengePerformDefaultHandling;
}

- (BOOL)isRemoteCertIsEqualToAnyLocalCert:(nonnull NSArray<NSData*> *)localCerts remoteCert:(nonnull NSData*)remoteCert
{
    for (NSData* localCert in localCerts)
    {
        if([remoteCert isEqualToData:localCert])
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)storeRsaPrivateKeyToKeyChain:(NSString*)privateKeyHex
{
    NSData* privateKeyData = [privateKeyHex stringConvertToBytesWhereStringIsHex:YES];
    BOOL result = [self saveRSAKeyWithKeyClass:kSecAttrKeyClassPrivate keyData:privateKeyData keyTagString:kPrivateKeyIdentifier overwrite:YES];
    return result;
}

- (NSData*)rsaPrivateKeyDataGet
{
    NSData* keyData = [self loadRSAKeyDataWithKeyClass:kSecAttrKeyClassPrivate keyTagString:kPrivateKeyIdentifier];
    return keyData;
}

@end
