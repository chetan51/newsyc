//
//  HNObjectCache.m
//  newsyc
//
//  Created by Grant Paul on 7/15/12.
//
//

#import "HNObjectCache.h"

@interface HNObjectCacheKey : NSObject <NSCopying> {
    Class cls;
    id identifier;
    NSDictionary *info;
}

@end

@implementation HNObjectCacheKey

#pragma mark - Lifecycle

- (id)initWithClass:(Class)cls_ identifier:(id)identifier_ infoDictionary:(NSDictionary *)info_ {
    if ((self = [super init])) {
        cls = cls_;
        identifier = [identifier_ copy];
        info = [info_ copy];
    }

    return self;
}

- (void)dealloc {
    [identifier release];
    [info release];

    [super dealloc];
}

+ (id)objectCacheWithClass:(Class)cls_ identifier:(id)identifier_ infoDictionary:(NSDictionary *)info {
    return [[[self alloc] initWithClass:cls_ identifier:identifier_ infoDictionary:info] autorelease];
}

+ (id)objectCacheForObject:(HNObject *)object {
    return [self objectCacheWithClass:[object class] identifier:[object identifier] infoDictionary:[object infoDictionary]];
}

+ (NSString *)persistentCacheIdentiferForClass:(Class)cls_ identifier:(id)identifier_ infoDictionary:(NSDictionary *)info {
    return [NSString stringWithFormat:@"%@-%@-%x", cls_, identifier_, [info hash]];
}

- (NSString *)persistentCacheIdentifier {
    return [[self class] persistentCacheIdentiferForClass:cls identifier:identifier infoDictionary:info];
}

#pragma mark - Properties

- (Class)objectClass {
    return cls;
}

- (id)objectIdentifier {
    return identifier;
}

- (NSDictionary *)objectInfoDictionary {
    return info;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithClass:cls identifier:identifier infoDictionary:info];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object_ {
    BOOL classes = cls == [object_ objectClass];
    BOOL identifiers = [identifier isEqual:[object_ objectIdentifier]];
    BOOL infos = [info isEqualToDictionary:[object_ objectInfoDictionary]] || (info == nil && [object_ objectInfoDictionary] == nil);

    return classes && identifiers && infos;
}

- (NSUInteger)hash {
    return [cls hash] ^ [identifier hash] ^ [info hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@:%p identifier=%@ info=%p>", [self class], self, identifier, info];
}

@end

@implementation HNObjectCache

+ (NSMutableDictionary *)cacheDictionary {
    static NSMutableDictionary *objectCache = nil;
    if (objectCache == nil) objectCache = [[NSMutableDictionary alloc] init];
    return objectCache;
}

+ (NSString *)persistentCachePath {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

    if ([cachePaths count] > 0) {
        NSString *cachePath = [cachePaths objectAtIndex:0];
        NSString *objectPath = [cachePath stringByAppendingPathComponent:@"HNObjectCache"];
        return objectPath;
    } else {
        return nil;
    }
}

+ (void)clearPersistentCache {
    NSString *cachePath = [self persistentCachePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:cachePath error:NULL];
}

+ (NSString *)persistentCachePathForKey:(HNObjectCacheKey *)key {
    NSString *cachePath = [self persistentCachePath];
    NSString *keyPath = [key persistentCacheIdentifier];
    NSString *objectPath = [cachePath stringByAppendingPathComponent:keyPath];

    return objectPath;
}

+ (BOOL)persistentCacheHasObjectForKey:(HNObjectCacheKey *)key {
    NSString *path = [self persistentCachePathForKey:key];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:path];
}

+ (NSDictionary *)persistentCacheDictionaryForKey:(HNObjectCacheKey *)key {
    NSString *path = [self persistentCachePathForKey:key];
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

+ (void)updateObjectFromPersistentCache:(HNObject *)object {
    HNObjectCacheKey *key = [HNObjectCacheKey objectCacheForObject:object];
    
    if ([self persistentCacheHasObjectForKey:key]) {
        NSDictionary *cachedDictionary = [self persistentCacheDictionaryForKey:key];
        [object loadFromDictionary:cachedDictionary complete:YES];
        [object setIsLoaded:YES];
    }
}

+ (void)savePersistentCacheDictionary:(NSDictionary *)dict forObject:(HNObject *)object {
    HNObjectCacheKey *key = [HNObjectCacheKey objectCacheForObject:object];
    NSString *path = [self persistentCachePathForKey:key];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [dict writeToFile:path atomically:YES];
    });
}

+ (void)initialize {
    static BOOL initialized = NO;

    if (!initialized) {
        // inititalize the cache
        [self cacheDictionary];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager createDirectoryAtPath:[self persistentCachePath] withIntermediateDirectories:YES attributes:nil error:NULL];

        initialized = YES;
    }
}

+ (HNObject *)objectFromCacheWithKey:(HNObjectCacheKey *)key {
    NSMutableDictionary *cache = [self cacheDictionary];
    HNObject *object = [cache objectForKey:key];
    return object;
}

+ (HNObject *)objectFromCacheWithClass:(Class)cls_ identifier:(id)identifier_ infoDictionary:(NSDictionary *)info {
    HNObjectCacheKey *key = [HNObjectCacheKey objectCacheWithClass:cls_ identifier:identifier_ infoDictionary:info];
    return [self objectFromCacheWithKey:key];
}

+ (BOOL)cacheHasObject:(HNObject *)object {
    HNObjectCacheKey *key = [HNObjectCacheKey objectCacheForObject:object];
    return ([self objectFromCacheWithKey:key] != nil);
}

+ (void)addObjectToCache:(HNObject *)object {
    HNObjectCacheKey *key = [HNObjectCacheKey objectCacheForObject:object];

    NSMutableDictionary *cache = [self cacheDictionary];
    [cache setObject:object forKey:key];
}

@end
