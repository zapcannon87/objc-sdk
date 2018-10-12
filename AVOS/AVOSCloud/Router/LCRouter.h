//
//  LCRouter.h
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * const RouterCacheKey NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT RouterCacheKey RouterCacheKeyApp;
FOUNDATION_EXPORT RouterCacheKey RouterCacheKeyRTM;

@interface LCRouter : NSObject

/**
 LCRouter is singleton in environment.
 */
+ (instancetype)sharedInstance;

- (instancetype)init NS_UNAVAILABLE;

/**
 Clean local cache of router.

 @param key Module key.
 @param error Can be nil.
 */
- (void)cleanCacheWithKey:(RouterCacheKey)key error:(NSError * __autoreleasing *)error;

/**
 Keep it for compatibility.
 */
- (NSString *)URLStringForPath:(NSString *)path __deprecated_msg("Deprecated! don't use it any more.");

@end

NS_ASSUME_NONNULL_END
