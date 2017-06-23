//
//  ViewController.m
//  URLSessionTest
//
//  Created by 马千里 on 15/10/10.
//  Copyright © 2015年 MQL. All rights reserved.
//

#import "ViewController.h"
#import "JZJDownloadManager.h"

@interface ViewController ()
{
    NSURLSessionDataTask *downTask;
}

@property (nonatomic, weak) IBOutlet UIImageView *imageWithBlock;
@property (nonatomic, strong) NSString *targetPath;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *lab;
@property (nonatomic, weak) IBOutlet UIButton *deleteBtn;


/**
 *  简单请求
 *
 *  @param sender
 */
-(IBAction)simpleRequest:(id)sender;

/**
 *  取消请求
 *
 *  @param sender
 */
-(IBAction)cancelRequest:(id)sender;

/**
 *  删除文件
 *
 *  @param sender
 */
-(IBAction)deleteImage:(id)sender;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

/**
 *  简单请求
 *  @param sender
 */
-(IBAction)simpleRequest:(id)sender{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory=[paths objectAtIndex:0];//Documents目录
    self.targetPath = [documentsDirectory stringByAppendingPathComponent:@"myPic"];
    
    NSURL *url = [NSURL URLWithString:@"http://p1.pichost.me/i/40/1639665.png"];
    
    NSURLSessionDataTask *task = [[JZJDownloadManager shareInstance] downloadWithURL:url targetPath:self.targetPath success:^{
        self.imageWithBlock.image = [UIImage imageWithContentsOfFile:self.targetPath];
        self.deleteBtn.hidden = NO;
    } failure:^(NSError *error) {
        NSLog(@"error = %@",error.description);
    } progress:^(int64_t totalReceivedContentLength, int64_t totalContentLength) {
        float percent = 1.0 * totalReceivedContentLength / totalContentLength;
        NSString *strPersent = [[NSString alloc]initWithFormat:@"%.f", percent *100];
        self.progressView.progress = percent;
        self.lab.text = [NSString stringWithFormat:@"已下载%@%%", strPersent];
    }];
    [task resume];
    
    self.targetPath = [documentsDirectory stringByAppendingPathComponent:@"myPic1"];
    
    downTask = [[JZJDownloadManager shareInstance] downloadWithURL:url targetPath:self.targetPath success:^{
        self.imageWithBlock.image = [UIImage imageWithContentsOfFile:self.targetPath];
        self.deleteBtn.hidden = NO;
    } failure:^(NSError *error) {
        NSLog(@"error = %@",error.description);
    } progress:^(int64_t totalReceivedContentLength, int64_t totalContentLength) {
        float percent = 1.0 * totalReceivedContentLength / totalContentLength;
        NSString *strPersent = [[NSString alloc]initWithFormat:@"%.f", percent *100];
        self.progressView.progress = percent;
        self.lab.text = [NSString stringWithFormat:@"已下载%@%%", strPersent];
    }];
    [downTask resume];
    
    NSLog(@"bbbbbbbbbbbbbbb");
}

/**
 *  取消请求
 *  @param sender
 */
-(IBAction)cancelRequest:(id)sender{
    
    [[JZJDownloadManager shareInstance] cancelWithTask:downTask];
}

/**
 *  删除文件
 *
 *  @param sender
 */
-(IBAction)deleteImage:(id)sender{
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    [manager removeItemAtPath:self.targetPath error:&error];
    
    if (error == nil) {
        
        self.imageWithBlock.image = [UIImage imageWithContentsOfFile:self.targetPath];
        self.progressView.progress = 0;
        self.lab.text = nil;
        
        self.deleteBtn.hidden = YES;
    }

}


@end
