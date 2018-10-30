//
//  AVIMConversationCache.m
//  AVOS
//
//  Created by zapcannon87 on 2018/10/25.
//  Copyright © 2018 LeanCloud Inc. All rights reserved.
//

#import "AVIMConversationCache_Internal.h"
#import "AVIMClient_Internal.h"
#import "AVIMConversation_Internal.h"
#import "LCDB.h"
#import "AVPersistenceUtils.h"
#import "AVApplication.h"
#import "AVErrorUtils.h"

static NSArray<NSString *> * ConversationTableOrderlyKeys()
{
    // can be reused in all probability, so cache it.
    static NSArray<NSString *> *array = nil;
    if (!array) {
        array = ({
            @[// TEXT
              AVIMConversationCacheKeyConversationID, AVIMConversationCacheKeyUniqueID, AVIMConversationCacheKeyCreator, AVIMConversationCacheKeyCreateAt,
              // INTEGER
              AVIMConversationCacheKeyUnique, AVIMConversationCacheKeySystem,
              // TEXT
              AVIMConversationCacheKeyUpdateAt,
              // BLOB
              AVIMConversationCacheKeyLastMessage,
              // REAL
              AVIMConversationCacheKeyLastMessageAt, AVIMConversationCacheKeyLastReadAt, AVIMConversationCacheKeyLastDeliveredAt,
              // INTEGER
              AVIMConversationCacheKeyUnreadMessagesCount, AVIMConversationCacheKeyUnreadMessagesMentioned, AVIMConversationCacheKeyShouldFetch,
              // TEXT
              AVIMConversationCacheKeyMembers, AVIMConversationCacheKeyMutedMembers, AVIMConversationCacheKeyName,
              // BLOB
              AVIMConversationCacheKeyAttributes];
        });
#if DEBUG
        // just a constraint of array count for debug.
        assert(array.count == 18);
#endif
    }
    return array;
}

static NSString * SQLCreateConversationTable()
{
    // using once in all probability, so not cache it.
    NSArray<NSString *> *keys = ConversationTableOrderlyKeys();
    return [NSString stringWithFormat:
            @"CREATE TABLE IF NOT EXISTS %@ "
            "("
            "%@ TEXT PRIMARY KEY," "%@ TEXT," "%@ TEXT," "%@ TEXT,"
            "%@ INTEGER," "%@ INTEGER,"
            "%@ TEXT,"
            "%@ BLOB,"
            "%@ REAL," "%@ REAL," "%@ REAL,"
            "%@ INTEGER," "%@ INTEGER," "%@ INTEGER,"
            "%@ TEXT," "%@ TEXT," "%@ TEXT,"
            "%@ BLOB"
            ")",
            AVIMLocalDBTableNameConversation,
            keys[0], keys[1], keys[2], keys[3], keys[4], keys[5],
            keys[6], keys[7], keys[8], keys[9], keys[10], keys[11],
            keys[12], keys[13], keys[14], keys[15], keys[16], keys[17]];
}

static NSString * SQLInsertOrReplaceIntoConversation()
{
    // can be reused in all probability, so cache it.
    static NSString *sql = nil;
    if (!sql) {
        NSArray<NSString *> *keys = ConversationTableOrderlyKeys();
        sql = [NSString stringWithFormat:
               @"INSERT OR REPLACE INTO %@ "
               "(%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@) "
               "VALUES "
               "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
               AVIMLocalDBTableNameConversation,
               keys[0], keys[1], keys[2], keys[3], keys[4], keys[5],
               keys[6], keys[7], keys[8], keys[9], keys[10], keys[11],
               keys[12], keys[13], keys[14], keys[15], keys[16], keys[17]];
    }
    return sql;
}

@interface AVIMConversationCache ()

@property (nonatomic, weak, readonly, nullable) AVIMClient *client;
@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t queue;
@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t callbackQueue;
@property (nonatomic, strong, readonly, nonnull) NSMutableDictionary<NSString *, AVIMConversation *> *conversationMap;
@property (nonatomic, strong, readonly, nullable) LCDatabase *db;

@end

@implementation AVIMConversationCache

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)initWithClient:(AVIMClient *)client cacheEnabled:(BOOL)cacheEnabled
{
    NSParameterAssert(client.internalSerialQueue && client.application.identifier && client.clientId);
    self = [super init];
    if (self) {
        self->_client = client;
        self->_queue = client.internalSerialQueue;
        self->_callbackQueue = dispatch_get_main_queue();
        self->_conversationMap = [NSMutableDictionary dictionary];
        if (cacheEnabled) {
            NSString *appID = client.application.identifier;
            NSString *directoryPath = [AVPersistenceUtils directoryPathOfConversationWithAppID:appID autoCreate:true];
            NSString *dbName = [NSString stringWithFormat:@"%@.db", ({
                NSData *data = [client.clientId dataUsingEncoding:NSUTF8StringEncoding];
                [data base64EncodedStringWithOptions:0];
            })];
            NSString *dbPath = [directoryPath stringByAppendingPathComponent:dbName];
            if (dbPath.length) {
                LCDatabase *db = [LCDatabase databaseWithPath:dbPath];
                if ([db open]) {
                    if ([db executeUpdate:SQLCreateConversationTable()]) {
                        NSString *sqlCreateIndexForConversationLastMessageAt = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@_%@ ON %@(%@)", AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyLastMessageAt, AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyLastMessageAt];
                        if ([db executeUpdate:sqlCreateIndexForConversationLastMessageAt]) {
                            self->_db = db;
                        } else {
                            AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> create index on %@ for %@ failed: %@.", db, AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyLastMessageAt, db.lastError);
                        }
                    } else {
                        AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> create %@ table failed: %@.", db, AVIMLocalDBTableNameConversation , db.lastError);
                    }
                } else {
                    AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> open failed: %@.", db, db.lastError);
                }
            } else {
                AVLoggerError(AVLoggerDomainIM, @"not get path of DB.");
            }
        }
    }
    return self;
}

// MARK: - Memory

- (AVIMConversation *)conversationForID:(NSString *)conversationID
{
    AssertRunInQueue(self.queue);
    NSParameterAssert(conversationID);
    return self.conversationMap[conversationID];
}

- (void)setConversation:(AVIMConversation *)conversation
{
    AssertRunInQueue(self.queue);
    NSParameterAssert(conversation.conversationId);
    self.conversationMap[conversation.conversationId] = conversation;
}

// MARK: - Local Cache

- (BOOL)insertOrReplaceConversation:(AVIMConversation *)conversation
{
    AssertRunInQueue(self.queue);
    NSParameterAssert(conversation.conversationId);
    BOOL succeeded = true;
    if (self.db) {
        switch (conversation.convType) {
            case LCIMConvTypeNormal:
            case LCIMConvTypeSystem: {
                NSString *sqlInsertOrReplaceIntoConversation = SQLInsertOrReplaceIntoConversation();
                // TODO: get values from conversation.
                NSArray *values = nil;
                succeeded = [self.db executeUpdate:sqlInsertOrReplaceIntoConversation withArgumentsInArray:values];
                if (!succeeded) {
                    AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> insert or replace into %@ failed: %@.", self.db, AVIMLocalDBTableNameConversation, self.db.lastError);
                }
            } break;
            default: break;
        }
    }
    return succeeded;
}

- (BOOL)updateConversation:(AVIMConversation *)conversation
                      keys:(NSArray<AVIMConversationCacheKey> *)keys
                    values:(NSArray *)values
{
    AssertRunInQueue(self.queue);
    NSParameterAssert(conversation.conversationId && keys.count > 0 && keys.count == values.count);
    BOOL succeeded = true;
    if (self.db) {
        NSString *columnNames = [keys componentsJoinedByString:@","];
        NSString *bindMarks = ({
            NSMutableArray<NSString *> *array = [NSMutableArray arrayWithCapacity:keys.count];
            for (__unused NSString *unused in keys) {
                [array addObject:@"?"];
            }
            [array componentsJoinedByString:@","];
        });
        NSString *sqlUpdateConversationSet = [NSString stringWithFormat:@"UPDATE %@ SET (%@) = (%@) WHERE %@ = ?", AVIMLocalDBTableNameConversation, columnNames, bindMarks, AVIMConversationCacheKeyConversationID];
        NSMutableArray *args = [NSMutableArray arrayWithArray:values];
        [args addObject:conversation.conversationId];
        succeeded = [self.db executeUpdate:sqlUpdateConversationSet withArgumentsInArray:args];
        if (!succeeded) {
            AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> update %@ set: %@ where: %@ failed: %@.", self.db, AVIMLocalDBTableNameConversation, columnNames, conversation.conversationId, self.db.lastError);
        }
    }
    return succeeded;
}

- (BOOL)changeAllCachedConversationsToShouldFetch
{
    AssertRunInQueue(self.queue);
    BOOL succeeded = true;
    if (self.db) {
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET (%@) = (?)", AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyShouldFetch];
        succeeded = [self.db executeUpdate:sql, @(true)];
        if (!succeeded) {
            AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> update %@ set(%@) = (true) failed: %@.", self.db, AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyShouldFetch, self.db.lastError);
        }
    }
    return succeeded;
}

// MARK: - API

- (void)queryCachedConversationsOrderByIDs:(NSArray<NSString *> *)orderlyIDs
                                  callback:(void (^)(NSArray<AVIMConversation *> * _Nullable orderlyResults, NSError * _Nullable error))callback
{
    NSParameterAssert(orderlyIDs.count > 0 && orderlyIDs.count == [NSSet setWithArray:orderlyIDs].count);
    dispatch_async(self.queue, ^{
        if (self.db) {
            NSString *whereIn = [orderlyIDs componentsJoinedByString:@","];
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@ IN (%@)", AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyConversationID, whereIn];
            LCResultSet *set = [self.db executeQuery:sql];
            if (set) {
                while ([set next]) {
                    NSString *conversationID = [set stringForColumn:AVIMConversationCacheKeyConversationID];
                    if (!conversationID) { continue; }
                    // TODO: get conversation from set data.
                    AVIMConversation *conversation = nil;
                    self.conversationMap[conversationID] = conversation;
                }
                NSMutableArray<AVIMConversation *> *orderlyResults = [NSMutableArray arrayWithCapacity:self.conversationMap.count];
                for (NSString *conversationID in orderlyIDs) {
                    AVIMConversation *conversation = self.conversationMap[conversationID];
                    if (conversation) {
                        [orderlyResults addObject:conversation];
                    }
                }
                dispatch_async(self.callbackQueue, ^{
                    callback(orderlyResults, nil);
                });
            } else {
                NSError *error = self.db.lastError;
                dispatch_async(self.callbackQueue, ^{
                    callback(nil, error);
                });
            }
        } else {
            dispatch_async(self.callbackQueue, ^{
                callback(nil, LCErrorInternal(@"not get DB."));
            });
        }
    });
}

- (void)queryCachedConversationsOrderByLastMessageTimestampWithCallback:(void (^)(NSArray<AVIMConversation *> * _Nullable orderlyResults, NSError * _Nullable error))callback;
{
    dispatch_async(self.queue, ^{
        if (self.db) {
            NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ ORDER BY %@ DESC", AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyLastMessageAt];
            LCResultSet *set = [self.db executeQuery:sql];
            if (set) {
                NSMutableArray<AVIMConversation *> *orderlyResults = [NSMutableArray array];
                while ([set next]) {
                    NSString *conversationID = [set stringForColumn:AVIMConversationCacheKeyConversationID];
                    if (!conversationID) { continue; }
                    // TODO: get conversation from set data.
                    AVIMConversation *conversation = nil;
                    self.conversationMap[conversationID] = conversation;
                    [orderlyResults addObject:conversation];
                }
                dispatch_async(self.callbackQueue, ^{
                    callback(orderlyResults, nil);
                });
            } else {
                NSError *error = self.db.lastError;
                dispatch_async(self.callbackQueue, ^{
                    callback(nil, error);
                });
            }
        } else {
            dispatch_async(self.callbackQueue, ^{
                callback(nil, LCErrorInternal(@"not get DB."));
            });
        }
    });
}

- (void)removeConversationsWithIDs:(NSArray<NSString *> *)conversationIDs
                          callback:(void (^)(BOOL succeeded, NSError * _Nullable error))callback
{
    NSParameterAssert(conversationIDs.count > 0 && conversationIDs.count == [NSSet setWithArray:conversationIDs].count);
    dispatch_async(self.queue, ^{
        NSError *error = nil;
        [self.conversationMap removeObjectsForKeys:conversationIDs];
        if (self.db) {
            NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (?)", AVIMLocalDBTableNameConversation, AVIMConversationCacheKeyConversationID];
            NSString *whereIn = [conversationIDs componentsJoinedByString:@","];
            if (![self.db executeUpdate:sql, whereIn]) {
                error = self.db.lastError;
                AVLoggerError(AVLoggerDomainIM, @"DB<p: %p> delete from %@ where in: %@ failed: %@.", self.db, AVIMLocalDBTableNameConversation, whereIn, error);
            }
        }
        dispatch_async(self.callbackQueue, ^{
            callback(!error, error);
        });
    });
}

@end
