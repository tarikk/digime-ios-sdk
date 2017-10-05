//
//  DMEArgonServiceController.m
//  digi.me
//
//  Created by digi.me on 17/10/2016.
//  Copyright © 2016 digi.me. All rights reserved.
//

#import "DMEArgonServiceController.h"
#import "DMEUtilities.h"
#import "DMERunLoopOperation.h"
#import "DMESecurityController.h"
#import "NSError+Helper.h"
#import "NSString+SSExtensions.h"

static const NSString* kDigimeConsentAccessVersion              = @"1.0.0";
static const NSString* kDigimeConsentAccessPathSessionKeyCreate = @"v1/permission-access/session";
static const NSString* kDigimeConsentAccessPathDataGet          = @"v1/permission-access/query";
static const NSString* kDownloadQueue                           = @"kDownloadQueue";
static const NSInteger kMaxConcurrentOperationCount             = 10;

@interface DMEArgonServiceController() <NSURLSessionDelegate>

@property (nonatomic, copy, nullable) void (^returnFinalDataCompletionHandler)(NSArray<NSString *>* _Nullable fileNames, NSDictionary* _Nullable filesWithContent, NSError* _Nullable error);

@property (nonatomic, strong) NSString*             sessionKey;
@property (nonatomic, strong) NSArray*              fileList;
@property (nonatomic, strong) NSMutableDictionary*  filesWithContent;
@property (nonatomic, strong) NSOperationQueue*     downloadQueue;
@property (nonatomic, strong) NSLock*               filesWithContentLock;

@end

@implementation DMEArgonServiceController

#pragma mark - Lifecycle
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
    _isDownloadingData  = NO;
    _sessionKey         = nil;
    _fileList           = nil;
    _filesWithContent   = nil;
    
    self.downloadQueue = [[NSOperationQueue alloc] init];
    self.downloadQueue.maxConcurrentOperationCount = kMaxConcurrentOperationCount;
    
    [self.downloadQueue addObserver:self
                         forKeyPath:NSStringFromSelector(@selector(operationCount))
                            options:NSKeyValueObservingOptionNew
                            context:&kDownloadQueue];
    
}

- (void)dealloc
{
    @try {
        [self.downloadQueue removeObserver:self
                                forKeyPath:NSStringFromSelector(@selector(operationCount))
                                   context:&kDownloadQueue];
    }
    @catch (NSException * __unused exception) {}
    
    [self.downloadQueue cancelAllOperations];
}

- (void)cancelAllOperations
{
    [self.downloadQueue cancelAllOperations];
    
    self.downloadQueue = nil;
    self.isDownloadingData = NO;
    
    for (NSOperation* o in [[NSOperationQueue mainQueue] operations])
    {
        [o cancel];
    }
    
    [self initialize];
}

#pragma mark - CA Argon Key Request. Get New Session Key.
- (void)sessionKeyCreateWithAppID:(nonnull NSString*)appID
                   withContractID:(nonnull NSString*)contractID
                   withCompletion:(void(^)(NSString* _Nullable sessionKey, NSTimeInterval expiry, NSError* _Nullable error))completion
{
    [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Starting to retrive session key from digi.me API.",nil)];
    
    NSAssert(appID.length >= 5,  @"app ID cannot be shorter than 5");
    NSAssert(appID.length <= 16, @"app ID cannot be longer than 16");
    NSAssert(contractID.length >= 1, @"contract ID cannot be shorter than 1");
    NSAssert(contractID.length <= 64, @"contract ID cannot be longer than 64");
    
    NSString*                   host            = [self baseUrl];
    NSURLComponents*            components      = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@%@"
                                                                         , host
                                                                         , kDigimeConsentAccessPathSessionKeyCreate]];
    NSURL*                      url             = components.URL;
    NSURLSessionConfiguration*  configuration   = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPAdditionalHeaders         = @{ @"Content-Type" : @"application/json", @"Accept" : @"application/json"};
    NSURLSession*               session         = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    NSMutableURLRequest*        request         = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:360.0];
    NSDictionary*               keysData        = @{@"appId" : appID, @"contractId" : contractID};
    NSData*                     postData        = [NSJSONSerialization dataWithJSONObject:keysData options:0 error:nil];
    
    [request setHTTPBody:postData];
    [request setHTTPMethod:@"POST"];

    __weak __typeof(DMEArgonServiceController *)weakSelf = self;
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
         __strong __typeof(DMEArgonServiceController *)strongSelf = weakSelf;
        
        [strongSelf digimeFrameworkLogWithMessage:NSLocalizedString(@"Received response from digi.me API on get session key request.",nil)];
        
        if(error)
        {
            if(completion)
                completion(nil,0,error);
            
            [strongSelf cancelAllOperations];
            return;
        }
        NSError*            parsingError        = nil;
        NSDictionary*       responseDictionary  = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parsingError];
        NSHTTPURLResponse*  httpResponse        = (NSHTTPURLResponse *) response;
        
        if(parsingError)
        {
            if(strongSelf.returnFinalDataCompletionHandler)
                strongSelf.returnFinalDataCompletionHandler(nil,nil,parsingError);
            
            [strongSelf cancelAllOperations];
            return;
        }
        
        if (httpResponse && (httpResponse.statusCode == 202 || httpResponse.statusCode == 200) && responseDictionary)
        {
            NSString*       sessionKey          = responseDictionary[@"sessionKey"];
            NSTimeInterval  expiry              = [responseDictionary[@"expiry"] longLongValue];
            
            if (sessionKey)
            {
                strongSelf.sessionKey = sessionKey;
                
                [strongSelf digimeFrameworkLogWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Session Key request succeeded. Data received. Key: %@",nil),sessionKey]];
                
                if(completion)
                    completion(sessionKey,expiry,nil);
            }
            else
            {
                if(completion)
                    completion(nil,0,[[NSError alloc] errorForErrorCode:ErrorSessionCreateSessionKeyNotReceived]);
                
                [strongSelf cancelAllOperations];
            }
        }
        else if (httpResponse && httpResponse.statusCode == 403)
        {
            if(completion)
                completion(nil,0,[[NSError alloc] errorForErrorCode:ErrorSessionCreateAppIdRevoke]);
            
            [strongSelf cancelAllOperations];
        }
        else if (httpResponse && httpResponse.statusCode == 410)
        {
            if(completion)
                completion(nil,0,[[NSError alloc] errorForErrorCode:ErrorSessionCreateContractHasExpired]);
            
            [strongSelf cancelAllOperations];
        }
        else
        {            
            if(completion)
                completion(nil,0,[[NSError alloc] errorForErrorCode:ErrorSessionCreateBadResponse]);
            
            [strongSelf cancelAllOperations];
        }
    }];
    
    [dataTask resume];
}

- (BOOL)sessionKeyIsValid:(NSString*)sessionKey
{
    if(!sessionKey || !self.sessionKey)
        return NO;
    
    return [sessionKey isEqualToString:self.sessionKey];
}

#pragma mark - CA Argon Data Get Request. Downloading Files List
- (void)getDataWithCompletion:(void(^)(NSArray<NSString *>* _Nullable fileNames, NSDictionary* _Nullable filesWithContent, NSError* _Nullable error))completion
{
    self.returnFinalDataCompletionHandler = completion;
    NSDate* startDate = [NSDate date];
    [self digimeFrameworkLogWithMessage:NSLocalizedString(@"Connecting to digi.me API with Files List Get request...",nil)];
    NSString*                   host            = [self baseUrl];
    NSURLComponents*            components      = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@%@/%@"
                                                                         , host
                                                                         , kDigimeConsentAccessPathDataGet
                                                                         , self.sessionKey]];
    
    NSURL*                      url             = components.URL;
    NSURLSessionConfiguration*  configuration   = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.HTTPAdditionalHeaders         = @{ @"Content-Type" : @"application/json", @"Accept" : @"application/json"};
    NSURLSession*               session         = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    NSMutableURLRequest*        request         = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:360.0];

    [request setHTTPMethod:@"GET"];
    
    NSLog(@"GET list request: %@", request);
    __weak __typeof(DMEArgonServiceController *)weakSelf = self;
    
    NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        __strong __typeof(DMEArgonServiceController *)strongSelf = weakSelf;
        NSTimeInterval timePassed = [startDate timeIntervalSinceNow] * -1;
        
        NSInteger interval = timePassed;
        NSInteger ms = (fmod(timePassed, 1) * 1000);
        long seconds = interval % 60;
        long minutes = (interval / 60) % 60;
        long hours = (interval / 3600);
        
        [strongSelf digimeFrameworkLogWithMessage:[NSString stringWithFormat:@"Response time: %0.2ld:%0.2ld:%0.2ld,%0.3ld", hours, minutes, seconds, (long)ms]];
        
        if(error)
        {
            if(completion)
                completion(nil,nil,error);
            [strongSelf cancelAllOperations];
            return;
        }
        
        NSError*            parsingError        = nil;
        NSDictionary*       responseDictionary  = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parsingError];
        NSHTTPURLResponse*  httpResponse        = (NSHTTPURLResponse *)response;
        
        if(parsingError)
        {
            NSLog(@"File Data Get LIST Parsing error (%@)",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            if(strongSelf.returnFinalDataCompletionHandler)
                strongSelf.returnFinalDataCompletionHandler(nil,nil,parsingError);
            [strongSelf cancelAllOperations];
            return;
        }
        
        if (httpResponse && httpResponse.statusCode == 200 && responseDictionary)
        {
            NSArray<NSString *>* fileList = [responseDictionary objectForKey:@"fileList"];
            [strongSelf digimeFrameworkLogWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Number of JFS files to download is %ld",nil), (long)fileList.count]];
            
            if (fileList != nil)
            {
                strongSelf.fileList = fileList;
                
                NSOperation *finalOp = [NSBlockOperation blockOperationWithBlock:^{
                    
                    if(strongSelf.fileList.count == strongSelf.filesWithContent.count && strongSelf.returnFinalDataCompletionHandler)
                    {
                        strongSelf.isDownloadingData = NO;
                        strongSelf.returnFinalDataCompletionHandler(strongSelf.fileList,strongSelf.filesWithContent,nil);
                    }
                } ];
                
                for(NSString* fileName in fileList)
                {
                    NSOperation *downloadOperation = [strongSelf getFileContentDataWithFileNameOperation:fileName];
                    [finalOp addDependency:downloadOperation];
                    [strongSelf.downloadQueue addOperation:downloadOperation];
                }
                
                [strongSelf.downloadQueue addOperation:finalOp];
            }
            else
            {
                if(completion)
                    completion(nil,nil,[[NSError alloc] errorForErrorCode:ErrorDataGetFilesListDataIsNotCorrect]);
                [strongSelf cancelAllOperations];
            }
        }
        else
        {
            if(completion)
                completion(nil,nil,[[NSError alloc] errorForErrorCode:ErrorDataGetFilesListServerResponseWithError]);
            [strongSelf cancelAllOperations];
        }
    }];
    
    [dataTask resume];
}

#pragma mark - CA Argon Data Get Request. Downloading File
- (NSOperation *)getFileContentDataWithFileNameOperation:(NSString*)fileName
{
    self.isDownloadingData = YES;
    
        DMERunLoopOperation*                    runLoopOperation = [DMERunLoopOperation new];
        __weak __typeof(DMERunLoopOperation *)  weakOperation    = runLoopOperation;
        
        runLoopOperation.workBlock = ^{
                        
            NSAssert(self.sessionKey != nil, @"Session key param cannot be nil");
            NSAssert(self.sessionKey.length == 32, @"Session key param cannot be other than 32 bytes");
            NSAssert(fileName != nil, @"File Name param cannot be nil");
            
            NSString*                   host            = [self baseUrl];
            NSURLComponents*            components      = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@%@/%@/%@"
                                                                                            , host
                                                                                            , kDigimeConsentAccessPathDataGet
                                                                                            , self.sessionKey
                                                                                            , fileName]];
            
            NSURL*                      url             = components.URL;
            NSURLSessionConfiguration*  configuration   = [NSURLSessionConfiguration defaultSessionConfiguration];
            configuration.HTTPAdditionalHeaders         = @{ @"Content-Type" : @"application/json", @"Accept" : @"application/json" };
            NSURLSession*               session         = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
            NSMutableURLRequest*        request         = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:360.0];

            [request setHTTPMethod:@"GET"];
            
            __weak __typeof(DMEArgonServiceController *)weakSelf = self;
            
            NSURLSessionDataTask* dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
                __strong __typeof(DMEArgonServiceController *)strongSelf = weakSelf;
                __strong __typeof(DMERunLoopOperation *)strongOperation = weakOperation;
                
                NSLog(@"Response on File Data Get request (%@)",fileName);
                
                if(error)
                {
                    if(strongSelf.returnFinalDataCompletionHandler)
                        strongSelf.returnFinalDataCompletionHandler(nil,nil,error);
                    
                    [strongSelf cancelAllOperations];
                    return;
                }
                
                NSError*            parsingError        = nil;
                NSDictionary*       responseDictionary  = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&parsingError];
                NSHTTPURLResponse*  httpResponse        = (NSHTTPURLResponse *)response;
                
                if(parsingError)
                {
                    NSLog(@"File Data Get Parsing error (%@)",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                    if(strongSelf.returnFinalDataCompletionHandler)
                        strongSelf.returnFinalDataCompletionHandler(nil,nil,parsingError);
                    
                    [strongSelf cancelAllOperations];
                    return;
                }
                
                if (httpResponse && httpResponse.statusCode == 200 && responseDictionary)
                {
                    if(!strongSelf.filesWithContent)
                    {
                        strongSelf.filesWithContent = [NSMutableDictionary new];
                        strongSelf.filesWithContentLock = [[NSLock alloc] init];
                    }
                    
                    NSString* base64Encoded = [responseDictionary objectForKey:@"fileContent"];
                    
                    if(base64Encoded && [base64Encoded isKindOfClass:[NSString class]] && [base64Encoded isBase64])
                    {
                        NSData* encryptedData = [[DMESecurityController sharedInstance] base64DataFromString:base64Encoded];
                        NSData* privateKeyData = [[DMESecurityController sharedInstance] rsaPrivateKeyDataGet];
                        NSData* decryptedData = [[DMESecurityController sharedInstance] getDataFromEncryptedBytes:encryptedData privateKeyData:privateKeyData];
                        NSAssert(decryptedData != nil, @"Decrypted data is nil");
                        
                        if (decryptedData)
                        {
                            NSDictionary* fileContent = [NSJSONSerialization JSONObjectWithData:decryptedData options:kNilOptions error:&parsingError];
                            NSAssert(fileContent != nil, @"File content data is nil");
                        
                            [strongSelf.filesWithContentLock lock];
                            [strongSelf.filesWithContent setObject:fileContent forKey:fileName];
                            [strongSelf progressDidChanged];
                            [strongSelf.filesWithContentLock unlock];
                        } 
                    }
                    else if([[responseDictionary objectForKey:@"fileContent"] isKindOfClass:[NSArray class]])
                    {
                        NSArray* fileContent = [responseDictionary objectForKey:@"fileContent"];
                        NSAssert(fileContent != nil, @"File content data is nil");
                        [strongSelf.filesWithContentLock lock];
                        [strongSelf.filesWithContent setObject:fileContent forKey:fileName];
                        [strongSelf progressDidChanged];
                        [strongSelf.filesWithContentLock unlock];
                    }
                    else
                    {
                        if(strongSelf.returnFinalDataCompletionHandler)
                            strongSelf.returnFinalDataCompletionHandler(nil,nil,[[NSError alloc] errorForErrorCode:ErrorDataGetFileDataDataIsNotCorrect]);
                        [strongSelf cancelAllOperations];
                    }
                }
                else if(httpResponse && httpResponse.statusCode == 404)
                {
                    NSLog(@"Received response. File is not ready. Requesting one more time. (%@)",fileName,nil);

                    NSOperation *finalOp = [NSBlockOperation blockOperationWithBlock:^{
                        
                        if(strongSelf.fileList.count == strongSelf.filesWithContent.count && strongSelf.returnFinalDataCompletionHandler)
                        {
                            strongSelf.isDownloadingData = NO;
                            strongSelf.returnFinalDataCompletionHandler(strongSelf.fileList,strongSelf.filesWithContent,nil);
                        }
                    } ];
                    
                    NSOperation *downloadOperation = [strongSelf getFileContentDataWithFileNameOperation:fileName];
                    [finalOp addDependency:downloadOperation];
                    [strongSelf.downloadQueue addOperation:downloadOperation];
                }
                else
                {
                    if(strongSelf.returnFinalDataCompletionHandler)
                        strongSelf.returnFinalDataCompletionHandler(nil,nil,[[NSError alloc] errorForErrorCode:ErrorDataGetFileDataServerResponseWithError]);
                    [strongSelf cancelAllOperations];
                }
                
                [strongOperation finishDoingWork];
            }];
            
            [dataTask resume];
            
        };
        
    return runLoopOperation;
    
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSURLSessionAuthChallengeDisposition challengeDisposition = NSURLSessionAuthChallengePerformDefaultHandling;
    if ([[[challenge protectionSpace] host] isEqualToString:[NSURL URLWithString:[self baseUrl]].host])
    {
        challengeDisposition = [[DMESecurityController sharedInstance] authenticateURLChallenge:challenge];
    }
    
    completionHandler(challengeDisposition, nil);
}

-(NSString*)baseUrl
{
    static NSString *argonURL;
    if (argonURL == nil)
    {
        NSString *domain = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"ArgonDomain"];
        if (!domain)
        {
            domain = @"digi.me";
        }
        argonURL = [NSString stringWithFormat:@"https://api.%@/", domain];
    }
    
    return argonURL;
}

#pragma mark - digi.me client framwork delegate methods
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

- (void)progressDidChanged
{
    float progress = (float)self.filesWithContent.count / self.fileList.count;
    
    if(progress < 0.0f)
        progress = 0.0f;
    
    if(progress > 1.0f)
        progress = 1.0f;
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(digimeFrameworkJsonFilesDownloadProgress:)])
    {
        [self.delegate digimeFrameworkJsonFilesDownloadProgress:progress];
    }
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == &kDownloadQueue && [keyPath isEqualToString:NSStringFromSelector(@selector(operationCount))])
    {
        NSNumber *operationCount = change[NSKeyValueChangeNewKey];
        if (operationCount.integerValue == 0 && self.fileList.count == self.filesWithContent.count)
        {
            if(self.fileList.count == self.filesWithContent.count && self.returnFinalDataCompletionHandler)
            {
                self.isDownloadingData = NO;
                [self digimeFrameworkDidChangeOperationState:StateDataRequestReceived];
                self.returnFinalDataCompletionHandler(self.fileList,self.filesWithContent,nil);
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end
