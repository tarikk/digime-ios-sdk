//
//  DMERunLoopOperation.h
//  DigiMe
//
//  Created on 13/05/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
/**
 * An operation with a run loop.  This allows asynchronous work to be carried on a background thread.
 */
@interface DMERunLoopOperation : NSOperation

/**
 * The block to execute from the operation object. The block should take no parameters and have no return value.
 * @note Within the block, be sure to call @c finishDoingWork when the work is complete, otherwise operation will never complete
 */
@property (nonatomic, copy, nullable) void (^workBlock)(void);

/**
 * Notifies the operation that all work has been completed and can clean itself up.
 * Must be called from within workBlock.
 */
- (void)finishDoingWork;

@end
