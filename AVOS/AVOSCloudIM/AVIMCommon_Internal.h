//
//  AVIMCommon_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/7/27.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMCommon.h"

#if DEBUG
void assertContextOfQueue(dispatch_queue_t queue, BOOL isRunIn);
#define AssertRunInQueue(queue) assertContextOfQueue(queue, true);
#define AssertNotRunInQueue(queue) assertContextOfQueue(queue, false);
#else
#define AssertRunInQueue(queue)
#define AssertNotRunInQueue(queue)
#endif

/// { kAVIMUserOptionUseUnread: true } support unread notification feature. use `lc.protobuf2.3`
/// { kAVIMUserOptionUseUnread: false } not support unread notification feature. use `lc.protobuf2.1`
static NSString * const kAVIMUserOptionUseUnread = @"AVIMUserOptionUseUnread";

/// some limit
static NSUInteger const kClientIdLengthLimit = 64;
static NSString * const kClientTagDefault = @"default";
static NSString * const kTemporaryConversationIdPrefix = @"_tmp:";

/// @see https://github.com/leancloud/avoscloud-push/blob/develop/push-server/doc/protocol.md
typedef NS_OPTIONS(int64_t, LCIMSessionConfigOptions) {
    LCIMSessionConfigOptions_Patch = 1 << 0,
    LCIMSessionConfigOptions_TempConv = 1 << 1,
    LCIMSessionConfigOptions_AutoBindInstallation = 1 << 2,
    LCIMSessionConfigOptions_TransientACK = 1 << 3,
    LCIMSessionConfigOptions_ReliableNotification = 1 << 4,
    LCIMSessionConfigOptions_CallbackResultSlice = 1 << 5,
    LCIMSessionConfigOptions_GroupChatReadReceipt = 1 << 6,
};

/// RTM events notification type
typedef NSString * const RTMNotificationType NS_TYPED_EXTENSIBLE_ENUM;
static RTMNotificationType RTMNotificationTypePermanent = @"permanent";
static RTMNotificationType RTMNotificationTypeDroppable = @"droppable";

/// RTM events notification key
typedef NSString * const RTMNotificationKey NS_TYPED_EXTENSIBLE_ENUM;
static RTMNotificationKey RTMNotificationKeyNotifications = @"notifications";
static RTMNotificationKey RTMNotificationKeyInvalidLocalConvCache = @"invalidLocalConvCache";
static RTMNotificationKey RTMNotificationKeyHasMore = @"hasMore";
static RTMNotificationKey RTMNotificationKeyCmd = @"cmd";
static RTMNotificationKey RTMNotificationKeyOp = @"op";
static RTMNotificationKey RTMNotificationKeyCmdConv = @"conv";
static RTMNotificationKey RTMNotificationKeyCmdRcp = @"rcp";
static RTMNotificationKey RTMNotificationKeyOpJoined = @"joined";
static RTMNotificationKey RTMNotificationKeyOpLeft = @"left";
static RTMNotificationKey RTMNotificationKeyOpMembersJoined = @"members-joined";
static RTMNotificationKey RTMNotificationKeyOpMembersLeft = @"members-left";
static RTMNotificationKey RTMNotificationKeyOpShutuped = @"shutuped";
static RTMNotificationKey RTMNotificationKeyOpUnshutuped = @"unshutuped";
static RTMNotificationKey RTMNotificationKeyOpMembersShutuped = @"members-shutuped";
static RTMNotificationKey RTMNotificationKeyOpMembersUnshutuped = @"members-unshutuped";
static RTMNotificationKey RTMNotificationKeyOpBlocked = @"blocked";
static RTMNotificationKey RTMNotificationKeyOpUnblocked = @"unblocked";
static RTMNotificationKey RTMNotificationKeyOpMembersBlocked = @"members-blocked";
static RTMNotificationKey RTMNotificationKeyOpMembersUnblocked = @"members-unblocked";
static RTMNotificationKey RTMNotificationKeyOpUpdated = @"updated";
static RTMNotificationKey RTMNotificationKeyOpMemberInfoChanged = @"member-info-changed";

/// conversation property key
typedef NSString * const AVIMConversationKey NS_TYPED_EXTENSIBLE_ENUM;
static AVIMConversationKey AVIMConversationKeyObjectId = @"objectId";
static AVIMConversationKey AVIMConversationKeyUniqueId = @"uniqueId";
static AVIMConversationKey AVIMConversationKeyName = @"name";
static AVIMConversationKey AVIMConversationKeyCreator = @"c";
static AVIMConversationKey AVIMConversationKeyCreatedAt = @"createdAt";
static AVIMConversationKey AVIMConversationKeyUpdatedAt = @"updatedAt";
static AVIMConversationKey AVIMConversationKeyLastMessageAt = @"lm";
static AVIMConversationKey AVIMConversationKeyAttributes = @"attr";
static AVIMConversationKey AVIMConversationKeyMembers = @"m";
static AVIMConversationKey AVIMConversationKeyMutedMembers = @"mu";
static AVIMConversationKey AVIMConversationKeyUnique = @"unique";
static AVIMConversationKey AVIMConversationKeyTransient = @"tr";
static AVIMConversationKey AVIMConversationKeySystem = @"sys";
static AVIMConversationKey AVIMConversationKeyTemporary = @"temp";
static AVIMConversationKey AVIMConversationKeyTemporaryTTL = @"ttl";
static AVIMConversationKey AVIMConversationKeyConvType = @"conv_type";
static AVIMConversationKey AVIMConversationKeyLastMessageContent = @"msg";
static AVIMConversationKey AVIMConversationKeyLastMessageId = @"msg_mid";
static AVIMConversationKey AVIMConversationKeyLastMessageFrom = @"msg_from";
static AVIMConversationKey AVIMConversationKeyLastMessageTimestamp = @"msg_timestamp";
static AVIMConversationKey AVIMConversationKeyLastMessagePatchTimestamp = @"patch_timestamp";
static AVIMConversationKey AVIMConversationKeyLastMessageBinary = @"bin";
static AVIMConversationKey AVIMConversationKeyLastMessageMentionAll = @"mention_all";
static AVIMConversationKey AVIMConversationKeyLastMessageMentionPids = @"mention_pids";

/// Use this enum to match command's value(`convType`)
typedef NS_ENUM(NSUInteger, LCIMConvType) {
    LCIMConvTypeNormal = 1,
    LCIMConvTypeTransient = 2,
    LCIMConvTypeSystem = 3,
    LCIMConvTypeTemporary = 4,
};

typedef NSString * const AVIMConversationMemberInfoKey NS_TYPED_EXTENSIBLE_ENUM;
static AVIMConversationMemberInfoKey AVIMConversationMemberInfoKeyConversationId = @"cid";
static AVIMConversationMemberInfoKey AVIMConversationMemberInfoKeyMemberId = @"clientId";
static AVIMConversationMemberInfoKey AVIMConversationMemberInfoKeyRole = @"role";

typedef NSString * const AVIMConversationMemberRoleKey NS_TYPED_EXTENSIBLE_ENUM;
static AVIMConversationMemberRoleKey AVIMConversationMemberRoleKeyMember = @"Member";
static AVIMConversationMemberRoleKey AVIMConversationMemberRoleKeyManager = @"Manager";
static AVIMConversationMemberRoleKey AVIMConversationMemberRoleKeyOwner = @"Owner";
