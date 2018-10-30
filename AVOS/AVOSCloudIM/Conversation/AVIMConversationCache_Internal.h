//
//  AVIMConversationCache_Internal.h
//  AVOS
//
//  Created by zapcannon87 on 2018/10/25.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationCache.h"
#import "AVIMCommon_Internal.h"

@class AVIMClient;

@interface AVIMConversationCache ()

- (instancetype)initWithClient:(AVIMClient *)client cacheEnabled:(BOOL)cacheEnabled;

- (AVIMConversation *)conversationForID:(NSString *)conversationID;
- (void)setConversation:(AVIMConversation *)conversation;

- (BOOL)insertOrReplaceConversation:(AVIMConversation *)conversation;
- (BOOL)updateConversation:(AVIMConversation *)conversation
                      keys:(NSArray<AVIMConversationCacheKey> *)keys
                    values:(NSArray *)values;

- (BOOL)changeAllCachedConversationsToShouldFetch;

@end
