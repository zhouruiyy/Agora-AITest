//
//  PullAudioFrameManager.m
//  Agora-AITest
//
//  Created by ZhouRui on 2025/5/19.
//

#import "PullAudioFrameManager.h"
#import <AgoraRtcKit/AgoraRtcEngineKit.h>
#import <os/lock.h>
#import "Config.h"

#define LOGTAG @"[PullAudioFrameManager]"

static const NSInteger MIN_POOL_FRAMES = 1;
static const NSInteger MAX_POOL_FRAMES = 5;

@interface PullAudioFrameManager ()

@property (atomic, assign) BOOL started;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) int64_t consumeAudioFrames;

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) dispatch_queue_t fileWriterQueue;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<NSData *> *> *byteArrayPool;
@property (nonatomic) os_unfair_lock poolLock;
@property (nonatomic, assign) NSInteger poolOnePackageAudioSize;

@end

@implementation PullAudioFrameManager

+ (instancetype)sharedInstance {
    static PullAudioFrameManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _started = NO;
        _byteArrayPool = [NSMutableDictionary dictionary];
        _poolLock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

#pragma mark - Public

- (void)startWithRtcEngine:(AgoraRtcEngineKit *)rtcEngine
                  interval:(NSInteger)interval
                sampleRate:(NSInteger)sampleRate
              channelCount:(NSInteger)channelCount
                saveToFile:(BOOL)saveToFile {
    
    LogInfo(@"%@: Starting PullAudioFrameManager. interval: %ld, sampleRate: %ld, channelCount: %ld, saveToFile: %d", 
           LOGTAG, (long)interval, (long)sampleRate, (long)channelCount, saveToFile);
    
    if (self.started) {
        LogInfo(@"%@: PullAudioFrameManager already started.", LOGTAG);
        return;
    }
    
    self.started = YES;
    self.startTime = [[NSDate date] timeIntervalSince1970] * 1000;
    self.consumeAudioFrames = 0;
    self.fileHandle = nil;
    self.fileWriterQueue = nil;
    LogInfo(@"%@: startTime: %f", LOGTAG, self.startTime);
    self.poolOnePackageAudioSize = sampleRate / 1000 * 2 * channelCount * interval;
    LogInfo(@"%@: Audio package size calculated: %ld bytes", LOGTAG, (long)self.poolOnePackageAudioSize);
    
    if (self.poolOnePackageAudioSize <= 0) {
        LogError(@"%@: Invalid audio parameters resulting in zero package size.", LOGTAG);
        self.started = NO;
        return;
    }
    
    if (saveToFile) {
        [self setupFileHandleWithStartTime:self.startTime];
        LogInfo(@"%@: File handle setup completed. File handle is %@", LOGTAG, self.fileHandle ? @"valid" : @"nil");
    }
    
    NSThread *pullThread = [[NSThread alloc] initWithBlock:^{
        [NSThread currentThread].name = @"com.agora.audio.pullThread";
        [NSThread currentThread].threadPriority = 1.0;
        PullAudioFrameManager *strongSelf = self;
        
        LogInfo(@"%@: Audio pull thread started with interval: %ld ms", LOGTAG, (long)interval);
        
        while (strongSelf.started) {
            @autoreleasepool {
                NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970] * 1000;
                int64_t totalRequiredFrames = (currentTime - strongSelf.startTime) / interval;
                int64_t framesToPullThisCycle = totalRequiredFrames - strongSelf.consumeAudioFrames;
                
                LogInfo(@"%@: currentTime: %f, totalRequiredFrames: %lld, consumeAudioFrames: %lld, framesToPullThisCycle: %lld", 
                        LOGTAG, currentTime, totalRequiredFrames, strongSelf.consumeAudioFrames, framesToPullThisCycle);
                
                if (strongSelf.consumeAudioFrames % 250 == 0) {
                    LogInfo(@"%@: Audio frames - Total required: %lld, Already consumed: %lld, To pull this cycle: %lld", 
                          LOGTAG, totalRequiredFrames, strongSelf.consumeAudioFrames, framesToPullThisCycle);
                }
                
                if (framesToPullThisCycle > 0) {
                    NSInteger maxFramesPerCycle = NSIntegerMax / self.poolOnePackageAudioSize;
                    framesToPullThisCycle = MIN(framesToPullThisCycle, maxFramesPerCycle);
                    
                    NSInteger pullSize = self.poolOnePackageAudioSize * framesToPullThisCycle;
                    if (pullSize < 0) {
                        LogError(@"%@: Calculated pullSize %ld exceeds NSIntegerMax or became negative.", LOGTAG, (long)pullSize);
                        break;
                    }
                    
                    NSTimeInterval msElapsed = currentTime - strongSelf.startTime;
                    NSMutableData *pullData = [strongSelf getByteArrayFromPoolWithSize:pullSize];
                    
                    if (framesToPullThisCycle > 1) {
                        LogDebug(@"%@: Calling pull with size: %ld bytes at time %.1f ms", LOGTAG, (long)pullSize, msElapsed);
                    }
                    // pull audio frame
                    BOOL ret = [rtcEngine pullPlaybackAudioFrameRawData:pullData.mutableBytes lengthInByte:(int)pullSize];
                    if (ret == YES) {                    
                        strongSelf.consumeAudioFrames += framesToPullThisCycle;
                        
                        if (strongSelf.fileHandle && strongSelf.fileWriterQueue) {
                            NSData *dataCopy = [pullData copy];
                            [strongSelf recycleByteArrayToPool:pullData];
                            
                            dispatch_async(strongSelf.fileWriterQueue, ^{
                                @try {
                                    [strongSelf.fileHandle writeData:dataCopy];
                                } @catch (NSException *exception) {
                                    LogError(@"%@: Failed to write audio data to file: %@", LOGTAG, exception);
                                }
                            });
                        } else {
                            if (!strongSelf.fileHandle) {
                                LogWarning(@"%@: File handle is nil, cannot write data", LOGTAG);
                            }
                            if (!strongSelf.fileWriterQueue) {
                                LogWarning(@"%@: File writer queue is nil, cannot write data", LOGTAG);
                            }
                            [strongSelf recycleByteArrayToPool:pullData];
                        }
                    } else {
                        LogWarning(@"%@: pullPlaybackAudioFrame failed, ret: %d", LOGTAG, ret);
                        [strongSelf recycleByteArrayToPool:pullData];
                    }
                }  
            }
            // 休眠interval
            usleep((useconds_t)(interval * 1000));
            // usleep((useconds_t)((interval - 6) * 1000));
        }
        
        LogInfo(@"%@: Audio pull thread stopped", LOGTAG);
    }];
    
    [pullThread start];
    
    LogInfo(@"%@: Audio pull thread has been launched with interval: %ld ms", LOGTAG, (long)interval);
}

- (void)startNormalWithRtcEngine:(AgoraRtcEngineKit *)rtcEngine
                        interval:(NSInteger)interval
                      sampleRate:(NSInteger)sampleRate
                    channelCount:(NSInteger)channelCount
                      saveToFile:(BOOL)saveToFile {
    
    LogInfo(@"%@: startNormal PullAudioFrameManager.", LOGTAG);
    
    if (self.started) {
        LogInfo(@"%@: PullAudioFrameManager already started.", LOGTAG);
        return;
    }
    
    self.started = YES;
    self.startTime = [[NSDate date] timeIntervalSince1970] * 1000;
    
    NSInteger onePackageAudioSize = sampleRate / 1000 * 2 * channelCount * interval;
    
    if (saveToFile) {
        [self setupFileHandleWithStartTime:self.startTime];
        LogInfo(@"%@: File handle setup completed. File handle is %@", LOGTAG, self.fileHandle ? @"valid" : @"nil");
    }
    
    NSMutableData *dataByteArray = [NSMutableData dataWithLength:onePackageAudioSize];
    NSThread *pullThread = [[NSThread alloc] initWithBlock:^{
        [NSThread currentThread].name = @"com.agora.audio.normalPullThread";
        [NSThread currentThread].threadPriority = 1.0;
        
        PullAudioFrameManager *strongSelf = self;
        LogInfo(@"%@: Normal audio pull thread started with interval: %ld ms", LOGTAG, (long)interval);
        
        while (strongSelf.started) {
            @autoreleasepool {
                // 拉取音频帧
                BOOL ret = [rtcEngine pullPlaybackAudioFrameRawData:dataByteArray.mutableBytes lengthInByte:(int)onePackageAudioSize];
                
                if (ret == YES) {
                    if (strongSelf.fileHandle && strongSelf.fileWriterQueue) {
                        NSData *dataCopy = [dataByteArray copy];
                        // 清空dataByteArray
                        [dataByteArray resetBytesInRange:NSMakeRange(0, onePackageAudioSize)];
                        
                        dispatch_async(strongSelf.fileWriterQueue, ^{
                            @try {
                                [strongSelf.fileHandle writeData:dataCopy];
                            } @catch (NSException *exception) {
                                LogError(@"%@: Failed to write audio data to file: %@", LOGTAG, exception);
                            }
                        });
                    }
                } else {
                    LogError(@"%@: pullPlaybackAudioFrame failed, ret: %d", LOGTAG, ret);
                }
                
                usleep((useconds_t)((interval) * 1000));
                // 异常情况
                // usleep((useconds_t)((interval - 6) * 1000));
            }
        }
        
        LogInfo(@"%@: Normal audio pull thread stopped", LOGTAG);
    }];
    
    [pullThread start];
    LogInfo(@"%@: Normal audio pull thread has been launched with interval: %ld ms", LOGTAG, (long)interval);
}

- (void)stop {
    if (!self.started) {
        LogInfo(@"%@: PullAudioFrameManager already stopped or never started.", LOGTAG);
        return;
    }
    
    LogInfo(@"%@: Stopping PullAudioFrameManager.", LOGTAG);
    
    self.started = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self closeFile];
        [self clearByteArrayPool];
    });
}

#pragma mark - Private

- (void)setupFileHandleWithStartTime:(NSTimeInterval)startTime {
    @try {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDir = [paths firstObject];
        
        if (!cacheDir) {
            @throw [NSException exceptionWithName:@"SecurityException"
                                           reason:@"Failed to access cache directory"
                                         userInfo:nil];
        }
        
        NSString *fileName = [NSString stringWithFormat:@"pull_audio_%.0f.pcm", startTime];
        NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
        
        LogInfo(@"%@: Creating audio file at path: %@", LOGTAG, filePath);
        
        BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        LogInfo(@"%@: File creation result: %@", LOGTAG, fileCreated ? @"success" : @"failed");
        
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        if (!self.fileHandle) {
            @throw [NSException exceptionWithName:@"IOError"
                                           reason:@"Failed to open file for writing"
                                         userInfo:nil];
        }
        
        self.fileWriterQueue = dispatch_queue_create("com.agora.ai.test.filewriter", DISPATCH_QUEUE_SERIAL);
        
        LogInfo(@"%@: Start saving audio to: %@ (fileHandle: %@)", LOGTAG, filePath, self.fileHandle);
    } @catch (NSException *exception) {
        LogError(@"%@: Failed to setup file handle: %@", LOGTAG, exception.reason);
        self.fileHandle = nil;
        self.fileWriterQueue = nil;
    }
}

- (void)closeFile {
    if (self.fileWriterQueue) {
        dispatch_sync(self.fileWriterQueue, ^{
        });
        self.fileWriterQueue = nil;
    }
    
    if (self.fileHandle) {
        @try {
            [self.fileHandle synchronizeFile];
            [self.fileHandle closeFile];
            LogInfo(@"%@: Closed audio save file.", LOGTAG);
        } @catch (NSException *exception) {
            LogError(@"%@: Failed to close audio save file: %@", LOGTAG, exception);
        } @finally {
            self.fileHandle = nil;
        }
    }
}

- (NSMutableData *)getByteArrayFromPoolWithSize:(NSInteger)size {
    os_unfair_lock_lock(&_poolLock);
    
    @try {
        NSInteger frameCount = size / self.poolOnePackageAudioSize;
        if (frameCount >= MIN_POOL_FRAMES && frameCount <= MAX_POOL_FRAMES) {
            NSNumber *key = @(frameCount);
            NSMutableArray *pool = self.byteArrayPool[key];
            
            if (pool && pool.count > 0) {
                NSMutableData *data = [pool lastObject];
                [pool removeLastObject];
                return data;
            }
        }
    } @finally {
        os_unfair_lock_unlock(&_poolLock);
    }
    
    return [NSMutableData dataWithLength:size];
}

- (void)recycleByteArrayToPool:(NSMutableData *)data {
    os_unfair_lock_lock(&_poolLock);
    
    @try {
        NSInteger frameCount = data.length / self.poolOnePackageAudioSize;
        if (frameCount >= MIN_POOL_FRAMES && frameCount <= MAX_POOL_FRAMES) {
            NSNumber *key = @(frameCount);
            NSMutableArray *pool = self.byteArrayPool[key];
            
            if (!pool) {
                pool = [NSMutableArray array];
                self.byteArrayPool[key] = pool;
            }
            
            [pool addObject:data];
        }
    } @finally {
        os_unfair_lock_unlock(&_poolLock);
    }
}

- (void)clearByteArrayPool {
    os_unfair_lock_lock(&_poolLock);
    
    @try {
        [self.byteArrayPool removeAllObjects];
    } @finally {
        os_unfair_lock_unlock(&_poolLock);
    }
}

@end 
