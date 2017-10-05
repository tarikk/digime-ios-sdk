//
//  NSString+SSExtensions.m
//  DigiMe
//
//  Created on 24/03/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "NSString+SSExtensions.h"

@implementation NSString (SSExtensions)

+ (BOOL)isStringNilEmptyOrNewLine:(NSString *)string
{
    return ((NSNull *)string == [NSNull null])
    || (string == nil)
    || ([string length] == 0)
    || ([string isNewline]);
}

- (BOOL)isWhitespace
{
    NSCharacterSet* cs = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
    return [self rangeOfCharacterFromSet:cs].length == 0;
}

- (BOOL)isNewline
{
    NSCharacterSet *cs = [[NSCharacterSet newlineCharacterSet] invertedSet];
    return [self rangeOfCharacterFromSet:cs].length == 0;
}

- (NSString*)appendStringWithAnotherString:(NSString *)string separator:(NSString*)separator
{
    if ([self length] != 0)
        return [NSString stringWithFormat:@"%@%@ %@", self, separator, string];
    else
        return string;
}

-(NSString *) stringByStrippingHTML {
    NSRange r;
    NSString *s = [self copy];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}

-(NSInteger)getMajorRevisionFromString
{
    NSString* stringFileRevisionNumber = [self copy];
    
    if ((!stringFileRevisionNumber) || (stringFileRevisionNumber.length < 1))
        return 0;
    
    NSArray* arrayFileRevisionNumber = [stringFileRevisionNumber componentsSeparatedByString:@"."];
    
    if ((arrayFileRevisionNumber) && (arrayFileRevisionNumber.count >= 1))
        return [arrayFileRevisionNumber[0] integerValue];
    else
        return 0;
}

-(NSInteger)getMinorRevisionFromString
{
    NSString* stringFileRevisionNumber = [self copy];
    
    NSLog(@"%lu",(unsigned long)stringFileRevisionNumber.length);
    
    if ((!stringFileRevisionNumber) || (stringFileRevisionNumber.length < 3))
        return 0;
    
    stringFileRevisionNumber = [stringFileRevisionNumber stringByReplacingOccurrencesOfString:@"," withString:@"."];
    NSArray* arrayFileRevisionNumber = [stringFileRevisionNumber componentsSeparatedByString:@"."];
    
    if (arrayFileRevisionNumber)
        return [arrayFileRevisionNumber[1] integerValue];
    else
        return 0;
}

- (NSString *)urlencode {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    unsigned long sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

- (NSString *)urlDecodedString
{
    return [self stringByRemovingPercentEncoding];
}

- (NSString *)urlEncodedString
{
    NSCharacterSet* customCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"!*'\"();:@&=+$,/?%#[]% "] invertedSet];
    
    return [self stringByAddingPercentEncodingWithAllowedCharacters:customCharacterSet];
}

- (NSString *)stringFromNSDataDescription
{
    NSString *string;
    string = [self stringByReplacingOccurrencesOfString:@" " withString:@""];
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    return string;
}

- (NSMutableData *)stringConvertToBytesWhereStringIsHex:(BOOL)isHexString
{
    NSMutableData* data = nil;
    
    if(isHexString)
        data = [self convertStringToBytesFromHexString].mutableCopy;
    else
        data = [self dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
    
    NSAssert(data != nil, @"Output data cannot be nil");
    
    return data;
}

- (NSData*)convertStringToBytesFromHexString
{
    NSString* cleanedString = [self stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData* commandToSend = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i=0; i < [cleanedString length]/2; i++) {
        byte_chars[0] = [cleanedString characterAtIndex:i*2];
        byte_chars[1] = [cleanedString characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [commandToSend appendBytes:&whole_byte length:1];
    }
    
    return commandToSend.copy;
}

-(BOOL)isBase64
{
    NSString * input = [[self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    if ([input length] % 4 == 0) {
        static NSCharacterSet *invertedBase64CharacterSet = nil;
        if (invertedBase64CharacterSet == nil) {
            invertedBase64CharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="]invertedSet];
        }
        return [input rangeOfCharacterFromSet:invertedBase64CharacterSet options:NSLiteralSearch].location == NSNotFound;
    }
    return NO;
}

@end
