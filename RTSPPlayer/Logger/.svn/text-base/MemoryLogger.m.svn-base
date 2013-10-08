
/*!
 * Copyright (c) 2013,福建星网视易信息系统有限公司
 * All rights reserved.
 
 * @File:       MemoryLogger.m
 * @Abstract:   打印内存信息
 * @History:
 
 -2013-06-09 创建 by xuwf
 */

#include <malloc/malloc.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#import "MemoryLogger.h"

#define MEMORY_LOGGER_TIME_INTERVAL (10.0f)

@interface MemoryLogger () {
    NSTimer* _timer;
}

@end

@implementation MemoryLogger

SINGLETON_DEF(MemoryLogger);

- (void)start {
    SARELEASE_TIMER(_timer);
    _timer = [NSTimer scheduledTimerWithTimeInterval:MEMORY_LOGGER_TIME_INTERVAL target:self selector:@selector(showMemoryInfo) userInfo:nil repeats:YES];
}


- (natural_t)getFreeMemory {
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;
    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);
    vm_statistics_data_t vm_stat;
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        NSLog(@"Failed to fetch vm statistics");
        return 0;
    }
    
    /* Stats in bytes */
    natural_t mem_free = vm_stat.free_count * pagesize;
    return mem_free;
}

- (NSString*)stringOfSize:(long long)size
{
    int i = 0;
    double tempLength;
    static NSString *formatString[5] = {@"%.0lfB", @"%.1lfKB", @"%.1lfMB", @"%.2lfGB", @"%.2lfTB"};
    
    tempLength = size;
    while (tempLength>=1024 && i<4) {
        tempLength /= 1024.0;
        i++;
    }
    
    return [NSString stringWithFormat:formatString[i], tempLength];
}

- (void)showMemoryInfo {
    struct mstats st;
    st = mstats();
    
    DDLogInfo(@"[MEMORY====>Total:%@, Living:%@, Freed:%@, Available:%@]", [self stringOfSize:st.bytes_total], [self stringOfSize:st.bytes_used], [self stringOfSize:st.bytes_free], [self stringOfSize:[self getFreeMemory]]);
}

- (void)stop {
    SARELEASE_TIMER(_timer);
}

@end
