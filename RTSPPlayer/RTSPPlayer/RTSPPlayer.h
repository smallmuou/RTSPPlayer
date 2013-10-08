
/*!
 * Copyright (c) 2013,福建星网视易信息系统有限公司
 * All rights reserved.
 
 * @File:       RTSPPlayer.h
 * @Abstract:   RTSP 流播放（整理https://github.com/hackacam/ios_rtsp_player,版权由原作者保留）
 * @History:
 
 -2013-08-19 创建 by xuwf
 */

#import <Foundation/Foundation.h>

#define RTSPError(fmt, ...) NSLog((@"ERROR:%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#ifdef DEBUG
#define RTSPLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define RTSPLog(...)
#endif

/*!
 @class         AVFrameData
 @superclass    NSObject
 @discussion    帧信息
 
 colorPlane0    颜色空间1数据
 colorPlane1    颜色空间2数据
 colorPlane2    颜色空间3数据
 
 这里对应yuv数据
 */
struct AVFrame;
@interface AVFrameData : NSObject
@property (nonatomic, strong) NSMutableData*    colorPlane0;
@property (nonatomic, strong) NSMutableData*    colorPlane1;
@property (nonatomic, strong) NSMutableData*    colorPlane2;
@property (nonatomic, strong) NSNumber*         lineSize0;
@property (nonatomic, strong) NSNumber*         lineSize1;
@property (nonatomic, strong) NSNumber*         lineSize2;
@property (nonatomic, strong) NSNumber*         width;
@property (nonatomic, strong) NSNumber*         height;
@property (nonatomic, strong) NSDate*           presentationTime;

/* convert frameData to UIImage */
- (UIImage* )image;

@end


extern NSString* RTSPErrorDomain;
extern NSString* RTSPErrorKey;
enum {
    RTSPErrorCodeAlreadyOpen = -400,
    RTSPErrorCodeOpenFile,
    RTSPErrorCodeStreamInfo,
    RTSPErrorCodeFindVideoStream,
    RTSPErrorCodeFindDecoder,
    RTSPErrorCodeOpenDecoder,
    RTSPErrorCodeAllocFrame,
};

enum {
    RTSPPlayerStateUnknown = 0,
    RTSPPlayerStateReady,
    RTSPPlayerStateLoading,
    RTSPPlayerStateLoadFailed,
    RTSPPlayerStatePlay,
    RTSPPlayerStateStop,
};
typedef NSInteger RTSPPlayerState;

@interface RTSPPlayer : NSObject {
    RTSPPlayerState _state;
}
@property (nonatomic, readonly) RTSPPlayerState state;

- (id)init;

/* NO return if open url fail. otherwise return YES */
- (BOOL)openURL:(NSString* )url error:(NSError** )error;

- (void)startWithCallbackBlock:(void (^)(AVFrameData *frame))frameCallbackBlock
               waitForConsumer:(BOOL)wait
            completionCallback:(void (^)())completion;

- (void)stop;

@end
