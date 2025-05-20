//
//  Config.h
//  Agora-AITest
//
//  Created by ZhouRui on 2025/5/19.
//

#ifndef Config_h
#define Config_h

#define AGORA_APP_ID @""
#define AGORA_TOKEN @""
#define AGORA_CHANNEL_ID @"zzz100"
#define AGORA_USER_ID 652313
#define AGORA_CERTIFICATE @""


typedef NS_ENUM(NSInteger, LogLevel) {
    LogLevelError = 0,
    LogLevelWarning = 1,
    LogLevelInfo = 2,
    LogLevelDebug = 3,
    LogLevelVerbose = 4
};

static const LogLevel currentLogLevel = LogLevelInfo;

static dispatch_queue_t logQueue;

static void InitLogQueue(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logQueue = dispatch_queue_create("com.agora.aitest.logqueue", DISPATCH_QUEUE_SERIAL);
    });
}

static void AsyncLog(LogLevel level, NSString *format, ...) {
    if (level > currentLogLevel) return;
    
    InitLogQueue();
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(logQueue, ^{
        NSLog(@"%@", message);
    });
}

#define LogError(fmt, ...) AsyncLog(LogLevelError, fmt, ##__VA_ARGS__)
#define LogWarning(fmt, ...) AsyncLog(LogLevelWarning, fmt, ##__VA_ARGS__)
#define LogInfo(fmt, ...) AsyncLog(LogLevelInfo, fmt, ##__VA_ARGS__)
#define LogDebug(fmt, ...) AsyncLog(LogLevelDebug, fmt, ##__VA_ARGS__)
#define LogVerbose(fmt, ...) AsyncLog(LogLevelVerbose, fmt, ##__VA_ARGS__)

#endif /* Config_h */
