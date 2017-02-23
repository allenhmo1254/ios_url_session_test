//
//  JZJUploadManager.h
//  URLSessionTest
//
//  Created by 景中杰 on 17/2/23.
//  Copyright © 2017年 MQL. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^JZUploadCompletionHandler)(void);
typedef void (^JZUploadFailureHandler)(NSError *error);
typedef void (^JZUploadProgressHandler)(int64_t totalReceivedContentLength, int64_t totalContentLength);

@interface JZJUploadManager : NSObject

+(instancetype)shareInstance;

-(NSURLSessionDataTask *)downloadWithURL:(NSURL *)url
                              targetPath:(NSString *)targetPath
                                 success:(JZUploadCompletionHandler)success
                                 failure:(JZUploadFailureHandler)failure
                                progress:(JZUploadProgressHandler)progress;

- (void)cancel;

- (void)cancelWithTask:(NSURLSessionTask *)task;

@end
