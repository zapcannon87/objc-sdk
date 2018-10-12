//
//  AVApplication.h
//  AVOS
//
//  Created by zapcannon87 on 2018/9/20.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVApplication : NSObject

+ (instancetype)defaultApplication;
+ (void)setDefaultApplication:(AVApplication *)application;

@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) NSString *key;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(NSString *)identifier key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
