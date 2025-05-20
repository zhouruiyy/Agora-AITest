# Agora-AITest

基于声网SDK的音频处理测试工程，专注于音频帧拉取功能测试与分析。

## 项目简介

Agora-AITest是一个用于测试声网RTC SDK音频功能的iOS项目，主要关注音频帧的实时拉取、处理和保存功能。该项目可用于以下场景：

- 声网SDK音频功能测试
- 音频帧处理性能评估
- 高精度音频定时器实现验证
- PCM音频数据采集与分析

## 安装与配置

1. 克隆项目到本地
   ```bash
   git clone https://github.com/zhouruiyy/Agora-AITest
   cd Agora-AITest
   ```

2. 安装依赖
   ```bash
   pod install
   ```

3. 打开工程
   ```bash
   open Agora-AITest.xcworkspace
   ```

4. 在`Config.h`中配置Agora App ID和其他参数
   ```objective-c
   #define AGORA_APP_ID @"your-app-id"
   #define AGORA_CHANNEL_ID @"your-channel"
   #define AGORA_USER_ID 123456
   ```

## 核心功能

### 音频拉取管理器 (PullAudioFrameManager)

`PullAudioFrameManager`是项目的核心类，提供了两种音频拉取模式：

1. **标准拉取模式**: 
   - 使用`startWithRtcEngine`方法
   - 支持多帧拉取补偿
   - 自动计算音频时间对齐

2. **普通拉取模式**: 
   - 使用`startNormalWithRtcEngine`方法
   - 简单定时拉取单帧
   - 适合基础测试场景

两种模式都支持PCM音频数据保存到文件，便于后续分析。
同时注意要有一个远端用户加入到同一频道中，产生语音，方便另一端pull audio。

### 使用示例

```objective-c
// 初始化Agora SDK
[self setupAgoraKit];

// 加入频道
[self joinChannel];

// 开始拉取音频帧
[[PullAudioFrameManager sharedInstance] startWithRtcEngine:self.agoraKit
                                                 interval:10    // 每10毫秒拉取一次
                                               sampleRate:16000 // 采样率
                                             channelCount:1    // 单声道
                                               saveToFile:YES]; // 保存到文件

// 停止拉取
[[PullAudioFrameManager sharedInstance] stop];
```

## 测试PCM音频

生成的PCM文件保存在应用的Cache目录中，可以通过以下方式查看：
- Xcode -> Devices and Simulators -> 选择设备 -> 选择应用 -> 下载容器
- 查找形如`pull_audio_1747723235487.pcm`的文件

## 许可证

[MIT License](LICENSE)

## 联系方式

如有问题，请联系项目维护者。 