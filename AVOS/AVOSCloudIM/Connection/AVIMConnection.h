//
//  AVIMConnection.h
//  AVOS
//
//  Created by ZapCannon87 on 2018/10/30.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessagesProtoOrig.pbobjc.h"
#import "AVIMConnectionProtocol.h"

@class AVApplication;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * LCIMProtocol NS_TYPED_EXTENSIBLE_ENUM;
static LCIMProtocol const LCIMProtocolProtobuf1 = @"lc.protobuf2.1";
static LCIMProtocol const LCIMProtocolProtobuf3 = @"lc.protobuf2.3";

typedef NSString * AVIMConnectionEvent NS_TYPED_EXTENSIBLE_ENUM;
static AVIMConnectionEvent const AVIMConnectionEventDisconnectInvoked = @"DisconnectInvoked";
static AVIMConnectionEvent const AVIMConnectionEventAppInBackground = @"AppInBackground";
static AVIMConnectionEvent const AVIMConnectionEventNetworkNotReachable = @"NetworkNotReachable";
static AVIMConnectionEvent const AVIMConnectionEventNetworkChanged = @"NetworkChanged";

@interface AVIMConnectionInitConfig : NSObject

@property (nonatomic) AVApplication *application;
@property (nonatomic) id<AVIMConnectionDelegate> delegate;
@property (nonatomic) LCIMProtocol lcimProtocol;
// default is nil
@property (nonatomic, nullable) NSString *customRTMServer;
// default is main queue
@property (nonatomic) dispatch_queue_t delegateQueue;
// default is 30 seconds
@property (nonatomic) NSTimeInterval commandTTL;

@end

@interface AVIMConnection : NSObject

@property (nonatomic, strong, readonly) AVApplication *application;
@property (nonatomic, strong, readonly) LCIMProtocol lcimProtocol;
@property (nonatomic, weak, readwrite, nullable) id<AVIMConnectionDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) NSString *customRTMServer;
@property (nonatomic, strong, readonly) dispatch_queue_t delegateQueue;
@property (nonatomic, assign, readonly) NSTimeInterval commandTTL;

- (instancetype)initWithConfig:(AVIMConnectionInitConfig *)config;

- (void)connect;

- (void)disconnect;

- (void)setAutoReconnectionEnabled:(BOOL)enabled;

- (void)sendCommand:(AVIMGenericCommand *)outCommand callback:(void (^)(AVIMGenericCommand * _Nullable inCommand, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
