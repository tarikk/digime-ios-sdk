//
//  NSData+SSExtension.h
//  DigiMe
//
//  Created on 07/03/2017.
//  Copyright © 2017 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (SSExtension)

- (BOOL)isBitSet:(NSInteger)bit;

@end

@interface NSMutableData (SSExtension)

- (void)setBit:(NSInteger)bit;

@end
