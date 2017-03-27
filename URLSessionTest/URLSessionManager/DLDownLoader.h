//
//  DLDownLoader.h
//  Dreamer-ios-client
//
//  Created by Ant on 17/3/20.
//  Copyright © 2017年 Beijing Dreamer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLDownLoader : NSObject

+(DLDownLoader *)resumeManagerWithURL:(NSURL*)url
                              targetPath:(NSString*)targetPath
                                 success:(void (^)())success
                                 failure:(void (^)(NSError *error))failure;


/**
 *  启动断点续传下载请求
 */
-(void)start;


@end
