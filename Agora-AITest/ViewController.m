//
//  ViewController.m
//  Agora-AITest
//
//  Created by ZhouRui on 2025/5/19.
//

#import "ViewController.h"
#import <AgoraRtcKit/AgoraRtcEngineKit.h>
#import "Config.h"
#import "PullAudioFrameManager.h"

@interface ViewController () <AgoraRtcEngineDelegate>

@property (nonatomic, strong) AgoraRtcEngineKit *agoraKit;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *startNormalButton;
@property (nonatomic, strong) UIButton *stopButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupUI];
    [self setupAgoraKit];
}

- (void)setupUI {
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"开始拉取音频" forState:UIControlStateNormal];
    self.startButton.frame = CGRectMake(50, 100, 200, 40);
    [self.startButton addTarget:self action:@selector(startButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startButton];
    
    self.startNormalButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startNormalButton setTitle:@"开始普通模式拉取" forState:UIControlStateNormal];
    self.startNormalButton.frame = CGRectMake(50, 160, 200, 40);
    [self.startNormalButton addTarget:self action:@selector(startNormalButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startNormalButton];

    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopButton setTitle:@"停止拉取音频" forState:UIControlStateNormal];
    self.stopButton.frame = CGRectMake(50, 220, 200, 40);
    [self.stopButton addTarget:self action:@selector(stopButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopButton];
}

- (void)startButtonTapped {
    NSLog(@"开始拉取音频");
    [self joinChannel];
    
    [[PullAudioFrameManager sharedInstance] startWithRtcEngine:self.agoraKit
                                                     interval:10  // 每10毫秒拉取一次
                                                   sampleRate:16000  // 采样率
                                                 channelCount:1  // 单声道
                                                   saveToFile:YES];  // 保存到文件
}

- (void)startNormalButtonTapped {
    NSLog(@"开始普通模式拉取");
    [self joinChannel];
    
    [[PullAudioFrameManager sharedInstance] startNormalWithRtcEngine:self.agoraKit
                                                           interval:10  // 每10毫秒拉取一次
                                                         sampleRate:16000  // 采样率
                                                       channelCount:1  // 单声道
                                                         saveToFile:YES];  // 保存到文件
}

- (void)stopButtonTapped {
    NSLog(@"停止拉取音频");
    [[PullAudioFrameManager sharedInstance] stop];
    [self leaveChannel];
}

- (void)setupAgoraKit {
    AgoraRtcEngineConfig *config = [[AgoraRtcEngineConfig alloc] init];
    config.appId = AGORA_APP_ID;
    self.agoraKit = [AgoraRtcEngineKit sharedEngineWithConfig:config delegate:self];
    [self.agoraKit setChannelProfile:AgoraChannelProfileLiveBroadcasting];
    [self.agoraKit setClientRole:AgoraClientRoleBroadcaster];
    [self.agoraKit enableAudio];
    [self.agoraKit setAudioScenario:AgoraAudioScenarioChorus];

    //  Before calling this method, call the [enableExternalAudioSink]([AgoraRtcEngineKit enableExternalAudioSink:channels:]) method to enable and set the external audio sink.
    [self.agoraKit enableExternalAudioSink:YES sampleRate:16000 channels:1];
}

- (void)joinChannel {
   AgoraRtcChannelMediaOptions *option = [[AgoraRtcChannelMediaOptions alloc] init];
   option.clientRoleType = AgoraClientRoleBroadcaster;
   [self.agoraKit joinChannelByToken:AGORA_TOKEN channelId:AGORA_CHANNEL_ID uid:AGORA_USER_ID mediaOptions:option joinSuccess:^(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed) {
        NSLog(@"joinChannelByToken success");
    }];
}

- (void)leaveChannel {
    [self.agoraKit leaveChannel:nil];
}

#pragma mark - AgoraRtcEngineDelegate

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSLog(@"didJoinChannel: %@, uid: %lu, elapsed: %ld", channel, uid, elapsed);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    NSLog(@"didOfflineOfUid: %lu, reason: %ld", uid, reason);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSLog(@"didJoinedOfUid: %lu, elapsed: %ld", uid, elapsed);
}


@end
