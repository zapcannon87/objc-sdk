//
//  AVIMConversation.h
//  AVOSCloudIM
//
//  Created by Qihe Bian on 12/4/14.
//  Copyright (c) 2014 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"
#import "AVIMMessage.h"
#import "AVIMMessageOption.h"

@class AVIMClient;
@class AVIMKeyedConversation;
@class AVIMRecalledMessage;
@class AVIMConversationMemberInfo;

NS_ASSUME_NONNULL_BEGIN

@interface AVIMMessageIntervalBound : NSObject

@property (nonatomic, copy, nullable) NSString *messageId;
@property (nonatomic, assign) int64_t timestamp;
@property (nonatomic, assign) BOOL closed;

- (instancetype)initWithMessageId:(nullable NSString *)messageId
                        timestamp:(int64_t)timestamp
                           closed:(BOOL)closed;

@end

@interface AVIMMessageInterval : NSObject

@property (nonatomic, strong) AVIMMessageIntervalBound *startIntervalBound;
@property (nonatomic, strong, nullable) AVIMMessageIntervalBound *endIntervalBound;

- (instancetype)initWithStartIntervalBound:(AVIMMessageIntervalBound *)startIntervalBound
                          endIntervalBound:(nullable AVIMMessageIntervalBound *)endIntervalBound;

@end

@interface AVIMOperationFailure : NSObject

@property (nonatomic, assign) NSInteger code;
@property (nonatomic, strong, nullable) NSString *reason;
@property (nonatomic, strong, nullable) NSArray<NSString *> *clientIds;

@end

@interface AVIMConversation : NSObject

/**
 The client which this conversation belongs to.
 */
@property (nonatomic, weak, readonly, nullable) AVIMClient *imClient;

/**
 The ID of the client.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *clientId;

/**
 The ID of the conversation.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *conversationId;

/**
 Unique ID of conversation, only unique conversation has this property.
 */
@property (nonatomic, strong, readonly, nullable) NSString *uniqueId;

/**
 The creator of the conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSString *creator;

/**
 The creation date of the conversation.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *createAt;

/**
 Indicating whether it is a unique conversation.
 @note only 0 or 1 property in [unique, transient, system, temporary] is true.
 */
@property (nonatomic, assign, readonly) BOOL unique;

/**
 Indicating whether it is a Chat Room.
 @note only 0 or 1 property in [unique, transient, system, temporary] is true.
 */
@property (nonatomic, assign, readonly) BOOL transient;

/**
 Indicating whether it is a Service Conversation.
 @note only 0 or 1 property in [unique, transient, system, temporary] is true.
 */
@property (nonatomic, assign, readonly) BOOL system;

/**
 Indicating whether it is a Temporary Conversation.
 @note only 0 or 1 property in [unique, transient, system, temporary] is true.
 */
@property (nonatomic, assign, readonly) BOOL temporary;

/**
 Temporary Conversation's Time to Live. only Temporary Conversation has a valid value.
 */
@property (nonatomic, assign, readonly) NSUInteger temporaryTTL;

/**
 The last updated date of the conversation,
 When fields like name, members, attributes ... changed, this value in server will changed.
 */
@property (nonatomic, strong, readonly, nullable) NSDate *updateAt;

/**
 The last message in this conversation.
 @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:].
 */
@property (nonatomic, strong, readonly, nullable) AVIMMessage *lastMessage;

/**
 The sent date of the last message in this conversation.
 @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:].
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastMessageAt;

/**
 The last date of this client ID's message read by other.
 @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:], -[self fetchReceiptTimestampsInBackground].
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastReadAt;

/**
 The last date of this client ID's message delivered to other.
  @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:], -[self fetchReceiptTimestampsInBackground].
 */
@property (nonatomic, strong, readonly, nullable) NSDate *lastDeliveredAt;

/**
 The count of unread messages in this conversation.
 @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:].
 */
@property (nonatomic, assign, readonly) NSUInteger unreadMessagesCount;

/**
 Indicating whether has one or more unread message mentioned this client ID,
 Should set this property to `false` when read the message.
 @note See-Also: AVIMConversationUpdatedKey, -[AVIMClientDelegate conversation:didUpdateForKey:].
 */
@property (nonatomic, assign) BOOL unreadMessagesMentioned;

/**
 Indicating whether this conversation's data maybe not sync with server's data,
 When this conversation did fetch or did query, this property will be `true`.
 */
@property (nonatomic, assign, readonly) BOOL shouldFetch;

/**
 The member's ID of this conversation.
 @note See-Also: -[self joinWithCallback:], -[self quitWithCallback:],
 -[self addMembersWithClientIds:callback:], -[self removeMembersWithClientIds:callback:],
 -[AVIMClientDelegate conversation:invitedByClientId:], -[AVIMClientDelegate conversation:kickedByClientId:],
 -[AVIMClientDelegate conversation:membersAdded:byClientId:], -[AVIMClientDelegate conversation:membersRemoved:byClientId:].
 */
@property (nonatomic, strong, readonly, nullable) NSArray<NSString *> *members;

/**
 The member's ID of which has mute this conversation.
 @note See-Also: muted, -[self muteWithCallback:], -[self unmuteWithCallback:].
 */
@property (nonatomic, strong, readonly, nullable) NSArray<NSString *> *mutedMembers;

/**
 Muting status of this client ID in this conversation.
 If this property is true(`mutedMembers` contains this client ID), then all device opened by this client ID will not receive system's notification when this client ID has offline messages.
 @note See-Also: mutedMembers, -[self muteWithCallback:], -[self unmuteWithCallback:].
 */
@property (nonatomic, assign, readonly) BOOL muted;

/**
 The name of this conversation.
 @note See-Also: -[self updateWithCallback:].
 */
@property (nonatomic, strong, readonly, nullable) NSString *name;

/**
 The attributes of the conversation, apply to saving any extra data of the conversation.
 @note See-Also: -[self updateWithCallback:].
 */
@property (nonatomic, strong, readonly, nullable) NSDictionary *attributes;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Add custom property for conversation.
 *
 * @param object The property value.
 * @param key    The property name.
 */
- (void)setObject:(id _Nullable)object forKey:(NSString *)key;

/**
 * Support to use subscript to set custom property.
 *
 * @see -[AVIMConversation setObject:forKey:]
 */
- (void)setObject:(id _Nullable)object forKeyedSubscript:(NSString *)key;

/*!
 * Get custom property value for conversation.
 *
 * @param key The custom property name.
 *
 * @return The custom property value.
 */
- (id _Nullable)objectForKey:(NSString *)key;

/**
 * Support to use subscript to set custom property.
 *
 * @see -[AVIMConversation objectForKey:]
 */
- (id _Nullable)objectForKeyedSubscript:(NSString *)key;

/*!
 创建一个 AVIMKeyedConversation 对象。用于序列化，方便保存在本地。
 @return AVIMKeyedConversation 对象。
 */
- (AVIMKeyedConversation * _Nullable)keyedConversation;

// MARK: - RCP Timestamps & Read

/*!
 拉取对话最近的回执时间。
 */
- (void)fetchReceiptTimestampsInBackground;

/*!
 将对话标记为已读。
 该方法将本地对话中其他成员发出的最新消息标记为已读，该消息的发送者会收到已读通知。
 */
- (void)readInBackground;

// MARK: - Conversation Update

/*!
 拉取服务器最新数据。
 @param callback － 结果回调
 */
- (void)fetchWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 发送更新。
 @param callback － 结果回调
 */
- (void)updateWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Conversation Mute

/*!
 静音，不再接收此对话的离线推送。
 @param callback － 结果回调
 */
- (void)muteWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 取消静音，开始接收此对话的离线推送。
 @param callback － 结果回调
 */
- (void)unmuteWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Members

/*!
 加入对话。
 @param callback － 结果回调
 */
- (void)joinWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 离开对话。
 @param callback － 结果回调
 */
- (void)quitWithCallback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 邀请新成员加入对话。
 @param clientIds － 成员列表
 @param callback － 结果回调
 */
- (void)addMembersWithClientIds:(NSArray<NSString *> *)clientIds
                       callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 从对话踢出部分成员。
 @param clientIds － 成员列表
 @param callback － 结果回调
 */
- (void)removeMembersWithClientIds:(NSArray<NSString *> *)clientIds
                          callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 查询成员人数（开放群组即为在线人数）。
 @param callback － 结果回调
 */
- (void)countMembersWithCallback:(void (^)(NSInteger count, NSError * _Nullable error))callback;

// MARK: - Message Send

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param option － 消息发送选项
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
             option:(AVIMMessageOption * _Nullable)option
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
      progressBlock:(void (^ _Nullable)(NSInteger progress))progressBlock
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param option － 消息发送选项
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
             option:(nullable AVIMMessageOption *)option
      progressBlock:(void (^ _Nullable)(NSInteger progress))progressBlock
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Message Update

/*!
 Replace a message you sent with a new message.

 @param oldMessage The message you've sent which will be replaced by newMessage.
 @param newMessage A new message.
 @param callback   Callback of message update.
 */
- (void)updateMessage:(AVIMMessage *)oldMessage
         toNewMessage:(AVIMMessage *)newMessage
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

/*!
 Recall a message.

 @param oldMessage The message you've sent which will be replaced by newMessage.
 @param callback   Callback of message update.
 */
- (void)recallMessage:(AVIMMessage *)oldMessage
             callback:(void (^)(BOOL succeeded, NSError * _Nullable error, AVIMRecalledMessage * _Nullable recalledMessage))callback;

// MARK: - Message Cache

/*!
 Add a message to cache.

 @param message The message to be cached.
 */
- (void)addMessageToCache:(AVIMMessage *)message;

/*!
 Remove a message from cache.

 @param message The message which you want to remove from cache.
 */
- (void)removeMessageFromCache:(AVIMMessage *)message;

// MARK: - Message Query

/*!
 从服务端拉取该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 */
- (void)queryMessagesFromServerWithLimit:(NSUInteger)limit
                                callback:(void (^)(NSArray<AVIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/*!
 从缓存中查询该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @return 消息数组。
 */
- (NSArray *)queryMessagesFromCacheWithLimit:(NSUInteger)limit;

/*!
 获取该会话的最近 limit 条消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 */
- (void)queryMessagesWithLimit:(NSUInteger)limit
                      callback:(void (^)(NSArray<AVIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/*!
 查询历史消息，获取某条消息之前的 limit 条消息。
 @warning `timestamp` must equal to the timestamp of the message that messageId equal to `messageId`, if the `timestamp` and `messageId` not match, continuity of querying message can't guarantee.
 
 @param messageId 此消息以前的消息。
 @param timestamp 此时间以前的消息。
 @param limit 返回结果的数量，默认 20 条，最多 1000 条。
 @param callback 查询结果回调。
 */
- (void)queryMessagesBeforeId:(NSString *)messageId
                    timestamp:(int64_t)timestamp
                        limit:(NSUInteger)limit
                     callback:(void (^)(NSArray<AVIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/**
 Query messages from a message to an another message with specified direction applied.

 @param interval  A message interval.
 @param direction Direction of message query.
 @param limit     Limit of messages you want to query.
 @param callback  Callback of query request.
 */
- (void)queryMessagesInInterval:(AVIMMessageInterval *)interval
                      direction:(AVIMMessageQueryDirection)direction
                          limit:(NSUInteger)limit
                       callback:(void (^)(NSArray<AVIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

/**
 Query Specific Media Type Message from Server.

 @param type Specific Media Type you want to query, see `AVIMMessageMediaType`.
 @param limit Limit of messages you want to query.
 @param messageId If set it and MessageId is Valid, the Query Result is Decending base on Timestamp and will Not Include the Message that its messageId is this parameter.
 @param timestamp Set Zero or Negative, it will query from latest Message and result include the latest Message; Set a valid timestamp, the Query Result is Decending base on Timestamp and will Not Include the Message that its timestamp is this parameter.
 @param callback Result callback.
 */
- (void)queryMediaMessagesFromServerWithType:(AVIMMessageMediaType)type
                                       limit:(NSUInteger)limit
                               fromMessageId:(NSString * _Nullable)messageId
                               fromTimestamp:(int64_t)timestamp
                                    callback:(void (^)(NSArray<AVIMMessage *> * _Nullable messages, NSError * _Nullable error))callback;

// MARK: - Member Info

/**
 Get all member info. using cache as a default.

 @param callback Result callback.
 */
- (void)getAllMemberInfoWithCallback:(void (^)(NSArray<AVIMConversationMemberInfo *> * _Nullable memberInfos, NSError * _Nullable error))callback;

/**
 Get all member info.

 @param ignoringCache Cache option.
 @param callback Result callback.
 */
- (void)getAllMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                                 callback:(void (^)(NSArray<AVIMConversationMemberInfo *> * _Nullable memberInfos, NSError * _Nullable error))callback;

/**
 Get a member info by member id. using cache as a default.

 @param memberId Equal to client id.
 @param callback Result callback.
 */
- (void)getMemberInfoWithMemberId:(NSString *)memberId
                         callback:(void (^)(AVIMConversationMemberInfo * _Nullable memberInfo, NSError * _Nullable error))callback;

/**
 Get a member info by member id.

 @param ignoringCache Cache option.
 @param memberId Equal to client id.
 @param callback Result callback.
 */
- (void)getMemberInfoWithIgnoringCache:(BOOL)ignoringCache
                              memberId:(NSString *)memberId
                              callback:(void (^)(AVIMConversationMemberInfo * _Nullable memberInfo, NSError * _Nullable error))callback;

/**
 Change a member's role.

 @param memberId Equal to client id.
 @param role Changing role.
 @param callback Result callback.
 */
- (void)updateMemberRoleWithMemberId:(NSString *)memberId
                                role:(AVIMConversationMemberRole)role
                            callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

// MARK: - Member Block

/**
 Blocking some members in the conversation.

 @param memberIds Who will be blocked.
 @param callback Result callback.
 */
- (void)blockMembers:(NSArray<NSString *> *)memberIds
            callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<AVIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Unblocking some members in the conversation.

 @param memberIds Who will be unblocked.
 @param callback Result callback.
 */
- (void)unblockMembers:(NSArray<NSString *> *)memberIds
              callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<AVIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Query blocked members in the conversation.

 @param limit Count of the blocked members you want to query.
 @param next Offset, if callback's next is nil or empty, that means there is no more blocked members.
 @param callback Result callback.
 */
- (void)queryBlockedMembersWithLimit:(NSInteger)limit
                                next:(NSString * _Nullable)next
                            callback:(void (^)(NSArray<NSString *> * _Nullable blockedMemberIds, NSString * _Nullable next, NSError * _Nullable error))callback;

// MARK: - Member Mute

/**
 Muting some members in the conversation.
 
 @param memberIds Who will be muted.
 @param callback Result callback.
 */
- (void)muteMembers:(NSArray<NSString *> *)memberIds
           callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<AVIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Unmuting some members in the conversation.
 
 @param memberIds Who will be unmuted.
 @param callback Result callback.
 */
- (void)unmuteMembers:(NSArray<NSString *> *)memberIds
             callback:(void (^)(NSArray<NSString *> * _Nullable successfulIds, NSArray<AVIMOperationFailure *> * _Nullable failedIds, NSError * _Nullable error))callback;

/**
 Query muted members in the conversation.
 
 @param limit Count of the muted members you want to query.
 @param next Offset, if callback's next is nil or empty, that means there is no more muted members.
 @param callback Result callback.
 */
- (void)queryMutedMembersWithLimit:(NSInteger)limit
                              next:(NSString * _Nullable)next
                          callback:(void (^)(NSArray<NSString *> * _Nullable mutedMemberIds, NSString * _Nullable next, NSError * _Nullable error))callback;

@end

@interface AVIMChatRoom : AVIMConversation

@end

@interface AVIMServiceConversation : AVIMConversation

/**
 Add ID of conversation's client to conversation's members.

 @param callback Result callback.
 */
- (void)subscribeWithCallback:(void(^)(BOOL, NSError * _Nullable))callback;

/**
 Remove ID of conversation's client from conversation's members.
 
 @param callback Result callback.
 */
- (void)unsubscribeWithCallback:(void(^)(BOOL, NSError * _Nullable))callback;

@end

@interface AVIMTemporaryConversation : AVIMConversation

@end

@interface AVIMConversation (deprecated)

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback __deprecated_msg("deprecated. use -[sendMessage:option:callback:] instead.");

/*!
 往对话中发送消息。
 @param message － 消息对象
 @param options － 可选参数，可以使用或 “|” 操作表示多个选项
 @param progressBlock - 发送进度回调。仅对文件上传有效，发送文本消息时不进行回调。
 @param callback － 结果回调
 */
- (void)sendMessage:(AVIMMessage *)message
            options:(AVIMMessageSendOption)options
      progressBlock:(nullable AVIMProgressBlock)progressBlock
           callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback __deprecated_msg("deprecated. use -[sendMessage:option:progressBlock:callback:] instead.");

/*!
 发送更新。
 @param updateDict － 需要更新的数据，可通过 AVIMConversationUpdateBuilder 生成
 @param callback － 结果回调
 */
- (void)update:(NSDictionary *)updateDict
      callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback __deprecated_msg("deprecated. use -[updateWithCallback:] instead.");

/*!
 标记该会话已读。
 将服务端该会话的未读消息数置零。
 */
- (void)markAsReadInBackground __deprecated_msg("deprecated. use -[readInBackground] instead.");

@end

NS_ASSUME_NONNULL_END
