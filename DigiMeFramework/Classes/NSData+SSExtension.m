//
//  NSData+SSExtension.m
//  DigiMe
//
//  Created on 07/03/2017.
//  Copyright © 2017 digi.me. All rights reserved.
//

#import "NSData+SSExtension.h"

@implementation NSData (SSExtension)

- (BOOL)isBitSet:(NSInteger)bit
{
    if (bit < 0 || bit >= self.length * 8)
    {
        return NO;
    }
    
    NSInteger byte = self.length - (bit / 8) - 1;
    
    unsigned char* bitfield = (unsigned char*)self.bytes;
    return ( bitfield[byte] & (1 << (bit % 8))) == (1 << (bit % 8));
}

@end

@implementation NSMutableData (SSExtension)

- (void)setBit:(NSInteger)bit
{
    if (bit < 0 || bit >= self.length * 8)
    {
        return;
    }
    
    NSInteger byte = self.length - (bit/8) - 1;
    
    unsigned char* bitfield = (unsigned char*)self.bytes;
    bitfield[byte] |= (1 << (bit % 8));
}

@end
