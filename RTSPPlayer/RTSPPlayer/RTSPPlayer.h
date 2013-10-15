/*!
   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:
   
   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.
   
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.
 
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
