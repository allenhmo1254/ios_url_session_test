//
//  DLDownLoader.m
//  Dreamer-ios-client
//
//  Created by Ant on 17/3/20.
//  Copyright © 2017年 Beijing Dreamer. All rights reserved.
//

#import "DLDownLoader.h"

#define kSizePerTime 1024*50
typedef void (^completionBlock)();

@interface DLDownLoader ()<NSURLSessionDataDelegate>

@property (nonatomic,strong)NSURL *url;          //文件资源地址
@property (nonatomic,strong)NSString *targetPath;//文件存放路径

@property(nonatomic,readwrite,retain)NSError *error;//请求出错

@property long long totalContentLength;            //文件总大小
@property long long totalReceivedContentLength;    //已下载大小

@property (nonatomic,strong)NSURLSession *session;   //注意一个session只能有一个请求任务
@property (nonatomic, strong)  NSURLSessionDataTask *dataTask; // datatask

@property(nonatomic,readwrite,copy)completionBlock completionBlock;


/**
 *  设置成功、失败回调block
 *
 *  @param success 成功回调block
 *  @param failure 失败回调block
 */
- (void)setCompletionBlockWithSuccess:(void (^)())success
                              failure:(void (^)(NSError *error))failure;

@end

@implementation DLDownLoader

+(DLDownLoader *)resumeManagerWithURL:(NSURL*)url
                           targetPath:(NSString*)targetPath
                              success:(void (^)())success
                              failure:(void (^)(NSError *error))failure
{
    
    DLDownLoader *downLoader = [[DLDownLoader alloc]init];
    
    downLoader.url = url;
    downLoader.targetPath = targetPath;
    [downLoader setCompletionBlockWithSuccess:success failure:failure];


    downLoader.totalContentLength =0;
    downLoader.totalReceivedContentLength =0;
    
    return downLoader;

}

/**
 *  设置成功、失败回调block
 *
 *  @param success 成功回调block
 *  @param failure 失败回调block
 */
- (void)setCompletionBlockWithSuccess:(void (^)())success
                              failure:(void (^)(NSError *error))failure{
    
    __weak typeof(self) weakSelf =self;
    self.completionBlock = ^ {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (weakSelf.error) {
                if (failure) {
                    failure(weakSelf.error);
                }
            } else {
                if (success) {
                    success();
                }
            }
            
        });
    };
}


/**
 *  启动断点续传下载请求
 */
-(void)start
{
   
    self.totalReceivedContentLength = [self getLocalFileSize];
    
    [self.dataTask resume];
}

- (void)reStart
{
    [self.dataTask resume];
}

-(NSURLSession *)session
{
    if (_session == nil) {
        //3.创建会话对象,设置代理
        /*
         第一个参数:配置信息 [NSURLSessionConfiguration defaultSessionConfiguration]
         第二个参数:代理
         第三个参数:设置代理方法在哪个线程中调用
         */
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc]init]];
        //defaultSessionConfiguration
    }
    return _session;
}
-(NSURLSessionDataTask *)dataTask
{
    if (_dataTask == nil) {
        //1.url
        NSURL *url = _url;
        //2.创建请求对象
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        
        //3 设置请求头信息,告诉服务器请求那一部分数据
        NSString *range = [NSString stringWithFormat:@"bytes=%zd-%zd",self.totalReceivedContentLength, self.totalReceivedContentLength + kSizePerTime];
        [request setValue:range forHTTPHeaderField:@"Range"];
        
        //4.创建Task
        _dataTask = [self.session dataTaskWithRequest:request];
    }
    return _dataTask;
}


- (long long)getLocalFileSize
{
    NSDictionary *dict=[[NSFileManager defaultManager]attributesOfItemAtPath:_targetPath error:NULL];
    return [dict[NSFileSize] longLongValue];
}

#pragma mark -- delegate

-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *rsp = (NSHTTPURLResponse *)response;
    
    if (rsp.statusCode ==200) {
        
        self.totalContentLength = dataTask.countOfBytesExpectedToReceive;
        
    }else if (rsp.statusCode ==206){
        
        NSString *contentRange = [rsp.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 4) {
                self.totalContentLength = [[bytes objectAtIndex:3]longLongValue];
            }
        }
    }else if (rsp.statusCode ==416){
        
        NSString *contentRange = [rsp.allHeaderFields valueForKey:@"Content-Range"];
        if ([contentRange hasPrefix:@"bytes"]) {
            NSArray *bytes = [contentRange componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -/"]];
            if ([bytes count] == 3) {
                
                self.totalContentLength = [[bytes objectAtIndex:2]longLongValue];
                
                
            }
        }
        return;
    }else{
        
        //其他情况还没发现
        return;
    }


    /*
     NSURLSessionResponseCancel = 0,取消 默认
     NSURLSessionResponseAllow = 1, 接收
     NSURLSessionResponseBecomeDownload = 2, 变成下载任务
     NSURLSessionResponseBecomeStream        变成流
     */

    
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session
         dataTask:(NSURLSessionDataTask *)dataTask
   didReceiveData:(NSData *)data
{
    self.totalReceivedContentLength += data.length;
    
    //写入文件
    [self appendData:data];
}

-(void)URLSession:(NSURLSession *)session
             task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    if (error == nil &&self.error ==nil) { // 成功回调
        
        if (self.totalReceivedContentLength == self.totalContentLength) { // 全部下载完成
            
            self.completionBlock();
            
        }
        
        self.dataTask = nil;
        
        [self.session invalidateAndCancel];
        self.session = nil;
        
        
        if (self.totalReceivedContentLength < self.totalContentLength)
        {
            
            [self reStart];
            
        }
        
    }else if (error !=nil){
        
        if (error.code != -999) {
            
            self.error = error;
            self.completionBlock();
        }
        
    }else if (self.error !=nil){
        
        self.completionBlock();
    }

}

- (void)appendData:(NSData *)data
{
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:_targetPath];
    if (!fh) {
      [data writeToFile:_targetPath atomically:YES];
        
    }else{
        [fh seekToEndOfFile];
        [fh writeData:data];
        [fh closeFile];
    }

}

@end
