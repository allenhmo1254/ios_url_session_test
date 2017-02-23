//
//  JZJDownloadManager.h
//  URLSessionTest
//
//  Created by 景中杰 on 17/2/23.
//  Copyright © 2017年 MQL. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^JZDownloadCompletionHandler)(void);
typedef void (^JZDownloadFailureHandler)(NSError *error);
typedef void (^JZDownloadProgressHandler)(int64_t totalReceivedContentLength, int64_t totalContentLength);

@interface JZJDownloadManager : NSObject

+(instancetype)shareInstance;

-(NSURLSessionDataTask *)downloadWithURL:(NSURL *)url
                              targetPath:(NSString *)targetPath
                                 success:(JZDownloadCompletionHandler)success
                                 failure:(JZDownloadFailureHandler)failure
                                progress:(JZDownloadProgressHandler)progress;

- (void)cancel;

- (void)cancelWithTask:(NSURLSessionTask *)task;

@end
