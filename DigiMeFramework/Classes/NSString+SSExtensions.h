//
//  NSString+SSExtensions.h
//  DigiMe
//
//  Created on 24/03/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (SSExtensions)

/**
 * Tests whether the specified string is nil, empty or new line.
 *
 * @param string The string to test.
 *
 * @return True if the string is nil, empty or new line, false otherwise.
 */
+ (BOOL)isStringNilEmptyOrNewLine:(NSString *)string;

/**
 Tests whether the string contains only whitespace.

 @return YES if the string contains only whitespace, NO otherwise.
 */
- (BOOL)isWhitespace;

- (NSString *)appendStringWithAnotherString:(NSString *)string separator:(NSString *)separator;
- (NSString *)stringByStrippingHTML;
- (NSInteger)getMajorRevisionFromString;
- (NSInteger)getMinorRevisionFromString;
- (NSString *)urlencode;

- (NSString *)urlEncodedString;
- (NSString *)urlDecodedString;
- (NSString *)stringFromNSDataDescription;
- (NSMutableData *)stringConvertToBytesWhereStringIsHex:(BOOL)isHexString;
- (NSData*)convertStringToBytesFromHexString;
- (BOOL)isBase64;
@end
