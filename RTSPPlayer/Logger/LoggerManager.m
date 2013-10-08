//
//  LoggerManager.m
//  logger
//
//  Created by xuwf on 13-6-18.
//  Copyright (c) 2013年 xuwf. All rights reserved.
//

#import "LoggerManager.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"
#import "MemoryLogger.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation LoggerManager

/* 异常退出捕获 */
void uncaughtExceptionHandler(NSException *exception) {
    NSArray *arr = [exception callStackSymbols];
    NSString *reason = [exception reason];
    NSString *name = [exception name];
    
    DDLogCInfo(@"################%@###################\n%@\n%@", name, reason, [arr componentsJoinedByString:@"\r\n"]);
    DDLogCInfo(@"######################################");/* 需要打印再调用DDLogCInfo一次，才能将crash 内容打印出来 */

}

- (id)init {
    self = [super init];
    if (self) {        
        /* 设置异常捕获 */
        NSSetUncaughtExceptionHandler (&uncaughtExceptionHandler);
        
        /* 系统Control */
        [DDLog addLogger:[DDASLLogger sharedInstance]];
        
        /* 控制台打印 */
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
        
        /* 文件输出,位于Cache/Logs/下 */
        DDFileLogger* fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        [DDLog addLogger:fileLogger];
        
        /* 内存打印 */
        [SINGLETON_CALL(MemoryLogger) start];
    }
    return self;
}

+ (void)logger {
    static LoggerManager* manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[LoggerManager alloc] init];
    });
    return;
}
@end
