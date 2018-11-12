//
//  AVIMConnectionProtocol.h
//  AVOS
//
//  Created by ZapCannon87 on 2018/10/30.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AVIMConnection;
@class AVIMGenericCommand;

NS_ASSUME_NONNULL_BEGIN

@protocol AVIMConnectionDelegate <NSObject>

- (void)connectionInConnecting:(AVIMConnection *)connection;

- (void)connectionDidConnect:(AVIMConnection *)connection;

- (void)connection:(AVIMConnection *)connection didFailInConnectingWithEvent:(id)Event;

- (void)connection:(AVIMConnection *)connection didDisconnectWithEvent:(id)Event;

- (void)connection:(AVIMConnection *)connection didReceiveCommand:(AVIMGenericCommand *)inCommand;

@end

NS_ASSUME_NONNULL_END
