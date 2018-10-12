//
//  AVApplication.m
//  AVOS
//
//  Created by zapcannon87 on 2018/9/20.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVApplication.h"

@implementation AVApplication

static AVApplication *sharedInstance = nil;

+ (instancetype)defaultApplication
{
    return sharedInstance;
}

+ (void)setDefaultApplication:(AVApplication *)application
{
    sharedInstance = application;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)initWithIdentifier:(NSString *)identifier key:(NSString *)key
{
    NSParameterAssert(identifier.length);
    NSParameterAssert(key.length);
    self = [super init];
    if (self) {
        self->_identifier = [identifier copy];
        self->_key = [key copy];
    }
    return self;
}

@end
