//
//  AVIMConversationCache.h
//  AVOS
//
//  Created by zapcannon87 on 2018/10/25.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVIMConversation;

NS_ASSUME_NONNULL_BEGIN

@interface AVIMConversationCache : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (void)queryCachedConversationsOrderByIDs:(NSArray<NSString *> *)orderlyIDs
                                  callback:(void (^)(NSArray<AVIMConversation *> * _Nullable orderlyResults, NSError * _Nullable error))callback;

- (void)queryCachedConversationsOrderByLastMessageTimestampWithCallback:(void (^)(NSArray<AVIMConversation *> * _Nullable orderlyResults, NSError * _Nullable error))callback;

- (void)removeConversationsWithIDs:(NSArray<NSString *> *)conversationIDs
                          callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback;

@end

NS_ASSUME_NONNULL_END
