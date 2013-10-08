
/*!
 * Copyright (c) 2013,福建星网视易信息系统有限公司
 * All rights reserved.
 
 * @File:       RTSPPlayerViewController.h
 * @Abstract:   RTSPPlayer 视图控制器
 * @History:
 
 -2013-08-19 创建 by xuwf
 */

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>



@interface RTSPPlayerViewController : GLKViewController
- (id)init;
- (id)initWithContentURL:(NSString *)contentURL;

- (void)setContentURL:(NSString *)contentURL;

/* 必须在view呈现之后调用 */
- (void)play;

- (void)stop;

@end
