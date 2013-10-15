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
 
 * @File:       RTSPPlayer.m
 * @Abstract:   RTSP 流播放
 * @History:
 
 -2013-08-19 创建 by xuwf
 */

#import "RTSPPlayer.h"
#import <FFmpegDecoder/libavcodec/avcodec.h>
#import <FFmpegDecoder/libavformat/avformat.h>
#import <FFmpegDecoder/libswscale/swscale.h>
#include <libkern/OSAtomic.h>

@interface AVFrameData() {
    NSMutableData*    _colorPlane0;
    NSMutableData*    _colorPlane1;
    NSMutableData*    _colorPlane2;
    NSNumber*         _lineSize0;
    NSNumber*         _lineSize1;
    NSNumber*         _lineSize2;
    NSNumber*         _width;
    NSNumber*         _height;
    NSDate*           _presentationTime;
}

- (id)initWithAVFrame:(AVFrame* )frame trimPadding:(BOOL)trim;
@end

@implementation AVFrameData
@synthesize colorPlane0         = _colorPlane0;
@synthesize colorPlane1         = _colorPlane1;
@synthesize colorPlane2         = _colorPlane2;
@synthesize lineSize0           = _lineSize0;
@synthesize lineSize1           = _lineSize1;
@synthesize lineSize2           = _lineSize2;
@synthesize width               = _width;
@synthesize height              = _height;
@synthesize presentationTime    = _presentationTime;

- (id)initWithAVFrame:(AVFrame* )frame trimPadding:(BOOL)trim {
    self = [super init];
    if (self) {
        if (trim){
            self.colorPlane0 = [[NSMutableData alloc] init];
            self.colorPlane1 = [[NSMutableData alloc] init];
            self.colorPlane2 = [[NSMutableData alloc] init];
            for (int i=0; i<frame->height; i++){
                [self.colorPlane0 appendBytes:(void*) (frame->data[0]+i*frame->linesize[0])
                                       length:frame->width];
            }
            for (int i=0; i<frame->height/2; i++){
                [self.colorPlane1 appendBytes:(void*) (frame->data[1]+i*frame->linesize[1])
                                       length:frame->width/2];
                [self.colorPlane2 appendBytes:(void*) (frame->data[2]+i*frame->linesize[2])
                                       length:frame->width/2];
            }
            self.lineSize0 = [[NSNumber alloc] initWithInt:frame->width];
            self.lineSize1 = [[NSNumber alloc] initWithInt:frame->width/2];
            self.lineSize2 = [[NSNumber alloc] initWithInt:frame->width/2];
        }else{
            self.colorPlane0 = [[NSMutableData alloc] initWithBytes:frame->data[0] length:frame->linesize[0]*frame->height];
            self.colorPlane1 = [[NSMutableData alloc] initWithBytes:frame->data[1] length:frame->linesize[1]*frame->height/2];
            self.colorPlane2 = [[NSMutableData alloc] initWithBytes:frame->data[2] length:frame->linesize[2]*frame->height/2];
            self.lineSize0 = [[NSNumber alloc] initWithInt:frame->linesize[0]];
            self.lineSize1 = [[NSNumber alloc] initWithInt:frame->linesize[1]];
            self.lineSize2 = [[NSNumber alloc] initWithInt:frame->linesize[2]];
        }
        self.width = [[NSNumber alloc] initWithInt:frame->width];
        self.height = [[NSNumber alloc] initWithInt:frame->height];
    }

    return self;
}

- (void)dealloc {
    self.colorPlane0 = nil;
    self.colorPlane1 = nil;
    self.colorPlane2 = nil;
    self.lineSize0 = nil;
    self.lineSize1 = nil;
    self.lineSize2 = nil;
    self.width = nil;
    self.height = nil;
    self.presentationTime = nil;
}

+ (UIImage* )imageFromAVPicture:(unsigned char **)pictureData
                       lineSize:(int* ) linesize
                          width:(int)width
                         height:(int)height
{
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pictureData[0], linesize[0]*height,kCFAllocatorNull);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGImageRef cgImage = CGImageCreate(width,
									   height,
									   8,
									   24,
									   linesize[0],
									   colorSpace,
									   bitmapInfo,
									   provider,
									   NULL,
									   NO,
									   kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	UIImage *image = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	CGDataProviderRelease(provider);
	CFRelease(data);
	
	return image;
}

- (UIImage* )image {
    // Allocate an AVFrame structure
    AVFrame* pFrameRGB = avcodec_alloc_frame();
    if(!pFrameRGB) return nil;
    
    // Determine required buffer size and allocate buffer
    int numBytes = avpicture_get_size(PIX_FMT_RGB24, self.width.intValue,
                                    self.height.intValue);
    uint8_t* buffer = (uint8_t *)av_malloc(numBytes*sizeof(uint8_t));
    
    struct SwsContext* sws_ctx =
    sws_getContext
    (
     self.width.intValue,
     self.height.intValue,
     PIX_FMT_YUV420P,
     self.width.intValue,
     self.height.intValue,
     PIX_FMT_RGB24,
     SWS_BILINEAR,
     NULL,
     NULL,
     NULL
     );
    
    // Assign appropriate parts of buffer to image planes in pFrameRGB
    // Note that pFrameRGB is an AVFrame, but AVFrame is a superset
    // of AVPicture
    avpicture_fill((AVPicture* )pFrameRGB, buffer, PIX_FMT_RGB24,
                   self.width.intValue, self.height.intValue);
    
    uint8_t *data[AV_NUM_DATA_POINTERS];
    int linesize[AV_NUM_DATA_POINTERS];
    for (int i = 0; i < AV_NUM_DATA_POINTERS; i++){
        data[i] = NULL;
        linesize[i] = 0;
    }
    data[0]=(uint8_t*)(self.colorPlane0.bytes);
    data[1]=(uint8_t*)(self.colorPlane1.bytes);
    data[2]=(uint8_t*)(self.colorPlane2.bytes);
    linesize[0]=self.lineSize0.intValue;
    linesize[1]=self.lineSize1.intValue;
    linesize[2]=self.lineSize2.intValue;
    
    sws_scale
    (
     sws_ctx,
     (uint8_t const* const* )data,
     linesize,
     0,
     self.width.intValue,
     pFrameRGB->data,
     pFrameRGB->linesize
     );
    UIImage* image = [AVFrameData imageFromAVPicture:pFrameRGB->data
                                     lineSize:pFrameRGB->linesize
                                        width:self.width.intValue
                                       height:self.height.intValue];
    
    // Free the RGB image
    av_free(buffer);
    av_free(pFrameRGB);
    
    return image;
}
@end

////////////////////////////////////////////////////////////////////////////////

NSString* RTSPErrorDomain = @"RTSPErrorDomain";
NSString* RTSPErrorKey = @"RTSPErrorKey";

static char* errorInfo[] = {
    "URL already opened",
    "Can't open rtsp stream",
    "Can't find stream information",
    "Can't find a video stream",
    "Unsupported codec",
    "Open codec error",
};

@interface RTSPPlayer() {
    AVFormatContext*        _formatCtx;
    AVCodecContext*         _codecCtx;
    AVCodec*                _codec;
    AVFrame*                _frame;
    AVPacket                _packet;
    AVDictionary*           _optionsDict;
    int                     _videoStream;
    dispatch_semaphore_t    _outputSinkQueueSema;
    dispatch_group_t        _decode_queue_group;
    volatile bool           _stopDecode;
    CFTimeInterval          _previousDecodedFrameTime;
}

@end

@implementation RTSPPlayer
@synthesize state = _state;
#define MIN_FRAME_INTERVAL 0.01

- (id)init {
    self = [super init];
    if (self) {
        // initialize all instance variables
        _state = RTSPPlayerStateUnknown;
        _formatCtx = NULL;
        _codecCtx = NULL;
        _codec = NULL;
        _frame = NULL;
        _optionsDict = NULL;
        
        // register av
        av_register_all();
        avformat_network_init();
        
        // setup output queue depth;
        _outputSinkQueueSema = dispatch_semaphore_create((long)(5));
        _decode_queue_group = dispatch_group_create();
        
        // set memory barrier
        OSMemoryBarrier();
        _stopDecode = false;
        
        _previousDecodedFrameTime = 0;
        _state = RTSPPlayerStateReady;
    }
    return self;
}

- (void)RTSPErrorWithCode:(NSInteger)code error:(NSError** )error {
    if (!error) return;
    
    NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:[NSString stringWithUTF8String:errorInfo[code - RTSPErrorCodeAlreadyOpen]], RTSPErrorKey, nil];
    
    *error = [NSError errorWithDomain:RTSPErrorDomain code:code userInfo:info];
}

- (BOOL)openURL:(NSString* )url error:(NSError** )error {
    NSInteger code;
    _state = RTSPPlayerStateLoading;
    
    if (_formatCtx || _codec){
        [self RTSPErrorWithCode:RTSPErrorCodeAlreadyOpen error:error];
        code = RTSPErrorCodeAlreadyOpen;
        goto _ERR;
    }
    
    // open video stream
    AVDictionary* serverOpt = NULL;
    av_dict_set(&serverOpt, "rtsp_transport", "tcp", 0);
    if (avformat_open_input(&_formatCtx, [url UTF8String], NULL, &serverOpt)!=0){
        code = RTSPErrorCodeOpenFile;
        goto _ERR;
    }
    
    // Retrieve stream information
    AVDictionary* options = NULL;
    av_dict_set(&options, "analyzeduration", "1000000", 0);
    if(avformat_find_stream_info(_formatCtx, &options)<0){
        code = RTSPErrorCodeStreamInfo;
        goto _ERR;
    }
    
    // Dump information about file onto standard error
    av_dump_format(_formatCtx, 0, [url UTF8String], 0);
    
    // Find the first video stream
    _videoStream = -1;
    for(int i = 0; i < _formatCtx->nb_streams; i++) {
        if(_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStream = i;
            break;
        }
    }
    
    if(_videoStream == -1){
        code = RTSPErrorCodeFindVideoStream;
        goto _ERR;
    }
    
    // Get a pointer to the codec context for the video stream
    _codecCtx = _formatCtx->streams[_videoStream]->codec;
    
    // Find the decoder for the video stream
    _codec = avcodec_find_decoder(_codecCtx->codec_id);
    if(!_codec) {
        code = RTSPErrorCodeFindDecoder;
        goto _ERR;
    }
    
    // Open codec
    if(avcodec_open2(_codecCtx, _codec, &_optionsDict)<0){
        code = RTSPErrorCodeOpenDecoder;
        goto _ERR;
    }
    
    // Allocate video frame
    _frame = avcodec_alloc_frame();
    if (!_frame){
        code = RTSPErrorCodeAllocFrame;
        goto _ERR;
    }
    
    return YES;
    
_ERR:
    _state = RTSPPlayerStateLoadFailed;
    [self deallocCodec];
    [self RTSPErrorWithCode:code error:error];
    return NO;
}

- (void)startWithCallbackBlock:(void (^)(AVFrameData *frame))frameCallbackBlock
               waitForConsumer:(BOOL)wait
            completionCallback:(void (^)())completion {
    
    OSMemoryBarrier();
    _stopDecode=false;
    
    _state = RTSPPlayerStatePlay;
    
    dispatch_queue_t decodeQueue = dispatch_queue_create("decodeQueue", NULL);
    dispatch_async(decodeQueue, ^{
        int frameFinished;
        OSMemoryBarrier();
        while (self->_stopDecode==false){
            @autoreleasepool {
                CFTimeInterval currentTime = CACurrentMediaTime();
                if ((currentTime-_previousDecodedFrameTime) > MIN_FRAME_INTERVAL &&
                    av_read_frame(_formatCtx, &_packet)>=0) {
                    _previousDecodedFrameTime = currentTime;
                    // Is this a packet from the video stream?
                    if(_packet.stream_index==_videoStream) {
                        // Decode video frame
                        avcodec_decode_video2(_codecCtx, _frame, &frameFinished,
                                              &_packet);
                        
                        // Did we get a video frame?
                        if(frameFinished) {
                            
                            // create a frame object and call the block;
                            AVFrameData *frameData = [[AVFrameData alloc] initWithAVFrame:_frame trimPadding:YES];
                            frameCallbackBlock(frameData);
                        }
                    }
                    
                    // Free the packet that was allocated by av_read_frame
                    av_free_packet(&_packet);
                }else{
                    usleep(1000);
                }
            }
        }
        if (completion) completion();
        _state = RTSPPlayerStateStop;
    });
}

- (void)stop {
    _stopDecode = true;
}

-(void)deallocCodec
{
    // Free the YUV frame
    if (_frame){
        av_free(_frame);
    }
    
    // Close the codec
    if (_codecCtx){
        avcodec_close(_codecCtx);
    }
    // Close the video src
    if (_formatCtx){
        avformat_close_input(&_formatCtx);
    }
    
}

-(void)dealloc
{
    [self stop];
    sleep(1);   // wait thread
    [self deallocCodec];
}

@end
