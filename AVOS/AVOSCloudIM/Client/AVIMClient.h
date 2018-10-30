//
//  AVIM.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMClientProtocol.h"

@class AVIMConversation;
@class AVIMChatRoom;
@class AVIMServiceConversation;
@class AVIMTemporaryConversation;
@class AVIMKeyedConversation;
@class AVIMConversationQuery;
@class AVIMConversationCache;
@protocol AVIMSignatureDataSource;

NS_ASSUME_NONNULL_BEGIN

@interface AVIMClientCacheOption : NSObject

@property (nonatomic, assign, readwrite) BOOL conversationCacheEnabled;
@property (nonatomic, assign, readwrite) BOOL messageCacheEnabled;

@end

@interface AVIMClient : NSObject

/*!
 Set what server will issues for offline messages when client did login.
 
 @param enabled Set `YES` if you want server just issues the count of offline messages in each conversation.
 Set `NO` if you want server issues concrete offline messages.
 Defaults to `NO`.
 */
+ (void)setUnreadNotificationEnabled:(BOOL)enabled;

/*!
 * 设置实时通信的超时时间，默认 30 秒。
 * @param seconds 超时时间，单位是秒。
 */
+ (void)setTimeoutIntervalInSeconds:(NSTimeInterval)seconds;

/**
 No thread-safe for getter & setter. recommend setting after instantiation.
 */
@property (nonatomic, weak, readwrite, nullable) id<AVIMClientDelegate> delegate;

/*
 No thread-safe for getter & setter. recommend setting after instantiation.
 */
@property (nonatomic, weak, readwrite, nullable) id<AVIMSignatureDataSource> signatureDataSource;

/**
 The ID of this Client.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *clientId;

/**
 The `AVUser` of this Client.
 */
@property (nonatomic, strong, readonly, nullable) AVUser *user;

/**
 The Tag of this Client.
 */
@property (nonatomic, strong, readonly, nullable) NSString *tag;

/**
 The Status of this Client.
 */
@property (nonatomic, assign, readonly) AVIMClientStatus status;

/**
 The conversation cache manager of this client,
 If `conversationCacheEnabled` is false, then it's nil.
 */
@property (nonatomic, strong, readonly, nullable) AVIMConversationCache *conversationCache;

- (instancetype)init NS_UNAVAILABLE;

/**
 Initialization method.
 
 @note `clientId`'s length should in range [1, 64], and all characters must be letters, digits, or the underscore.
 
 @param clientId Identifie of this Client.
 @return Instance.
 */
- (instancetype)initWithClientId:(NSString *)clientId;

/**
 Initialization method.
 
 @note `clientId`'s length should in range [1, 64], and all characters must be letters, digits, or the underscore.
 @note `tag` should not use @"default".

 @param clientId Identifie of this Client.
 @param tag Set it to implement only one client online.
 @return Instance.
 */
- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString * _Nullable)tag;

- (instancetype)initWithClientId:(NSString *)clientId tag:(NSString * _Nullable)tag cacheOption:(AVIMClientCacheOption * _Nullable)cacheOption;

/**
 Initialization method.

 @param user The `AVUser` of this Client.
 @return Instance.
 */
- (instancetype)initWithUser:(AVUser *)user;

/**
 Initialization method.
 
 @note `tag` should not use @"default".

 @param user The `AVUser` of this Client.
 @param tag Set it to implement only one client online.
 @return Instance.
 */
- (instancetype)initWithUser:(AVUser *)user tag:(NSString * _Nullable)tag;

- (instancetype)initWithUser:(AVUser *)user tag:(NSString * _Nullable)tag cacheOption:(AVIMClientCacheOption * _Nullable)cacheOption;

/**
 Start a Session with Server.
 It is similar to Login.
 
 @param callback Result Callback.
 */
- (void)openWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 Start a Session with Server.
 It is similar to Login.
 
 @param openOption See more: `AVIMClientOpenOption`.
 @param callback Result Callback.
 */
- (void)openWithOption:(AVIMClientOpenOption)openOption
              callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/**
 End a Session with Server.
 It is similar to Logout.
 
 @param callback Result Callback.
 */
- (void)closeWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Create a new chat room conversation.
 
 @param name Name of the chat room.
 @param attributes Custom attributes of the chat room.
 @param callback Result of callback.
 */
- (void)createChatRoomWithName:(NSString * _Nullable)name
                    attributes:(NSDictionary * _Nullable)attributes
                      callback:(void (^)(AVIMChatRoom * _Nullable chatRoom, NSError * _Nullable error))callback;

/**
 Create a new temporary conversation.
 
 @param clientIds Member's client ID of conversation.
 @param ttl Use it to setup time to live of temporary conversation. it will not greater than a default max value(depend on server). if set Zero or Negtive, it will use max ttl, Unit of Measure: Second.
 @param callback Result of callback.
 */
- (void)createTemporaryConversationWithClientIds:(NSArray<NSString *> *)clientIds
                                      timeToLive:(int32_t)ttl
                                        callback:(void (^)(AVIMTemporaryConversation * _Nullable temporaryConversation, NSError * _Nullable error))callback;

/*!
 创建一个新的用户对话。
 在单聊的场合，传入对方一个 clientId 即可；群聊的时候，支持同时传入多个 clientId 列表
 @param name - 会话名称。
 @param clientIds - 聊天参与者（发起人除外）的 clientId 列表。
 @param attributes - 会话的自定义属性。
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param callback － 对话建立之后的回调
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/**
 Create a New Conversation.

 @param name Name of the Conversation.
 @param clientIds Array of Other Client's ID
 @param attributes Custom Attributes
 @param options Option of the Conversation's Type
 @param temporaryTTL Temporary Conversation's Time to Live, Unit of Measure: Second.
 @param callback Result callback
 */
- (void)createConversationWithName:(NSString * _Nullable)name
                         clientIds:(NSArray<NSString *> *)clientIds
                        attributes:(NSDictionary * _Nullable)attributes
                           options:(AVIMConversationOption)options
                      temporaryTTL:(int32_t)temporaryTTL
                          callback:(void (^)(AVIMConversation * _Nullable conversation, NSError * _Nullable error))callback;

/*!
 Query online clients within the given array of clients.

 @note Currently, It only supports to query 20 clients at most.

 @param clients  An array of clients you want to query.
 @param callback The callback of query.
 */
- (void)queryOnlineClientsInClients:(NSArray<NSString *> *)clients
                           callback:(void (^)(NSArray<NSString *> * _Nullable clientIds, NSError * _Nullable error))callback;

/*!
 构造一个对话查询对象
 @return 对话查询对象.
 */
- (AVIMConversationQuery *)conversationQuery;

@end

@interface AVIMClient (deprecated)

@property (nonatomic, assign, readwrite) BOOL messageQueryCacheEnabled __deprecated_msg("deprecated.");

+ (void)setUserOptions:(NSDictionary *)userOptions __deprecated_msg("deprecated.");

- (AVIMConversation * _Nullable)conversationForId:(NSString *)conversationId __deprecated_msg("deprecated.");

- (void)getConversationsFromMemoryWith:(NSArray<NSString *> *)conversationIds
                              callback:(void (^)(NSArray<AVIMConversation *> * _Nullable conversations))callback __deprecated_msg("deprecated.");

- (void)removeConversationsInMemoryWith:(NSArray<NSString *> *)conversationIds
                               callback:(void (^)(void))callback __deprecated_msg("deprecated.");

- (void)removeAllConversationsInMemoryWith:(void (^)(void))callback __deprecated_msg("deprecated.");

- (AVIMConversation * _Nullable)conversationWithKeyedConversation:(AVIMKeyedConversation *)keyedConversation __deprecated_msg("deprecated.");

@end

NS_ASSUME_NONNULL_END
