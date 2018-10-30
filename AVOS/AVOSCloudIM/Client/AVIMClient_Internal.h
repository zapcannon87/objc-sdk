//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMClient.h"
#import "AVIMCommon_Internal.h"
#import "AVIMWebSocketWrapper.h"

@class LCIMConversationCache;
@class AVIMClientInternalConversationManager;
@class AVIMClientPushManager;
@class AVIMSignature;
@class AVApplication;

@interface AVIMClientConfig : NSObject

@property (nonatomic, strong, readwrite) AVApplication *application;
@property (nonatomic, strong, readwrite) AVInstallation *installation;

@end

@interface AVIMClient () <AVIMWebSocketWrapperDelegate>

@property (nonatomic, strong, readonly) AVApplication *application;
@property (nonatomic, strong, readonly) AVIMClientPushManager *pushManager;
@property (nonatomic, strong, readonly) dispatch_queue_t internalSerialQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t signatureQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t userInteractQueue;
@property (nonatomic, strong, readonly) AVIMWebSocketWrapper *socketWrapper;
@property (nonatomic, strong, readonly) AVIMClientCacheOption *cacheOption;
@property (nonatomic, strong, readonly) AVIMClientInternalConversationManager *conversationManager;

+ (NSMutableDictionary *)sessionProtocolOptions;

- (instancetype)initWithConfig:(AVIMClientConfig *)config
                      clientId:(NSString *)clientId
                          user:(AVUser *)user
                           tag:(NSString *)tag
                   cacheOption:(AVIMClientCacheOption *)cacheOption;

- (void)addOperationToInternalSerialQueue:(void (^)(AVIMClient *client))block;

- (void)sendCommandWrapper:(LCIMProtobufCommandWrapper *)commandWrapper;

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
