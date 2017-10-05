//
//  DMERunLoopOperation.m
//  DigiMe
//
//  Created on 13/05/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "DMERunLoopOperation.h"

@interface DMERunLoopOperation ()
{
@protected
    
    BOOL _isExecuting;
    BOOL _isFinished;
    
    // if you need run loops (e.g. for libraries with delegate callbacks that require a run loop)
    BOOL _requiresRunLoop;
    NSTimer *_keepAliveTimer;  // a NSRunLoop needs a source input or timer for its run method to do anything.
    BOOL _stopRunLoop;
}

@end

@implementation DMERunLoopOperation

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

- (BOOL)isAsynchronous
{
    return YES;
}

- (BOOL)isExecuting
{
    return _isExecuting;
}

- (BOOL)isFinished
{
    return _isFinished;
}

- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    _requiresRunLoop = YES;  // depends on your situation.
    if(_requiresRunLoop)
    {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        
        // run loops don't run if they don't have input sources or timers on them.  So we add a timer that we never intend to fire and remove him later.
        _keepAliveTimer = [NSTimer timerWithTimeInterval:CGFLOAT_MAX target:self selector:@selector(timeout:) userInfo:nil repeats:NO];
        [runLoop addTimer:_keepAliveTimer forMode:NSDefaultRunLoopMode];
        
        [self doWork];
        
        NSTimeInterval updateInterval = 0.1f;
        NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];
        while (!_stopRunLoop && [runLoop runMode: NSDefaultRunLoopMode beforeDate:loopUntil])
        {
            loopUntil = [NSDate dateWithTimeIntervalSinceNow:updateInterval];
        }
    }
    else
    {
        [self doWork];
    }
}

- (void)timeout:(NSTimer*)timer
{
    // this method should never get called.
    
    [self finishDoingWork];
}

- (void)doWork
{
    // do whatever stuff you need to do on a background thread.
    // Make network calls, asynchronous stuff, call other methods, etc.
    
    // and whenever the work is done, success or fail, whatever
    // be sure to call finishDoingWork.
    if (self.workBlock)
    {
        self.workBlock();
    }
    else
    {
        [self finishDoingWork];
    }
    
}

- (void)finishDoingWork
{
    if (_requiresRunLoop)
    {
        // this removes (presumably still the only) timer from the NSRunLoop
        [_keepAliveTimer invalidate];
        _keepAliveTimer = nil;
        
        // and this will kill the while loop in the start method
        _stopRunLoop = YES;
    }
    
    [self finish];
    
}
- (void)finish
{
    // generate the KVO necessary for the queue to remove him
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
}


@end
