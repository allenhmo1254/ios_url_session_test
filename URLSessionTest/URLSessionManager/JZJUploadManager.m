//
//  JZJUploadManager.m
//  URLSessionTest
//
//  Created by 景中杰 on 17/2/23.
//  Copyright © 2017年 MQL. All rights reserved.
//

#import "JZJUploadManager.h"

#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug 1140.11
#else
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug NSFoundationVersionNumber_iOS_8_0
#endif

static dispatch_queue_t url_session_manager_creation_queue() {
    static dispatch_queue_t af_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_creation_queue = dispatch_queue_create("com.jingzhongjie.networking.download.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    
    return af_url_session_manager_creation_queue;
}

static void url_session_manager_create_task_safely(dispatch_block_t block) {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        dispatch_sync(url_session_manager_creation_queue(), block);
    } else {
        block();
    }
}

static NSString * const JZJDownloadManagerLockName = @"com.jingzhongjie.networking.download.manager.lock";

@interface JZJUploadHandler : NSObject

@property(nonatomic, strong)NSURLSessionDataTask *dataTask;
@property(nonatomic, copy)NSURL *url;           //文件资源地址
@property(nonatomic, copy)NSString *targetPath; //文件存放路径
@property(nonatomic, copy)JZUploadCompletionHandler successBlock;
@property(nonatomic, copy)JZUploadFailureHandler failureBlock;
@property(nonatomic, copy)JZUploadProgressHandler progressBlock;
@property(nonatomic, retain)NSError *error; //请求出错
@property(nonatomic, assign)int64_t totalContentLength;             //文件总大小
@property(nonatomic, assign)int64_t totalReceivedContentLength;     //已下载大小

-(instancetype)initWithTask:(NSURLSessionDataTask *)dataTask;

@end

@implementation JZJUploadHandler

-(instancetype)initWithTask:(NSURLSessionDataTask *)dataTask
{
    self = [super init];
    if (self) {
        _dataTask = dataTask;
    }
    return self;
}

@end

static JZJUploadManager *instance = nil;

@interface JZJUploadManager ()<NSURLSessionDataDelegate>
//<NSURLSessionDelegate, NSURLSessionTaskDelegate>

@property(nonatomic, strong)NSURLSession *session;
@property(nonatomic, strong)NSOperationQueue *operationQueue;
@property(nonatomic, strong)NSMutableDictionary *handlerDict;
@property(nonatomic, strong)NSLock *lock;

@end

@implementation JZJUploadManager

+(instancetype)shareInstance
{
    @synchronized (instance) {
        if (!instance) {
            instance = [[JZJUploadManager alloc] init];
        }
        return instance;
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self _initData];
    }
    return self;
}

-(NSURLSessionDataTask *)uploadWithURL:(NSURL *)url
                              fromFile:(NSString *)file
                               success:(JZUploadCompletionHandler)success
                               failure:(JZUploadFailureHandler)failure
                              progress:(JZUploadProgressHandler)progress
{
    long long downloadedBytes = [self _fileSizeForPath:file];
    
    NSURLRequest *request = [self _createRequestWithURL:url targetPath:file downloadedBytes:downloadedBytes];
    
    __block NSURLSessionDataTask *dataTask = nil;
    url_session_manager_create_task_safely(^{
        dataTask = [self.session uploadTaskWithRequest:request fromFile:[NSURL URLWithString:file]];
    });
    
    [self _addHandlerForDataTask:dataTask
                             url:url
                      targetPath:file
                         success:success
                         failure:failure
                        progress:progress
                 downloadedBytes:downloadedBytes];
    
    return dataTask;
}

- (void)cancel
{
    [self.session invalidateAndCancel];
    [self _removeAllHandlerDict];
}

- (void)cancelWithTask:(NSURLSessionTask *)task
{
    JZJUploadHandler *handler = [self _handlerForTask:task];
    
    if (handler) {
        [handler.dataTask cancel];
        [self _removeHandler:handler];
    }
}

#pragma mark - private

-(void)_initData
{
    _handlerDict = [[NSMutableDictionary alloc] init];
    
    self.lock = [[NSLock alloc] init];
    self.lock.name = JZJDownloadManagerLockName;
    
    [self _initSession];
}

-(void)_initSession
{
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = 6;
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:_operationQueue];
}

-(NSURLRequest *)_createRequestWithURL:(NSURL *)url
                            targetPath:(NSString *)targetPath
                       downloadedBytes:(long long)downloadedBytes
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:url];

    if (downloadedBytes > 0) {
        
        NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
        [request setValue:requestRange forHTTPHeaderField:@"Range"];
    }else{
        
        int fileDescriptor = open([targetPath UTF8String], O_CREAT | O_EXCL | O_RDWR, 0666);
        if (fileDescriptor > 0) {
            close(fileDescriptor);
        }
    }
    
    return request;
}

/**
 *  获取文件大小
 *  @param path 文件路径
 *  @return 文件大小
 *
 */
- (long long)_fileSizeForPath:(NSString *)path {
    
    long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager new]; // not thread safe
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    
    return fileSize;
}

-(void)_addHandlerForDataTask:(NSURLSessionDataTask *)dataTask
                          url:(NSURL *)url
                   targetPath:(NSString *)targetPath
                      success:(JZUploadCompletionHandler)success
                      failure:(JZUploadFailureHandler)failure
                     progress:(JZUploadProgressHandler)progress
              downloadedBytes:(int64_t)downloadedBytes
{
    JZJUploadHandler *handler = [[JZJUploadHandler alloc] initWithTask:dataTask];
    
    handler.url = url;
    handler.targetPath = targetPath;
    
    handler.successBlock = success;
    handler.failureBlock = failure;
    handler.progressBlock = progress;
    
    handler.totalReceivedContentLength = downloadedBytes;
    
    [self _addHandler:handler];
}

- (void)_addHandler:(JZJUploadHandler *)handler
{
    NSParameterAssert(handler);
    
    [self.lock lock];
    self.handlerDict[@(handler.dataTask.taskIdentifier)] = handler;
    [self.lock unlock];
}

-(JZJUploadHandler *)_handlerForTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    
    JZJUploadHandler *handler = nil;
    [self.lock lock];
    handler = self.handlerDict[@(task.taskIdentifier)];
    [self.lock unlock];
    
    return handler;
}

-(void)_removeHandler:(JZJUploadHandler *)handler
{
    [self.lock lock];
    [self.handlerDict removeObjectForKey:@(handler.dataTask.taskIdentifier)];
    [self.lock unlock];
}

-(void)_removeAllHandlerDict
{
    [self.lock lock];
    [self.handlerDict removeAllObjects];
    [self.lock unlock];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error
{
    if (error) {
        NSLog(@"didBecomeInvalidWithError = %@",error.description);
    }
}

#pragma mark -- NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error
{
    JZJUploadHandler *handler = [self _handlerForTask:task];
    
    if (error == nil && handler.error == nil)
    {
        handler.successBlock();
    }
    else if (error != nil)
    {
        if (error.code != -999) {
            
            handler.error = error;
            handler.failureBlock(handler.error);
        }
    }
    else if (handler.error != nil)
    {
        handler.successBlock();
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    JZJUploadHandler *handler = [self _handlerForTask:task];
    
    handler.totalReceivedContentLength = totalBytesSent;
    handler.totalContentLength = totalBytesExpectedToSend;
    
    handler.progressBlock(handler.totalReceivedContentLength, handler.totalContentLength);
}

#pragma mark -- NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    JZJUploadHandler *handler = [self _handlerForTask:dataTask];
    //根据status code的不同，做相应的处理
    NSHTTPURLResponse *response = (NSHTTPURLResponse*)dataTask.response;
    if (response.statusCode == 200) {
        
        handler.totalContentLength = dataTask.countOfBytesExpectedToReceive;
        
    }else if (response.statusCode == 206){
        
        NSString *contentRange = [response.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {
                handler.totalContentLength = [[bytes objectAtIndex:3] longLongValue];
            }
        }
    }else if (response.statusCode == 416){
        
        NSString *contentRange = [response.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 3) {
                
                handler.totalContentLength = [[bytes objectAtIndex:2] longLongValue];
                if (handler.totalReceivedContentLength == handler.totalContentLength) {
                    
                    //说明已下完
                    
                    //更新进度
                    handler.progressBlock(handler.totalReceivedContentLength, handler.totalContentLength);
                }else{
                    
                    //416 Requested Range Not Satisfiable
                    handler.error = [[NSError alloc]initWithDomain:[handler.url absoluteString] code:416 userInfo:response.allHeaderFields];
                }
            }
        }
        return;
    }else{
        
        //其他情况还没发现
        return;
    }
    
    NSLog(@"写入数据 = %@",handler.targetPath);
    //向文件追加数据
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:handler.targetPath];
    [fileHandle seekToEndOfFile]; //将节点跳到文件的末尾
    
    [fileHandle writeData:data];//追加写入数据
    [fileHandle closeFile];
    
    //更新进度
    handler.totalReceivedContentLength += data.length;
    handler.progressBlock(handler.totalReceivedContentLength, handler.totalContentLength);
}

@end
