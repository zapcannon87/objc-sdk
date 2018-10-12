//
//  LCRouter.m
//  AVOS
//
//  Created by Tang Tianyong on 5/9/16.
//  Copyright © 2016 LeanCloud Inc. All rights reserved.
//

#import "LCRouter_Internal.h"
#import "AVUtils.h"
#import "AVErrorUtils.h"
#import "AVPaasClient.h"
#import "AVPersistenceUtils.h"
#import "LCNetworkStatistics.h"

RouterCacheKey RouterCacheKeyApp = @"RouterCacheDataApp";
RouterCacheKey RouterCacheKeyRTM = @"RouterCacheDataRTM";
static RouterCacheKey RouterCacheKeyData = @"data";
static RouterCacheKey RouterCacheKeyTimestamp = @"timestamp";

static NSString * PathWithVersion(NSString *path)
{
    NSString *APIVersion = @"1.1";
    if ([path hasPrefix:[@"/" stringByAppendingPathComponent:APIVersion]]) {
        return path;
    } else if ([path hasPrefix:APIVersion]) {
        return [@"/" stringByAppendingPathComponent:path];
    } else {
        return [[@"/" stringByAppendingPathComponent:APIVersion] stringByAppendingPathComponent:path];
    }
}

static NSString * RTMRouterPath = @"/v1/route";

@implementation LCRouter {
    NSLock *_lock;
    /// { 'app ID' : 'app router data tuple' }
    NSMutableDictionary<NSString *, NSDictionary *> *_appRouterMap;
    /// { 'app ID' : 'app callback flag' }
    NSMutableDictionary<NSString *, NSNumber *> *_appRouterCallbacksMap;
    /// { 'app ID' : 'RTM router data tuple' }
    NSMutableDictionary<NSString *, NSDictionary *> *_RTMRouterMap;
    /// { 'app ID' : 'RTM callback array' }
    NSMutableDictionary<NSString *, NSMutableArray<void (^)(NSDictionary *, NSError *)> *> *_RTMRouterCallbacksMap;
    /// { 'module key' : 'URL' }
    NSMutableDictionary<NSString *, NSString *> *_customAppServerTable;
    /// { 'router response key' : 'url module key' }
    NSDictionary<NSString *, NSString *> *_keyToModule;
}

+ (instancetype)sharedInstance
{
    static LCRouter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LCRouter alloc] _init];
    });
    return instance;
}

- (instancetype)init
{
    [NSException raise:NSInternalInconsistencyException format:@"not allow."];
    return nil;
}

- (instancetype)_init
{
    self = [super init];
    if (self) {
        self->_lock = [NSLock new];
        NSString *directoryPathOfRouterCache = [AVPersistenceUtils directoryPathOfRouterWithAutoCreate:true];
        self->_directoryPathOfCache = directoryPathOfRouterCache;
        NSMutableDictionary *(^ loadCacheToMemoryBlock)(NSString *) = ^NSMutableDictionary *(NSString *key) {
            if (directoryPathOfRouterCache.length) {
                NSString *filePath = [directoryPathOfRouterCache stringByAppendingPathComponent:key];
                NSData *data = [NSData dataWithContentsOfFile:filePath];
                if (data.length) {
                    NSError *error = nil;
                    NSMutableDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                    if ([NSMutableDictionary lc__checkingType:dictionary]) {
                        return dictionary;
                    } else {
                        if (!error) { error = LCErrorInternal([NSString stringWithFormat:@"file in %@ is invalid.", filePath]); }
                        AVLoggerError(AVLoggerDomainDefault, @"%@", error);
                    }
                }
            }
            return [NSMutableDictionary dictionary];
        };
        self->_appRouterMap = loadCacheToMemoryBlock(RouterCacheKeyApp);
        self->_appRouterCallbacksMap = [NSMutableDictionary dictionary];
        self->_RTMRouterMap = loadCacheToMemoryBlock(RouterCacheKeyRTM);
        self->_RTMRouterCallbacksMap = [NSMutableDictionary dictionary];
        self->_customAppServerTable = [NSMutableDictionary dictionary];
        self->_keyToModule = ({
            @{ RouterKeyAppAPIServer : AppModuleAPI,
               RouterKeyAppEngineServer : AppModuleEngine,
               RouterKeyAppPushServer : AppModulePush,
               RouterKeyAppRTMRouterServer : AppModuleRTMRouter,
               RouterKeyAppStatsServer : AppModuleStats };
        });
    }
    return self;
}

// MARK: - App Router

- (void)getAppRouterDataWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID.length);
    [[AVPaasClient sharedInstance] getObject:AppRouterURLString withParameters:@{@"appId":appID} block:^(id _Nullable object, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
        } else {
            NSDictionary *dictionary = (NSDictionary *)object;
            if ([NSDictionary lc__checkingType:dictionary]) {
                callback(dictionary, nil);
            } else {
                callback(nil, LCErrorInternal(@"response data invalid."));
            }
        }
    }];
}

- (void)tryUpdateAppRouterWithAppID:(NSString *)appID callback:(void (^)(NSError *error))callback
{
    NSParameterAssert(appID.length);
    BOOL isUpdatingAppRouter = false;
    [self->_lock lock];
    if (self->_appRouterCallbacksMap[appID]) {
        isUpdatingAppRouter = true;
    } else {
        self->_appRouterCallbacksMap[appID] = @(true);
    }
    [self->_lock unlock];
    if (isUpdatingAppRouter) {
        return;
    }
    [self getAppRouterDataWithAppID:appID callback:^(NSDictionary *dataDictionary, NSError *error) {
        if (error) {
            AVLoggerError(AVLoggerDomainDefault, @"%@", error);
        } else {
            NSParameterAssert([NSDictionary lc__checkingType:dataDictionary]);
            NSDictionary *routerDataTuple = ({
                @{ RouterCacheKeyData : dataDictionary,
                   RouterCacheKeyTimestamp : @(NSDate.date.timeIntervalSince1970) };
            });
            NSDictionary *appRouterMapCopy = nil;
            [self->_lock lock];
            self->_appRouterMap[appID] = routerDataTuple;
            appRouterMapCopy = [self->_appRouterMap copy];
            [self->_lock unlock];
            [self cachingRouterDataWithMap:appRouterMapCopy key:RouterCacheKeyApp];
        }
        [self->_lock lock];
        [self->_appRouterCallbacksMap removeObjectForKey:appID];
        [self->_lock unlock];
        if (callback) { callback(error); }
    }];
}

- (NSString *)appURLForPath:(NSString *)path appID:(NSString *)appID
{
    NSParameterAssert(path.length);
    NSParameterAssert(appID.length);
    
    RouterKey serverKey = [self serverKeyForPath:path];
    
    NSString *(^constructedURL)(NSString *) = ^NSString *(NSString *host) {
        if ([serverKey isEqualToString:RouterKeyAppRTMRouterServer]) {
            return [self absoluteURLStringWithHost:host path:path];
        } else {
            return [self absoluteURLStringWithHost:host path:PathWithVersion(path)];
        }
    };
    
    ({  /// get server URL from custom server table.
        NSString *customServerURL = [NSString lc__decodingDictionary:self->_customAppServerTable key:serverKey];
        if (customServerURL.length) {
            return constructedURL(customServerURL);
        }
    });
    
    ({  /// get server URL from memory cache
        NSDictionary *appRouterDataTuple = nil;
        [self->_lock lock];
        appRouterDataTuple = [NSDictionary lc__decodingDictionary:self->_appRouterMap key:appID];
        [self->_lock unlock];
        if ([self shouldUpdateRouterData:appRouterDataTuple]) {
            [self tryUpdateAppRouterWithAppID:appID callback:nil];
        }
        NSDictionary *dataDic = [NSDictionary lc__decodingDictionary:appRouterDataTuple key:RouterCacheKeyData];
        NSString *serverURL = [NSString lc__decodingDictionary:dataDic key:serverKey];
        if (serverURL.length) {
            return constructedURL(serverURL);
        }
    });
    
    /// fallback server URL
    NSString *fallbackServerURL = [self appRouterFallbackURLWithKey:serverKey appID:appID];
    return constructedURL(fallbackServerURL);
}

- (NSString *)appRouterFallbackURLWithKey:(NSString *)key appID:(NSString *)appID
{
    NSParameterAssert(key.length);
    NSParameterAssert(appID.length);
    /// fallback server URL
    NSString *appDomain = nil;
    if ([appID hasSuffix:AppIDSuffixCN] || [appID rangeOfString:@"-"].location == NSNotFound) {
        appDomain = AppDomainCN;
    } else if ([appID hasSuffix:AppIDSuffixCE]) {
        appDomain = AppDomainCE;
    } else if ([appID hasSuffix:AppIDSuffixUS]) {
        appDomain = AppDomainUS;
    } else {
        [NSException raise:NSInternalInconsistencyException format:@"application id invalid."];
    }
    return [NSString stringWithFormat:@"%@.%@.%@", [appID substringToIndex:8].lowercaseString, self->_keyToModule[key], appDomain];
}

/// for compatibility, keep it.
- (NSString *)URLStringForPath:(NSString *)path
{
    return [self appURLForPath:path appID:[AVOSCloud getApplicationId]];
}

// MARK: - RTM Router

- (NSString *)RTMRouterURLForAppID:(NSString *)appID
{
    NSParameterAssert(appID.length);
    return [self appURLForPath:RTMRouterPath appID:appID];
}

- (void)getRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID.length);
    NSParameterAssert(RTMRouterURL.length);
    NSMutableDictionary *parameters = ({
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        parameters[@"appId"] = appID;
        parameters[@"secure"] = @"1";
        /* Back door for user to connect to puppet environment. */
        if (getenv("LC_IM_PUPPET_ENABLED") && getenv("SIMULATOR_UDID")) {
            parameters[@"debug"] = @"true";
        }
        parameters;
    });
    [[AVPaasClient sharedInstance] getObject:RTMRouterURL withParameters:parameters block:^(id _Nullable object, NSError * _Nullable error) {
        if (error) {
            callback(nil, error);
        } else {
            if ([NSDictionary lc__checkingType:object]) {
                callback(object, nil);
            } else {
                callback(nil, LCErrorInternal(@"response data invalid."));
            }
        }
    }];
}

- (void)getAndCacheRTMRouterDataWithAppID:(NSString *)appID RTMRouterURL:(NSString *)RTMRouterURL callback:(void (^)(NSDictionary *dataDictionary, NSError *error))callback
{
    NSParameterAssert(appID.length);
    NSParameterAssert(RTMRouterURL.length);
    [self getRTMRouterDataWithAppID:appID RTMRouterURL:RTMRouterURL callback:^(NSDictionary *dataDictionary, NSError *error) {
        if (error) {
            callback(nil, error);
        } else {
            NSParameterAssert([NSDictionary lc__checkingType:dataDictionary]);
            NSDictionary *routerDataTuple = ({
                @{ RouterCacheKeyData : dataDictionary,
                   RouterCacheKeyTimestamp : @(NSDate.date.timeIntervalSince1970) };
            });
            NSDictionary *RTMRouterMapCopy = nil;
            [self->_lock lock];
            self->_RTMRouterMap[appID] = routerDataTuple;
            RTMRouterMapCopy = [self->_RTMRouterMap copy];
            [self->_lock unlock];
            [self cachingRouterDataWithMap:RTMRouterMapCopy key:RouterCacheKeyRTM];
            callback(dataDictionary, nil);
        }
    }];
}

- (void)getRTMURLWithAppID:(NSString *)appID callback:(void (^)(NSDictionary *dictionary, NSError *error))callback
{
    NSParameterAssert(appID.length);
    
    /// get RTM router URL & try update app router
    NSString *RTMRouterURL = [self RTMRouterURLForAppID:appID];
    
    ({  /// add callback to map
        BOOL addCallbacksToArray = false;
        [self->_lock lock];
        NSMutableArray<void (^)(NSDictionary *, NSError *)> *callbacks = self->_RTMRouterCallbacksMap[appID];
        if (callbacks) {
            [callbacks addObject:callback];
            addCallbacksToArray = true;
        } else {
            callbacks = [NSMutableArray arrayWithObject:callback];
            self->_RTMRouterCallbacksMap[appID] = callbacks;
        }
        [self->_lock unlock];
        if (addCallbacksToArray) {
            return;
        }
    });
    
    void(^invokeCallbacks)(NSDictionary *, NSError *) = ^(NSDictionary *data, NSError *error) {
        NSMutableArray<void (^)(NSDictionary *, NSError *)> *callbacks = nil;
        [self->_lock lock];
        callbacks = self->_RTMRouterCallbacksMap[appID];
        [self->_RTMRouterCallbacksMap removeObjectForKey:appID];
        [self->_lock unlock];
        for (void (^block)(NSDictionary *, NSError *) in callbacks) {
            block(data, error);
        }
    };
    
    ({  /// get RTM URL data from memory
        NSDictionary *RTMRouterDataTuple = nil;
        [self->_lock lock];
        RTMRouterDataTuple = [NSDictionary lc__decodingDictionary:self->_RTMRouterMap key:appID];
        [self->_lock unlock];
        if (![self shouldUpdateRouterData:RTMRouterDataTuple]) {
            NSDictionary *dataDic = [NSDictionary lc__decodingDictionary:RTMRouterDataTuple key:RouterCacheKeyData];
            invokeCallbacks(dataDic, nil);
            return;
        }
    });
    
    [self getAndCacheRTMRouterDataWithAppID:appID RTMRouterURL:RTMRouterURL callback:^(NSDictionary *dataDictionary, NSError *error) {
        invokeCallbacks(dataDictionary, error);
    }];
}

// MARK: - Batch Path

- (NSString *)batchPathForPath:(NSString *)path
{
    NSParameterAssert(path.length);
    return PathWithVersion(path);
}

// MARK: - Custom App URL

- (void)customAppServerURL:(NSString *)URLString key:(RouterKey)key
{
    if (!key.length) { return; }
    if (URLString) {
        self->_customAppServerTable[key] = URLString;
    } else {
        [self->_customAppServerTable removeObjectForKey:key];
    }
    [LCNetworkStatistics sharedInstance].ignoreAlwaysCollectIfCustomedService = true;
}

// MARK: - Misc

- (void)cachingRouterDataWithMap:(NSDictionary *)routerDataMap key:(RouterCacheKey)key
{
    NSParameterAssert([NSDictionary lc__checkingType:routerDataMap]);
    NSParameterAssert(key.length);
    NSData *data = ({
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:routerDataMap options:0 error:&error];
        if (!data.length) {
            AVLoggerError(AVLoggerDomainDefault, @"%@", error);
            return;
        }
        data;
    });
    NSString *filePath = ({
        NSString *routerCacheDirectoryPath = self.directoryPathOfCache;
        BOOL isDirectory;
        BOOL isExists = [[NSFileManager defaultManager] fileExistsAtPath:routerCacheDirectoryPath isDirectory:&isDirectory];
        if (!isExists) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:routerCacheDirectoryPath withIntermediateDirectories:true attributes:nil error:&error];
            if (error) {
                AVLoggerError(AVLoggerDomainDefault, @"%@", error);
                return;
            }
        } else if (isExists && !isDirectory) {
            AVLoggerError(AVLoggerDomainDefault, @"can't caching router data.");
            return;
        }
        [routerCacheDirectoryPath stringByAppendingPathComponent:key];
    });
    [data writeToFile:filePath atomically:true];
}

- (void)cleanCacheWithKey:(RouterCacheKey)key error:(NSError * _Nullable __autoreleasing *)error
{
    NSParameterAssert(key.length);
    NSString *path = [self.directoryPathOfCache stringByAppendingPathComponent:key];
    if (path.length && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:error];
    }
}

- (BOOL)shouldUpdateRouterData:(NSDictionary *)routerDataTuple
{
    if ([NSDictionary lc__checkingType:routerDataTuple]) {
        NSDictionary *JSONData = [NSDictionary lc__decodingDictionary:routerDataTuple key:RouterCacheKeyData];
        NSTimeInterval lastTimestamp = [[NSNumber lc__decodingDictionary:routerDataTuple key:RouterCacheKeyTimestamp] doubleValue];
        if (JSONData) {
            NSTimeInterval ttl = [[NSNumber lc__decodingDictionary:JSONData key:RouterKeyTTL] doubleValue];
            NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
            if (currentTimestamp >= lastTimestamp && currentTimestamp <= (lastTimestamp + ttl)) {
                return false;
            } else {
                return true;
            }
        } else {
            return true;
        }
    } else {
        return true;
    }
}

- (RouterKey)serverKeyForPath:(NSString *)path
{
    if ([path hasPrefix:@"call"] || [path hasPrefix:@"functions"]) {
        return RouterKeyAppEngineServer;
    } else if ([path hasPrefix:@"push"] || [path hasPrefix:@"installations"]) {
        return RouterKeyAppPushServer;
    } else if ([path hasPrefix:@"stats"] || [path hasPrefix:@"statistics"] || [path hasPrefix:@"always_collect"]) {
        return RouterKeyAppStatsServer;
    } else if ([path isEqualToString:RTMRouterPath]) {
        return RouterKeyAppRTMRouterServer;
    } else {
        return RouterKeyAppAPIServer;
    }
}

- (NSString *)absoluteURLStringWithHost:(NSString *)host path:(NSString *)path
{
    NSParameterAssert(host.length);
    NSString *unifiedHost = ({
        NSString *unifiedHost = nil;
        /// For "example.com:8080", the scheme is "example.com". Here, we need a farther check.
        NSURL *URL = [NSURL URLWithString:host];
        if (URL.scheme && [host hasPrefix:[URL.scheme stringByAppendingString:@"://"]]) {
            unifiedHost = host;
        } else {
            unifiedHost = [@"https://" stringByAppendingString:host];
        }
        unifiedHost;
    });
    
    NSURLComponents *URLComponents = ({
        NSURLComponents *URLComponents = [[NSURLComponents alloc] initWithString:unifiedHost];
        if (path.length) {
            NSString *pathString = nil;
            if (URLComponents.path.length) {
                pathString = [URLComponents.path stringByAppendingPathComponent:path];
            } else {
                pathString = path;
            }
            NSURL *pathURL = [NSURL URLWithString:pathString];
            URLComponents.path = pathURL.path;
            URLComponents.query = pathURL.query;
            URLComponents.fragment = pathURL.fragment;
        }
        URLComponents;
    });
    
    return [URLComponents URL].absoluteString;
}

@end
