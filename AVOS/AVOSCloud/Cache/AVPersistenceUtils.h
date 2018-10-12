//
//  AVPersistenceUtils.h
//  paas
//
//  Created by Summer on 13-3-25.
//  Copyright (c) 2013年 AVOS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AVPersistenceUtils : NSObject

// MARK: - ~/Library/Caches/com.leancloud.caches/_Router
+ (NSString *)directoryPathOfRouterWithAutoCreate:(BOOL)autoCreate;

// MARK: - ~/Library/Application Support/com.leancloud.data/{App ID MD5 String}/_Conversation
+ (NSString *)directoryPathOfConversationWithAppID:(NSString *)appID autoCreate:(BOOL)autoCreate;

// MARK: - 

+ (NSString *)homeDirectoryLibraryCachesLeanCloudCachesFiles;

+ (NSString *)avCacheDirectory;

+ (NSString *)currentUserArchivePath;
+ (NSString *)currentUserClassArchivePath;
+ (NSString *)currentInstallationArchivePath;

+ (NSString *)eventuallyPath;

+ (NSString *)messageCachePath;
+ (NSString *)messageCacheDatabasePathWithName:(NSString *)name;

+ (NSString *)keyValueDatabasePath;
+ (NSString *)clientSessionTokenCacheDatabasePath;

+ (NSString *)userDefaultsPath;

+ (BOOL)saveJSON:(id)JSON toPath:(NSString *)path;
+ (id)getJSONFromPath:(NSString *)path;

+(BOOL)removeFile:(NSString *)path;
+(BOOL)fileExist:(NSString *)path;
+(BOOL)createFile:(NSString *)path;

+ (BOOL)deleteFilesInDirectory:(NSString *)dirPath moreThanDays:(NSInteger)numberOfDays;
+ (NSDate *)lastModified:(NSString *)fullPath;

@end
