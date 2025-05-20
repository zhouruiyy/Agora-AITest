//
//  PullAudioFrameManager.h
//  Agora-AITest
//
//  Created by ZhouRui on 2025/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AgoraRtcEngineKit;

@interface PullAudioFrameManager : NSObject

/**
 * 获取PullAudioFrameManager单例
 */
+ (instancetype)sharedInstance;

/**
 * 从RTC引擎拉取音频帧，并可选择保存到文件
 * @param rtcEngine RTC引擎实例
 * @param interval 拉取间隔(毫秒)
 * @param sampleRate 采样率
 * @param channelCount 通道数
 * @param saveToFile 是否保存到文件
 */
- (void)startWithRtcEngine:(AgoraRtcEngineKit *)rtcEngine
                  interval:(NSInteger)interval
                sampleRate:(NSInteger)sampleRate
              channelCount:(NSInteger)channelCount
                saveToFile:(BOOL)saveToFile;

/**
 * 使用普通模式从RTC引擎拉取音频帧
 * @param rtcEngine RTC引擎实例
 * @param interval 拉取间隔(毫秒)
 * @param sampleRate 采样率
 * @param channelCount 通道数
 * @param saveToFile 是否保存到文件
 */
- (void)startNormalWithRtcEngine:(AgoraRtcEngineKit *)rtcEngine
                        interval:(NSInteger)interval
                      sampleRate:(NSInteger)sampleRate
                    channelCount:(NSInteger)channelCount
                      saveToFile:(BOOL)saveToFile;

/**
 * 停止拉取音频帧
 */
- (void)stop;

@end

NS_ASSUME_NONNULL_END 