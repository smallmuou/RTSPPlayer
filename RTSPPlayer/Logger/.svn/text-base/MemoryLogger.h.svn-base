
/*!
 * Copyright (c) 2013,福建星网视易信息系统有限公司
 * All rights reserved.
 
 * @File:       MemoryLogger.h
 * @Abstract:   打印内存信息
 * @History:
 
 -2013-06-09 创建 by xuwf
 */

#import <Foundation/Foundation.h>

/* 定时器销毁 */
#if __has_feature(objc_arc)
#define SARELEASE_TIMER(__timer) \
    do {\
        [__timer invalidate];\
        __timer = nil;\
    }while(0)
#else
#define SARELEASE_TIMER(__timer) \
    do {\
        [__timer invalidate];\
        [__timer release];\
        __timer = nil;\
    }while(0)
#endif


@interface MemoryLogger : NSObject
SINGLETON_AS(MemoryLogger);

- (void)start;
- (void)stop;

@end
