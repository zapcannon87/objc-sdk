//
//  AVIMConnection.m
//  AVOS
//
//  Created by ZapCannon87 on 2018/10/30.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConnection.h"
#import "AVIMWebSocket.h"
#import "AVIMNetworkReachabilityManager.h"
#import "AVErrorUtils.h"
#import "AVUtils.h"
#import "AVIMClient_Internal.h"
#import "LCRouter_Internal.h"
#import "AVApplication.h"
#import "AVIMErrorUtil.h"
#import "AVIMCommon_Internal.h"
#import "AVIMGenericCommand+AVIMMessagesAdditions.h"

#define LCIM_OUT_COMMAND_LOG_FORMAT \
@"\n\n" \
@"------ BEGIN LeanCloud IM Out Command ------\n" \
@"content: %@\n"                                  \
@"------ END ---------------------------------\n" \
@"\n"

#define LCIM_IN_COMMAND_LOG_FORMAT \
@"\n\n" \
@"------ BEGIN LeanCloud IM In Command ------\n" \
@"content: %@\n"                                 \
@"------ END --------------------------------\n" \
@"\n"

@implementation AVIMConnectionInitConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegateQueue = dispatch_get_main_queue();
        _commandTTL = 30.0;
    }
    return self;
}

@end

@interface AVIMCommandCallback : NSObject

@property (nonatomic, copy, readonly) void (^block)(AVIMGenericCommand *inCommand, NSError *error);
@property (nonatomic, assign, readonly) NSTimeInterval timeoutTimestamp;

- (instancetype)initWithBlock:(void (^)(AVIMGenericCommand *, NSError *))block timeToLive:(NSTimeInterval)timeToLive;

@end

@implementation AVIMCommandCallback

- (instancetype)initWithBlock:(void (^)(AVIMGenericCommand *, NSError *))block timeToLive:(NSTimeInterval)timeToLive
{
    self = [super init];
    if (self) {
        _block = block;
        _timeoutTimestamp = [[NSDate date] timeIntervalSince1970] + timeToLive;
    }
    return self;
}

@end

@interface AVIMConnectionTimer : NSObject

@property (nonatomic, assign, readonly) NSTimeInterval pingpongInterval;
@property (nonatomic, assign, readonly) NSTimeInterval pingTimeout;
@property (nonatomic, strong, readonly) dispatch_source_t source;
@property (nonatomic, strong, readonly) dispatch_queue_t commandCallbackQueue;
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *commandIndexSequence;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber *, AVIMCommandCallback *> *commandCallbackCollection;
@property (nonatomic, assign, readwrite) NSTimeInterval lastPingSentTimestamp;
@property (nonatomic, assign, readwrite) NSTimeInterval lastPongReceivedTimestamp;
@property (nonatomic, copy, readonly) void (^pingSentBlock)(AVIMConnectionTimer *timer);

- (instancetype)initWithTimerQueue:(dispatch_queue_t)timerQueue
              commandCallbackQueue:(dispatch_queue_t)commandCallbackQueue
                     pingSentBlock:(void (^)(AVIMConnectionTimer *timer))pingSentBlock;
- (void)cancel;
- (void)insertCommandCallback:(AVIMCommandCallback *)commandCallback index:(UInt16)index;
- (void)handleCallbackCommand:(AVIMGenericCommand *)command;

@end

@implementation AVIMConnectionTimer

- (instancetype)initWithTimerQueue:(dispatch_queue_t)timerQueue
              commandCallbackQueue:(dispatch_queue_t)commandCallbackQueue
                     pingSentBlock:(void (^)(AVIMConnectionTimer *timer))pingSentBlock
{
    self = [super init];
    if (self) {
        _pingpongInterval = 180.0;
        _pingTimeout = 20.0;
        _commandCallbackQueue = commandCallbackQueue;
        _pingSentBlock = pingSentBlock;
        _commandIndexSequence = [NSMutableArray array];
        _commandCallbackCollection = [NSMutableDictionary dictionary];
        _lastPingSentTimestamp = 0;
        _lastPongReceivedTimestamp = 0;
        _source = ({
            dispatch_source_t sourceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timerQueue);
            dispatch_source_set_timer(sourceTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
            __weak typeof(self) weakSelf = self;
            dispatch_source_set_event_handler(sourceTimer, ^{
                NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
                [weakSelf checkCommandTimeout:currentTimestamp];
                [weakSelf checkPingPong:currentTimestamp];
            });
            dispatch_resume(sourceTimer);
            sourceTimer;
        });
    }
    return self;
}

- (void)cancel
{
    dispatch_source_cancel(self.source);
    NSArray<AVIMCommandCallback *> *callbacks = self.commandCallbackCollection.allValues;
    if (callbacks.count > 0) {
        dispatch_async(self.commandCallbackQueue, ^{
            NSError *error = ({
                AVIMErrorCode code = AVIMErrorCodeConnectionLost;
                LCError(code, AVIMErrorMessage(code), nil);
            });
            for (AVIMCommandCallback *callback in callbacks) {
                callback.block(nil, error);
            }
        });
    }
}

- (void)insertCommandCallback:(AVIMCommandCallback *)commandCallback index:(UInt16)index
{
    NSNumber *indexKey = @(index);
    [self.commandIndexSequence addObject:indexKey];
    [self.commandCallbackCollection setObject:commandCallback forKey:indexKey];
}

- (void)handleCallbackCommand:(AVIMGenericCommand *)command
{
    int32_t i = (command.hasI ? command.i : 0);
    if (i > 0 && i <= UINT16_MAX) {
        NSNumber *indexKey = @(i);
        AVIMCommandCallback *callback = self.commandCallbackCollection[indexKey];
        if (callback) {
            [self.commandCallbackCollection removeObjectForKey:indexKey];
            [self.commandIndexSequence removeObject:indexKey];
            dispatch_async(self.commandCallbackQueue, ^{
                callback.block(command, nil);
            });
        }
    }
}

- (void)checkCommandTimeout:(NSTimeInterval)currentTimestamp
{
    NSUInteger length = 0;
    for (NSNumber *indexKey in self.commandIndexSequence) {
        length += 1;
        AVIMCommandCallback *callback = self.commandCallbackCollection[indexKey];
        if (callback) {
            if (callback.timeoutTimestamp > currentTimestamp) {
                length -= 1;
                break;
            } else {
                [self.commandCallbackCollection removeObjectForKey:indexKey];
                dispatch_async(self.commandCallbackQueue, ^{
                    NSError *error = ({
                        AVIMErrorCode code = AVIMErrorCodeCommandTimeout;
                        LCError(code, AVIMErrorMessage(code), nil);
                    });
                    callback.block(nil, error);
                });
            }
        }
    }
    if (length > 0) {
        [self.commandIndexSequence removeObjectsInRange:NSMakeRange(0, length)];
    }
}

- (void)checkPingPong:(NSTimeInterval)currentTimestamp
{
    BOOL isPingSentAndPongNotReceived = (self.lastPingSentTimestamp > self.lastPongReceivedTimestamp);
    BOOL lastPingTimeout = (isPingSentAndPongNotReceived && (currentTimestamp > self.lastPingSentTimestamp + self.pingTimeout));
    BOOL shouldNextPingPong = (!isPingSentAndPongNotReceived && (currentTimestamp > self.lastPongReceivedTimestamp + self.pingpongInterval));
    if (lastPingTimeout || shouldNextPingPong) {
        self.pingSentBlock(self);
        self.lastPingSentTimestamp = currentTimestamp;
    }
}

@end

@interface AVIMConnection () <AVIMWebSocketDelegate> {
    UInt16 _serialIndex;
}

@property (nonatomic, strong, readonly) dispatch_queue_t serialQueue;
@property (nonatomic, strong) AVIMWebSocket *socket;
@property (nonatomic, strong) AVIMConnectionTimer *timer;
@property (nonatomic, assign) BOOL isAutoReconnectionEnabled;
@property (nonatomic, assign) BOOL useSecondaryServer;
@property (nonatomic, assign, readonly) UInt16 nextSerialIndex;
#if !TARGET_OS_WATCH
@property (nonatomic, assign) AVIMNetworkReachabilityStatus previousReachabilityStatus;
@property (nonatomic, strong, readonly) AVIMNetworkReachabilityManager *reachabilityManager;
#endif
#if TARGET_OS_IOS || TARGET_OS_TV
@property (nonatomic, assign) BOOL previousIsAppInBackground;
@property (nonatomic, strong, readonly) id<NSObject> enterBackgroundObserver;
@property (nonatomic, strong, readonly) id<NSObject> enterForegroundObserver;
#endif

@end

@implementation AVIMConnection

- (instancetype)initWithConfig:(AVIMConnectionInitConfig *)config
{
    NSParameterAssert(config.application && config.lcimProtocol && config.delegate && config.delegateQueue && config.commandTTL > 0);
    self = [super init];
    if (self) {
        _application = config.application;
        _lcimProtocol = config.lcimProtocol;
        _delegate = config.delegate;
        _delegateQueue = config.delegateQueue;
        _commandTTL = config.commandTTL;
        _customRTMServer = config.customRTMServer;
        
        _serialIndex = 1;
        _isAutoReconnectionEnabled = false;
        _useSecondaryServer = false;
        _socket = nil;
        _timer = nil;
        _serialQueue = ({
            NSString *className = NSStringFromClass(self.class);
            NSString *pathName = keyPath(self, serialQueue);
            NSString *label = [NSString stringWithFormat:@"%@.%@", className, pathName];
            dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, DISPATCH_QUEUE_SERIAL);
#if DEBUG
            void *keyAlsoContext = (__bridge void *)queue;
            dispatch_queue_set_specific(queue, keyAlsoContext, keyAlsoContext, NULL);
#endif
            queue;
        });
        
        __weak typeof(self) weakSelf = self;
#if TARGET_OS_IOS || TARGET_OS_TV
        _previousIsAppInBackground = (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground);
        NSOperationQueue *operationQueue = [NSOperationQueue new];
        operationQueue.underlyingQueue = _serialQueue;
        _enterBackgroundObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:operationQueue usingBlock:^(NSNotification * _Nonnull note) {
            AVLoggerInfo(AVLoggerDomainIM, @"Application did enter background");
            [weakSelf appStateChanged:true];
        }];
        _enterForegroundObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:operationQueue usingBlock:^(NSNotification * _Nonnull note) {
            AVLoggerInfo(AVLoggerDomainIM, @"Application will enter foreground");
            [weakSelf appStateChanged:false];
        }];
#endif
#if !TARGET_OS_WATCH
        _reachabilityManager = [AVIMNetworkReachabilityManager manager];
        _previousReachabilityStatus = _reachabilityManager.networkReachabilityStatus;
        [_reachabilityManager setReachabilityStatusChangeDispatchQueue:_serialQueue];
        [_reachabilityManager setReachabilityStatusChangeBlock:^(AVIMNetworkReachabilityStatus status) {
            AVLoggerInfo(AVLoggerDomainIM, @"Network status change to %@", AVIMStringFromNetworkReachabilityStatus(status));
            [weakSelf networkReachabilityStatusChanged:status];
        }];
        [_reachabilityManager startMonitoring];
#endif
    }
    return self;
}

- (void)dealloc
{
#if TARGET_OS_IOS || TARGET_OS_TV
    [NSNotificationCenter.defaultCenter removeObserver:_enterBackgroundObserver];
    [NSNotificationCenter.defaultCenter removeObserver:_enterForegroundObserver];
#endif
#if !TARGET_OS_WATCH
    [_reachabilityManager stopMonitoring];
#endif
    [_socket close];
    [_timer cancel];
}

#if !TARGET_OS_WATCH
- (void)networkReachabilityStatusChanged:(AVIMNetworkReachabilityStatus)newStatus
{
    AssertRunInQueue(self.serialQueue);
    AVIMNetworkReachabilityStatus oldStatus = self.previousReachabilityStatus;
    self.previousReachabilityStatus = newStatus;
    AVIMNetworkReachabilityStatus notReachable = AVIMNetworkReachabilityStatusNotReachable;
    if (oldStatus != notReachable && newStatus == notReachable) {
        [self tryClearConnectionWithEvent:AVIMConnectionEventNetworkNotReachable];
    } else if (oldStatus != newStatus && newStatus != notReachable) {
        [self tryClearConnectionWithEvent:AVIMConnectionEventNetworkChanged];
        if (self.isAutoReconnectionEnabled) {
            [self tryConnecting];
        }
    }
}
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
- (void)appStateChanged:(BOOL)nowIsAppInBackground
{
    AssertRunInQueue(self.serialQueue);
    BOOL previousIsAppInBackground = self.previousIsAppInBackground;
    self.previousIsAppInBackground = nowIsAppInBackground;
    if (previousIsAppInBackground && !nowIsAppInBackground) {
        if (self.isAutoReconnectionEnabled) {
            [self tryConnecting];
        }
    } else if (!previousIsAppInBackground && nowIsAppInBackground) {
        [self tryClearConnectionWithEvent:AVIMConnectionEventAppInBackground];
    }
}
#endif

// MARK: - Public

- (void)connect
{
    dispatch_async(self.serialQueue, ^{
        if (self.socket && self.isAutoReconnectionEnabled) {
            return;
        }
        [self tryConnecting];
    });
}

- (void)setAutoReconnectionEnabled:(BOOL)enabled
{
    dispatch_async(self.serialQueue, ^{
        self.isAutoReconnectionEnabled = enabled;
    });
}

- (void)disconnect
{
    dispatch_async(self.serialQueue, ^{
        [self tryClearConnectionWithEvent:AVIMConnectionEventDisconnectInvoked];
    });
}

- (void)sendCommand:(AVIMGenericCommand *)outCommand callback:(void (^)(AVIMGenericCommand * _Nullable, NSError * _Nullable))callback
{
    dispatch_async(self.serialQueue, ^{
        void(^errorCallback)(AVIMErrorCode) = ^(AVIMErrorCode code) {
            if (callback) {
                dispatch_async(self.delegateQueue, ^{
                    callback(nil, LCError(code, AVIMErrorMessage(code), nil));
                });
            }
        };
        if (self.socket && self.timer) {
            if (callback) {
                outCommand.i = self.nextSerialIndex;
            }
            NSData *data = [outCommand data];
            if (data) {
                if (data.length <= 5000) {
                    if (callback) {
                        AVIMCommandCallback *commandCallback = [[AVIMCommandCallback alloc] initWithBlock:callback timeToLive:self.commandTTL];
                        UInt16 index = outCommand.i;
                        [self.timer insertCommandCallback:commandCallback index:index];
                    }
                    AVLoggerDebug(AVLoggerDomainIM, LCIM_OUT_COMMAND_LOG_FORMAT, [outCommand avim_description]);
                    [self.socket send:data];
                } else {
                    errorCallback(AVIMErrorCodeCommandDataLengthTooLong);
                }
            } else {
                errorCallback(AVIMErrorCodeInvalidCommand);
            }
        } else {
            errorCallback(AVIMErrorCodeConnectionLost);
        }
    });
}

// MARK: - Private

- (AVIMConnectionEvent)checkIfCanDoConnecting
{
    AssertRunInQueue(self.serialQueue);
#if !TARGET_OS_WATCH
    if (self.previousIsAppInBackground) {
        return AVIMConnectionEventAppInBackground;
    }
#endif
#if TARGET_OS_IOS || TARGET_OS_TV
    if (self.previousReachabilityStatus == AVIMNetworkReachabilityStatusNotReachable) {
        return AVIMConnectionEventNetworkNotReachable;
    }
#endif
    return nil;
}

- (void)getRTMServerWithCallback:(void (^)(NSURL *URL, NSError *error))callback
{
    AssertRunInQueue(self.serialQueue);
    NSInteger inconsistency = 9976;
    if (self.customRTMServer) {
        NSURL *url = [NSURL URLWithString:self.customRTMServer];
        if (url.scheme) {
            callback(url, nil);
        } else {
            callback(nil, LCError(inconsistency, @"Custom RTM URL invalid.", nil));
        }
    } else {
        [[LCRouter sharedInstance] getRTMURLWithAppID:self.application.identifier callback:^(NSDictionary *dictionary, NSError *error) {
            dispatch_async(self.serialQueue, ^{
                if (error) {
                    callback(nil, error);
                } else {
                    NSString *primaryServer = [NSString lc__decodingDictionary:dictionary key:RouterKeyRTMServer];
                    NSString *secondaryServer = [NSString lc__decodingDictionary:dictionary key:RouterKeyRTMSecondary];
                    NSString *server = (self.useSecondaryServer ? secondaryServer : primaryServer);
                    // fallback
                    server = server ?: primaryServer;
                    if (server) {
                        NSURL *url = [NSURL URLWithString:server];
                        callback(url, nil);
                    } else {
                        callback(nil, LCError(inconsistency, @"RTM Router response invalid.", nil));
                    }
                }
            });
        }];
    }
}

- (void)tryConnecting
{
    AssertRunInQueue(self.serialQueue);
    [self getRTMServerWithCallback:^(NSURL *URL, NSError *error) {
        AssertRunInQueue(self.serialQueue);
        if (self.socket) {
            // if socket exists, means in connecting or did connect.
            return;
        }
        AVIMConnectionEvent cannotEvent = [self checkIfCanDoConnecting];
        if (cannotEvent) {
            dispatch_async(self.delegateQueue, ^{
                [self.delegate connection:self didFailInConnectingWithEvent:cannotEvent];
            });
        } else {
            if (error) {
                AVLoggerInfo(AVLoggerDomainIM, @"Get RTM server URL failed: %@", error);
                dispatch_async(self.delegateQueue, ^{
                    [self.delegate connection:self didFailInConnectingWithEvent:error];
                });
                if ([error.domain isEqualToString:NSURLErrorDomain] && self.isAutoReconnectionEnabled) {
                    [self tryConnecting];
                }
            } else {
                self.socket = [[AVIMWebSocket alloc] initWithURL:URL protocols:@[self.lcimProtocol]];
                [self.socket setDelegateDispatchQueue:self.serialQueue];
                [self.socket setDelegate:self];
                [self.socket open];
                AVLoggerInfo(AVLoggerDomainIM, @"%@ connecting URL<\"%@\"> with protocol<\"%@\">", self.socket, URL, self.lcimProtocol);
                dispatch_async(self.delegateQueue, ^{
                    [self.delegate connectionInConnecting:self];
                });
            }
        }
    }];
}

- (void)tryClearConnectionWithEvent:(id)event
{
    AssertRunInQueue(self.serialQueue);
    if (self.socket) {
        [self.socket setDelegate:nil];
        [self.socket close];
        self.socket = nil;
        dispatch_async(self.delegateQueue, ^{
            [self.delegate connection:self didDisconnectWithEvent:event];
        });
    }
    if (self.timer) {
        [self.timer cancel];
        self.timer = nil;
    }
}

- (UInt16)nextSerialIndex
{
    AssertRunInQueue(self.serialQueue);
    UInt16 index = _serialIndex;
    if (index == UINT16_MAX) {
        _serialIndex = 1;
    } else {
        _serialIndex += 1;
    }
    return index;
}

- (void)handleWebSocketClosedWithError:(NSError *)error
{
    AssertRunInQueue(self.serialQueue);
    if (self.timer) {
        [self tryClearConnectionWithEvent:error];
    } else {
        dispatch_async(self.serialQueue, ^{
            [self.delegate connection:self didFailInConnectingWithEvent:error];
        });
        [self.socket setDelegate:nil];
        self.socket = nil;
    }
}

// MARK: - AVIMWebSocketDelegate

- (void)webSocketDidOpen:(AVIMWebSocket *)webSocket
{
    AssertRunInQueue(self.serialQueue);
    NSParameterAssert(self.socket == webSocket && self.timer == nil);
    AVLoggerInfo(AVLoggerDomainIM, @"%@ open success", webSocket);
    self.timer = [[AVIMConnectionTimer alloc] initWithTimerQueue:self.serialQueue commandCallbackQueue:self.delegateQueue pingSentBlock:^(AVIMConnectionTimer *timer) {
        [webSocket sendPing:[NSData data]];
        AVLoggerInfo(AVLoggerDomainIM, @"%@ ping sent", webSocket);
    }];
    dispatch_async(self.delegateQueue, ^{
        [self.delegate connectionDidConnect:self];
    });
}

- (void)webSocket:(AVIMWebSocket *)webSocket didFailWithError:(NSError *)error
{
    AssertRunInQueue(self.serialQueue);
    NSParameterAssert(self.socket == webSocket);
    AVLoggerInfo(AVLoggerDomainIM, @"%@ closed with error: %@", webSocket, error);
    if ([error.domain isEqualToString:AVIMWebSocketErrorDomain]) {
        if (error.code == 2132) {
            // HTTP upgrade failed, maybe should use another server.
            self.useSecondaryServer = !self.useSecondaryServer;
        } else if (error.code == 2133) {
            // WebSocket protocol error, unexpectation error.
            [self tryClearConnectionWithEvent:error];
            return;
        }
    }
    [self handleWebSocketClosedWithError:error];
    if (self.isAutoReconnectionEnabled) {
        [self tryConnecting];
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    AssertRunInQueue(self.serialQueue);
    NSParameterAssert(self.socket == webSocket);
    NSDictionary *userInfo = @{ NSLocalizedFailureReasonErrorKey : (reason ?: @"unknown reason"),
                                @"wasClean" : @(wasClean) };
    NSError *error = [NSError errorWithDomain:AVIMWebSocketErrorDomain code:code userInfo:userInfo];
    AVLoggerInfo(AVLoggerDomainIM, @"%@ closed with error: %@", webSocket, error);
    [self handleWebSocketClosedWithError:error];
    if (!wasClean && self.isAutoReconnectionEnabled) {
        // not was clean means not close by server, so should try reconnecting.
        [self tryConnecting];
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceiveMessage:(id)message
{
    AssertRunInQueue(self.serialQueue);
    NSParameterAssert(self.socket == webSocket && self.timer);
    NSError *error = nil;
    AVIMGenericCommand *inCommand = [AVIMGenericCommand parseFromData:message error:&error];
    if (error) {
        AVLoggerError(AVLoggerDomainIM, @"%@", error);
        return;
    }
    AVLoggerDebug(AVLoggerDomainIM, LCIM_IN_COMMAND_LOG_FORMAT, [inCommand avim_description]);
    if (inCommand.hasI) {
        [self.timer handleCallbackCommand:inCommand];
    } else {
        dispatch_async(self.delegateQueue, ^{
            [self.delegate connection:self didReceiveCommand:inCommand];
        });
    }
}

- (void)webSocket:(AVIMWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    AssertRunInQueue(self.serialQueue);
    NSParameterAssert(self.socket == webSocket && self.timer);
    AVLoggerInfo(AVLoggerDomainIM, @"%@ pong received", webSocket);
    self.timer.lastPongReceivedTimestamp = [[NSDate date] timeIntervalSince1970];
}

@end
