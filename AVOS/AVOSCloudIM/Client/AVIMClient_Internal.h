//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon_Internal.h"
#import "AVIMClient.h"
#import "AVIMWebSocketWrapper.h"

@class LCIMConversationCache;
@class AVIMClientInternalConversationManager;
@class AVIMClientPushManager;

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

@property (nonatomic, strong, readonly) dispatch_queue_t internalSerialQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t signatureQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t userInteractQueue;
@property (nonatomic, strong, readonly) AVIMWebSocketWrapper *socketWrapper;
@property (nonatomic, strong, readonly) AVIMClientInternalConversationManager *conversationManager;
@property (nonatomic, strong, readonly) AVIMClientPushManager *pushManager;
@property (nonatomic, strong, readonly) LCIMConversationCache *conversationCache;

@property (nonatomic, assign) BOOL offLineEventsNotificationEnabled;

+ (NSMutableDictionary *)sessionProtocolOptions;

- (instancetype)initWithClientId:(NSString *)clientId
                             tag:(NSString *)tag
                    installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (instancetype)initWithUser:(AVUser *)user
                         tag:(NSString *)tag
                installation:(AVInstallation *)installation LC_WARN_UNUSED_RESULT;

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;
- (void)sendCommand:(AVIMGenericCommand *)command;

- (void)getSignatureWithConversationId:(NSString *)conversationId
                                action:(AVIMSignatureAction)action
                     actionOnClientIds:(NSArray<NSString *> *)actionOnClientIds
                              callback:(void (^)(AVIMSignature *signature))callback;

- (void)getSessionTokenWithForcingRefresh:(BOOL)forcingRefresh
                                 callback:(void (^)(NSString *sessionToken, NSError *error))callback;

- (void)conversation:(AVIMConversation *)conversation didUpdateForKeys:(NSArray<AVIMConversationUpdatedKey> *)keys;

- (void)fetchRTMNotificationsWithSessionToken:(NSString *)sessionToken
                                     clientId:(NSString *)clientId
                                    timestamp:(int64_t)timestamp
                             notificationType:(RTMNotificationType)notificationType
                                     callback:(void (^)(NSDictionary *dictionary, NSError *error))callback;

@end
