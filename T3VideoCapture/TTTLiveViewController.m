//
//  TTTLiveViewController.m
//  T3VideoCapture
//
//  Created by Work on 2019/7/4.
//  Copyright © 2019 yanzhen. All rights reserved.
//

#import "TTTLiveViewController.h"
#import "TTTRtcManager.h"
#import <AVFoundation/AVFoundation.h>

@interface TTTLiveViewController ()<TTTRtcEngineDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *anchorPlayer;
@property (weak, nonatomic) IBOutlet UILabel *statsLabel;
@property (weak, nonatomic) IBOutlet UIButton *exitBtn;
    
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) dispatch_queue_t dataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoDataOutput *dataOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureConnection *connect;
@end

@implementation TTTLiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    TTTRtcManager.manager.rtcEngine.delegate = self;
    [self startPreview];
}
    
- (IBAction)exitChannel:(UIButton *)sender {
    [self.session stopRunning];
    [TTTRtcManager.manager.rtcEngine leaveChannel:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}
    

- (void)startPreview {
    if (self.session.isRunning) {
        return;
    }
    _session = [[AVCaptureSession alloc] init];
    __block AVCaptureDevice *camera = nil;
    NSArray<AVCaptureDevice *> *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    [devices enumerateObjectsUsingBlock:^(AVCaptureDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.position == AVCaptureDevicePositionFront) {
            camera = obj;
            *stop = YES;
        }
    }];
    if (camera == nil) {
        NSLog(@"3TLog--:未找到前置摄像头");
        return;
    }
    
    NSError *error;
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (error) {
        NSLog(@"3TLog--:%@",error.description);
        return;
    }
    
    _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _dataOutput.alwaysDiscardsLateVideoFrames = YES;
    _dataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    _dataOutputQueue = dispatch_queue_create("TTT.video.queue", 0);
    [self.dataOutput setSampleBufferDelegate:self queue:self.dataOutputQueue];
    //
    if ([self.session canAddInput:self.deviceInput]) {
        [self.session addInput:self.deviceInput];
    }
    
    if ([self.session canAddOutput:self.dataOutput]) {
        [self.session addOutput:self.dataOutput];
    }
    
    [_session beginConfiguration];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    _connect = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    [_connect setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [_session commitConfiguration];
    
    AVCaptureVideoPreviewLayer *previewLayer= [AVCaptureVideoPreviewLayer layerWithSession:_session];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.backgroundColor = [UIColor clearColor].CGColor;
    previewLayer.frame = UIScreen.mainScreen.bounds;
    [self.anchorPlayer.layer addSublayer:previewLayer];
    
    [camera lockForConfiguration:nil];
    camera.activeVideoMinFrameDuration = CMTimeMake(1, 15);
    camera.activeVideoMaxFrameDuration = CMTimeMake(1, 15 + 2);
    [camera unlockForConfiguration];
    
    if ([camera.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeCinematic]) {
        [_connect setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeCinematic];
    }else if([camera.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeAuto]){
        [_connect setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
    }
    [self.session startRunning];
}
    
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(nonnull CMSampleBufferRef)sampleBuffer fromConnection:(nonnull AVCaptureConnection *)connection {
    CVPixelBufferRef pixerBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    TTTRtcVideoFrame *frame = [[TTTRtcVideoFrame alloc] init];
    frame.height = (int)CVPixelBufferGetHeight(pixerBuffer);
    frame.strideInPixels = (int)CVPixelBufferGetWidth(pixerBuffer);
    frame.format = TTTRtc_VideoFrameFormat_Texture;
    frame.textureBuffer = pixerBuffer;
    [TTTRtcManager.manager.rtcEngine pushExternalVideoFrame:frame];
}
    
#pragma mark - TTTRtcEngineDelegate
- (void)rtcEngine:(TTTRtcEngineKit *)engine reportRtcStats:(TTTRtcStats *)stats {
    _statsLabel.text = [NSString stringWithFormat:@"A-↑%ldkbps  V-↑%ldkbps", stats.txAudioKBitrate, stats.txVideoKBitrate];
}
    
- (void)rtcEngineConnectionDidLost:(TTTRtcEngineKit *)engine {
    NSLog(@"3TLog--:网络连接丢失，正在重连");
}

- (void)rtcEngineReconnectServerSucceed:(TTTRtcEngineKit *)engine {
    NSLog(@"3TLog--:重连成功");
}
    
- (void)rtcEngineReconnectServerTimeout:(TTTRtcEngineKit *)engine {
    NSLog(@"3TLog--:重连失败——退出房间");
    [self exitChannel:_exitBtn];
}
//被踢出房间
- (void)rtcEngine:(TTTRtcEngineKit *)engine didKickedOutOfUid:(int64_t)uid reason:(TTTRtcKickedOutReason)reason {
    NSString *errorInfo = @"";
    switch (reason) {
        case TTTRtc_KickedOut_PushRtmpFailed:
            errorInfo = @"rtmp推流失败";
            break;
        case TTTRtc_KickedOut_ReLogin:
            errorInfo = @"重复登录";
            break;
        case TTTRtc_KickedOut_NewChairEnter:
            errorInfo = @"其他人以主播身份进入";
            break;
        default:
            errorInfo = @"未知错误";
            break;
    }
    NSLog(@"3TLog--:%@", errorInfo);
    [self exitChannel:_exitBtn];
}
@end
