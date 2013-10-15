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
 
 * @File:       RTSPPlayerViewController.m
 * @Abstract:   RTSPPlayer 视图控制器
 * @History:
 
 -2013-08-19 创建 by xuwf
 */

#import "RTSPPlayerViewController.h"
#import "RTSPPlayer.h"
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

const Vertex Vertices[] = {
    {{1, -1, 0}, {1, 1, 1, 1}, {1, 1}},
    {{1, 1, 0}, {1, 1, 1, 1}, {1, 0}},
    {{-1, 1, 0}, {1, 1, 1, 1}, {0, 0}},
    {{-1, -1, 0}, {1, 1, 1, 1}, {0, 1}}
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 Position; // 1
 attribute vec4 SourceColor; // 2
 
 varying vec4 DestinationColor; // 3
 
 attribute vec2 TexCoordIn;
 varying vec2 TexCoordOut;
 
 void main(void) { // 4
     DestinationColor = SourceColor; // 5
     gl_Position = Position; // 6
     TexCoordOut = TexCoordIn; // New
 }
 );

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 TexCoordOut;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, TexCoordOut).r;
     highp float u = texture2D(s_texture_u, TexCoordOut).r - 0.5;
     highp float v = texture2D(s_texture_v, TexCoordOut).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);
 }
 
 );

////////////////////////////////////////////////////////////////////////////////
@interface RTSPPlayerViewController() {
    RTSPPlayer* _player;
    EAGLContext*_context;
    NSString*   _contentURL;
    
    float       _curRed;
    BOOL        _increasing;
    
    GLuint      _vertexBuffer;
    GLuint      _indexBuffer;
    
    GLuint      _positionSlot;
    GLuint      _colorSlot;
    
    uint16_t    _textureWidth;
    uint16_t    _textureHeight;
    GLuint      _yTexture;
    GLuint      _uTexture;
    GLuint      _vTexture;
    GLuint      _texCoordSlot;
    GLuint      _yTextureUniform;
    GLuint      _uTextureUniform;
    GLuint      _vTextureUniform;
    
    dispatch_semaphore_t _textureUpdateRenderSemaphore;
    
    /* Loading */
    UIActivityIndicatorView*    _activityIndicatorView;
    
    UILabel*    _promptLabel;
}

@property (strong, nonatomic) EAGLContext* context;

@end

@implementation RTSPPlayerViewController
@synthesize context = _context;

- (id)init {
    self = [super init];
    if (self) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [_activityIndicatorView hidesWhenStopped];
        [_activityIndicatorView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin];
        
        _promptLabel = [[UILabel alloc] init];
        [_promptLabel setTextColor:[UIColor whiteColor]];
        [_promptLabel setBackgroundColor:[UIColor clearColor]];
        [_promptLabel setTextAlignment:NSTextAlignmentCenter];
        [_promptLabel setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleWidth];
    }
    return self;
}

- (id)initWithContentURL:(NSString *)contentURL {
    self = [self init];
    if (self) {
        _contentURL = contentURL;

    }
    return self;
}

- (void)setContentURL:(NSString *)contentURL {
    _contentURL = contentURL;
}

- (void)startOnMainThread {
    [_promptLabel setText:@""];
    [_activityIndicatorView startAnimating];

}

- (void)endOnMainThread {
    [_activityIndicatorView stopAnimating];
}

- (void)play {
    if ([NSThread isMainThread]) {
        [self performSelectorInBackground:@selector(play) withObject:nil];
        return;
    }
    
    // wait for stop
    while (_player.state == RTSPPlayerStatePlay || _player.state == RTSPPlayerStateLoading) {
        [_player stop];
        usleep(100);
    }
    
    [self performSelectorOnMainThread:@selector(startOnMainThread) withObject:nil waitUntilDone:NO];
    
    _player = [[RTSPPlayer alloc] init];
    
    NSError* error = nil;
    if ([_player openURL:_contentURL error:&error]) {
        [_player startWithCallbackBlock:^(AVFrameData* frame) {
            [self loadFrameData:frame];
        } waitForConsumer:YES completionCallback:NULL];
    } else {
        [_promptLabel setText:[NSString stringWithFormat:@"Load failed (%@)", [error.userInfo objectForKey:RTSPErrorKey]]];
    }
    
    [self performSelectorOnMainThread:@selector(endOnMainThread) withObject:nil waitUntilDone:NO];
}

- (void)stop {
    [_player stop];
    _player = nil;
}

- (void)setupGL {
    [EAGLContext setCurrentContext:self.context];
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    // init the update render semaphore
    _textureUpdateRenderSemaphore = dispatch_semaphore_create((long)1);
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	// Do any additional setup after loading the view.
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    
    [self setupGL];
    [self compileShaders];
    
    // setup the textures
    _textureWidth = 1280;
    _textureHeight = 720;
    _yTexture = [self setupTexture:nil width:_textureWidth height:_textureHeight textureIndex:0];
    _uTexture = [self setupTexture:nil width:_textureWidth/2 height:_textureHeight/2 textureIndex:1];
    _vTexture = [self setupTexture:nil width:_textureWidth/2 height:_textureHeight/2 textureIndex:2];
    
    // activity
    [self.view addSubview:_activityIndicatorView];
    
    [self.view addSubview:_promptLabel];
}

- (void)viewDidAppear:(BOOL)animated {
    [_activityIndicatorView setCenter:CGPointMake(self.view.frame.size.width/2, 30)];
    [_promptLabel setFrame:CGRectMake(0, self.view.frame.size.height-50, self.view.frame.size.width, 30)];
}

- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"viewWillDisappear...");
}

- (void)tearDownGL {
    
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    
    glDeleteTextures(1, &_yTexture);
    glDeleteTextures(1, &_uTexture);
    glDeleteTextures(1, &_vTexture);
    
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
    
    [self tearDownGL];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

#pragma mark - texture setup

- (void) updateTexture: (NSData*)textureData width:(uint) width height:(uint) height textureIndex:(GLuint)index
{
    long renderStatus = dispatch_semaphore_wait(_textureUpdateRenderSemaphore, DISPATCH_TIME_NOW);
    if (renderStatus==0){
        GLubyte *glTextureData;
        if (textureData){
            glTextureData = (GLubyte*)(textureData.bytes);
        }else{
            glTextureData = (GLubyte *) malloc(width*height);
            memset(glTextureData, 0, width*height);
        }
        glActiveTexture(GL_TEXTURE0+index);
        //        glBindTexture(GL_TEXTURE_2D, texName);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, glTextureData);
        
        if (!textureData){
            free(glTextureData);
        }
        dispatch_semaphore_signal(_textureUpdateRenderSemaphore);
    }
}

- (GLuint)setupTexture:(NSData *)textureData width:(uint) width height:(uint) height textureIndex:(GLuint) index
{
    GLuint texName;
    
    glGenTextures(1, &texName);
    glActiveTexture(GL_TEXTURE0+index);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    [self updateTexture:textureData width:width height:height textureIndex:index];
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    return texName;
}

#pragma mark - compile and load shaders

- (GLuint)compileShader:(NSString*)shaderString withType:(GLenum)shaderType
{
    GLuint shaderHandle = glCreateShader(shaderType);
    if (shaderHandle == 0 || shaderHandle == GL_INVALID_ENUM) {
        return -1;
    }
    
    // 3
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4
    glCompileShader(shaderHandle);
    
    // 5
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        return -1;
    }
    
    return shaderHandle;
}

- (void) compileShaders
{
    GLuint vertexShader = [self compileShader:vertexShaderString
                                     withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:rgbFragmentShaderString
                                       withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        return;
    }
    
    glUseProgram(programHandle);
    
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    
    // set the shader slots
    _texCoordSlot = glGetAttribLocation(programHandle, "TexCoordIn");
    glEnableVertexAttribArray(_texCoordSlot);
    _yTextureUniform = glGetUniformLocation(programHandle, "s_texture_y");
    _uTextureUniform = glGetUniformLocation(programHandle, "s_texture_u");
    _vTextureUniform = glGetUniformLocation(programHandle, "s_texture_v");
    _yTexture = 0;
    _uTexture = 0;
    _vTexture = 0;
}

#pragma mark - render code
- (void) setGLViewportToScale
{
    CGFloat scaleFactor = [[UIScreen mainScreen] scale];
    if (_textureHeight!=0 && _textureWidth!=0){
        float targetRatio = _textureWidth/(_textureHeight*1.0);
        float viewRatio = self.view.bounds.size.width/(self.view.bounds.size.height*1.0);
        uint16_t x,y,width,height;
        if (targetRatio>viewRatio){
            width=self.view.bounds.size.width*scaleFactor;
            height=width/targetRatio;
            x=0;
            y=(self.view.bounds.size.height*scaleFactor-height)/2;
            
        }else{
            height=self.view.bounds.size.height*scaleFactor;
            width = height*targetRatio;
            y=0;
            x=(self.view.bounds.size.width*scaleFactor-width)/2;
        }
        glViewport(x,y,width,height);
    }else{
        glViewport(self.view.bounds.origin.x, self.view.bounds.origin.y,
                   self.view.bounds.size.width*scaleFactor, self.view.bounds.size.height*scaleFactor);
    }
}

- (void)render
{
    [EAGLContext setCurrentContext:self.context];
    
    [self setGLViewportToScale];
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    
    // load the texture
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 7));
    
    //    glActiveTexture(GL_TEXTURE0);
    //    glBindTexture(GL_TEXTURE_2D, _yTexture);
    glUniform1i(_yTextureUniform, 0);
    
    //    glActiveTexture(GL_TEXTURE0+1);
    //    glBindTexture(GL_TEXTURE_2D, _uTexture);
    glUniform1i(_uTextureUniform, 1);
    
    //    glActiveTexture(GL_TEXTURE0+2);
    //    glBindTexture(GL_TEXTURE_2D, _vTexture);
    glUniform1i(_vTextureUniform, 2);
    
    // draw
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
                   GL_UNSIGNED_BYTE, 0);
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}


#pragma mark - loading the texture data

- (int) loadFrameData:(AVFrameData *)frameData
{
    if (frameData && self.context){
        [EAGLContext setCurrentContext:self.context];
        if (_yTexture && _uTexture && _vTexture){
            [self updateTexture:frameData.colorPlane0 width:frameData.width.intValue height:frameData.height.intValue textureIndex:0];
            [self updateTexture:frameData.colorPlane1 width:frameData.width.intValue/2 height:frameData.height.intValue/2 textureIndex:1];
            [self updateTexture:frameData.colorPlane2 width:frameData.width.intValue/2 height:frameData.height.intValue/2 textureIndex:2];
            _textureWidth = frameData.width.intValue;
            _textureHeight = frameData.height.intValue;
        }
        return 0;
    }else{
        return -1;
    }
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    long textureUpdateStatus = dispatch_semaphore_wait(_textureUpdateRenderSemaphore, DISPATCH_TIME_NOW);
    if (textureUpdateStatus==0){
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        [self render];
        dispatch_semaphore_signal(_textureUpdateRenderSemaphore);
    }
}

#pragma mark - GLKViewControllerDelegate

- (void) update
{
    if (_increasing) {
        _curRed += 1.0 * self.timeSinceLastUpdate;
    } else {
        _curRed -= 1.0 * self.timeSinceLastUpdate;
    }
    if (_curRed >= 1.0) {
        _curRed = 1.0;
        _increasing = NO;
    }
    if (_curRed <= 0.0) {
        _curRed = 0.0;
        _increasing = YES;
    }
}


- (void)dealloc {
    [_player stop];
    _player = nil;
    
    [_activityIndicatorView removeFromSuperview];
    _activityIndicatorView = nil;
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    self.context = nil;
    [self tearDownGL];
}

@end
