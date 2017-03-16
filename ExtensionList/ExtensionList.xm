#import <ImageIO/ImageIO.h>
#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import <dlfcn.h>

#define ROCKETBOOTSTRAP_LOAD_DYNAMIC
#import <LightMessaging/LightMessaging.h>

#import <LSApplicationWorkspace.h>
#import <LSPlugInKitProxy.h>
#import "ExtensionList.h"

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end


NSString *const ALIconLoadedNotification = @"ELIconLoadedNotification";
NSString *const ALDisplayIdentifierKey = @"ELDisplayIdentifier";
NSString *const ALIconSizeKey = @"ELIconSize";

enum {
    ELMessageIdGetExtensions,
    ELMessageIdIconForSize,
    ELMessageIdValueForKey,
    ELMessageIdValueForKeyPath,
    ELMessageIdGetExtensionCount,
    ELMessageIdGetAvaliableExtensions
};

static LMConnection connection = {
    MACH_PORT_NULL,
    "extensionlist.datasource"
};

@interface ELExtensionListImpl : ELExtensionList

@end

static ELExtensionList * sharedExtensionList;

@implementation ELExtensionList

+(void)initialize {
    if (self == [ELExtensionList class] && !%c(SBIconModel)) {
        sharedExtensionList = [[self alloc] init];
    }
}

+(ELExtensionList *) sharedExtensionList {
    return sharedExtensionList;
}

-(instancetype)init {
    if ((self = [super init])) {
        if (sharedExtensionList) {
            [self release];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Only one instance of ELExtensionList is permitted at a time! Use [ELExtensionList sharedExtensionList] instead." userInfo:nil];
        }
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        cachedIcons = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [pool drain];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cachedIcons release];
    [super dealloc];
}

-(NSInteger)extensionCount {
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWay(&connection, ELMessageIdGetExtensionCount, NULL, 0, &buffer))
        return 0;
    return LMResponseConsumeInteger(&buffer);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ELExtensionList: %p extensionCount=%ld>", self, (long)self.extensionCount];
}

- (void)didReceiveMemoryWarning
{
    OSSpinLockLock(&spinLock);
    [cachedIcons removeAllObjects];
    OSSpinLockUnlock(&spinLock);
}

- (NSDictionary *)extensions
{
    return [self extensionsFilteredUsingPredicate:nil];
}

- (NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate
{
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWayData(&connection, ELMessageIdGetExtensions, (CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:predicate], &buffer))
        return nil;
    id result = LMResponseConsumePropertyList(&buffer);
    return [result isKindOfClass:[NSDictionary class]] ? result : nil;
}


static NSInteger DictionaryTextComparator(id a, id b, void *context)
{
    return [[(NSDictionary *)context objectForKey:a] localizedCaseInsensitiveCompare:[(NSDictionary *)context objectForKey:b]];
}

- (NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate sysVerAvaliable:(BOOL)sysVerAvaliable titleSortedIdentifiers:(NSArray **)outSortedByTitle
{
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWayData(&connection, sysVerAvaliable ? ELMessageIdGetAvaliableExtensions : ELMessageIdGetExtensions, (CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:predicate], &buffer))
        return nil;
    NSDictionary *result = LMResponseConsumePropertyList(&buffer);
    if (![result isKindOfClass:[NSDictionary class]])
        return nil;
    if (outSortedByTitle) {
        // Generate a sorted list of apps
        *outSortedByTitle = [[result allKeys] sortedArrayUsingFunction:DictionaryTextComparator context:result];
    }
    return result;
}


- (id)valueForKeyPath:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier
{
    if (!keyPath || !displayIdentifier)
        return nil;
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWayPropertyList(&connection, ELMessageIdValueForKeyPath, [NSDictionary dictionaryWithObjectsAndKeys:keyPath, @"key", displayIdentifier, @"displayIdentifier", nil], &buffer))
        return nil;
    return LMResponseConsumePropertyList(&buffer);
}

- (id)valueForKey:(NSString *)key forDisplayIdentifier:(NSString *)displayIdentifier
{
    if (!key || !displayIdentifier)
        return nil;
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWayPropertyList(&connection, ELMessageIdValueForKey, [NSDictionary dictionaryWithObjectsAndKeys:key, @"key", displayIdentifier, @"displayIdentifier", nil], &buffer))
        return nil;
    return LMResponseConsumePropertyList(&buffer);
}

- (void)postNotificationWithUserInfo:(NSDictionary *)userInfo
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ALIconLoadedNotification object:self userInfo:userInfo];
}

- (CGImageRef)copyIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier
{
    if (iconSize <= 0)
        return NULL;
    LSBundleProxy * bundle = (LSBundleProxy *)[[LSPlugInKitProxy pluginKitProxyForIdentifier:displayIdentifier] containingBundle];
    NSString * containingBundleId = [bundle valueForKey:@"bundleIdentifier"];
    if (!containingBundleId || containingBundleId.length == 0) {
        return NULL;
    }
    NSString *key = [displayIdentifier stringByAppendingFormat:@"#%f", (CGFloat)iconSize];
    OSSpinLockLock(&spinLock);
    CGImageRef result = (CGImageRef)[cachedIcons objectForKey:key];
    if (result) {
        result = CGImageRetain(result);
        OSSpinLockUnlock(&spinLock);
        return result;
    }
    OSSpinLockUnlock(&spinLock);
    if (iconSize == ALApplicationIconSizeSmall) {
        result = [UIImage _applicationIconImageForBundleIdentifier:containingBundleId format:0 scale:[UIScreen mainScreen].scale].CGImage;
        if (result)
            goto skip;
    }
    LMResponseBuffer buffer;
    if (LMConnectionSendTwoWayPropertyList(&connection, ELMessageIdIconForSize, [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:iconSize], @"iconSize", displayIdentifier, @"displayIdentifier", nil], &buffer))
        return NULL;
    result = [LMResponseConsumeImage(&buffer) CGImage];
    if (!result)
        return NULL;
skip:
    OSSpinLockLock(&spinLock);
    [cachedIcons setObject:(id)result forKey:key];
    OSSpinLockUnlock(&spinLock);
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInteger:iconSize], ALIconSizeKey,
                              displayIdentifier, ALDisplayIdentifierKey,
                              nil];
    if ([NSThread isMainThread])
        [self performSelector:@selector(postNotificationWithUserInfo:) withObject:userInfo afterDelay:0.0];
    else
        [self performSelectorOnMainThread:@selector(postNotificationWithUserInfo:) withObject:userInfo waitUntilDone:NO];
    return CGImageRetain(result);
}

- (UIImage *)iconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier
{
    CGImageRef image = [self copyIconOfSize:iconSize forDisplayIdentifier:displayIdentifier];
    if (!image)
        return nil;
    UIImage *result;
    if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
        CGFloat scale = (CGImageGetWidth(image) + CGImageGetHeight(image)) / (CGFloat)(iconSize + iconSize);
        result = [UIImage imageWithCGImage:image scale:scale orientation:0];
    } else {
        result = [UIImage imageWithCGImage:image];
    }
    CGImageRelease(image);
    return result;
}

- (BOOL)hasCachedIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier
{
    NSString *key = [displayIdentifier stringByAppendingFormat:@"#%f", (CGFloat)iconSize];
    OSSpinLockLock(&spinLock);
    id result = [cachedIcons objectForKey:key];
    OSSpinLockUnlock(&spinLock);
    return result != nil;
}

@end

@implementation ELExtensionListImpl

static void processMessage(SInt32 messageId, mach_port_t replyPort, CFDataRef data)
{
    switch (messageId) {
        case ELMessageIdGetExtensions: {
            NSDictionary *result;
            if (data && CFDataGetLength(data)) {
                NSPredicate *predicate = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)data];
                @try {
                    result = [predicate isKindOfClass:[NSPredicate class]] ? [sharedExtensionList extensionsFilteredUsingPredicate:predicate] : [sharedExtensionList extensions];
                }
                @catch (NSException *exception) {
                    NSLog(@"ExtensionList: In call to extensionsFilteredUsingPredicate:%@ trapped %@", predicate, exception);
                    break;
                }
            } else {
                result = [sharedExtensionList extensions];
            }
            LMSendPropertyListReply(replyPort, result);
            return;
        }
        case ELMessageIdGetAvaliableExtensions: {
            NSDictionary *result;
            if (data && CFDataGetLength(data)) {
                NSPredicate *predicate = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)data];
                @try {
                    result = [predicate isKindOfClass:[NSPredicate class]] ? [sharedExtensionList extensionsFilteredUsingPredicate:predicate sysVerAvaliable:YES titleSortedIdentifiers:NULL] : [sharedExtensionList extensions];
                }
                @catch (NSException *exception) {
                    NSLog(@"AppList: In call to applicationsFilteredUsingPredicate:%@ onlyVisible:YES titleSortedIdentifiers:NULL trapped %@", predicate, exception);
                    break;
                }
            } else {
                result = [sharedExtensionList extensions];
            }
            LMSendPropertyListReply(replyPort, result);
            return;
        }
        case ELMessageIdIconForSize: {
            if (!data)
                break;
            NSDictionary *params = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
            if (![params isKindOfClass:[NSDictionary class]])
                break;
            id iconSize = [params objectForKey:@"iconSize"];
            if (![iconSize respondsToSelector:@selector(floatValue)])
                break;
            NSString *displayIdentifier = [params objectForKey:@"displayIdentifier"];
            if (![displayIdentifier isKindOfClass:[NSString class]])
                break;
            CGImageRef result = [sharedExtensionList copyIconOfSize:[iconSize floatValue] forDisplayIdentifier:displayIdentifier];
            if (result) {
                LMSendImageReply(replyPort, [UIImage imageWithCGImage:result]);
                CGImageRelease(result);
                return;
            }
            break;
        }
        case ELMessageIdValueForKeyPath:
        case ELMessageIdValueForKey: {
            if (!data)
                break;
            NSDictionary *params = [NSPropertyListSerialization propertyListFromData:(NSData *)data mutabilityOption:0 format:NULL errorDescription:NULL];
            if (![params isKindOfClass:[NSDictionary class]])
                break;
            NSString *key = [params objectForKey:@"key"];
            Class stringClass = [NSString class];
            if (![key isKindOfClass:stringClass])
                break;
            NSString *displayIdentifier = [params objectForKey:@"displayIdentifier"];
            if (![displayIdentifier isKindOfClass:stringClass])
                break;
            id result;
            @try {
                result = messageId == ELMessageIdValueForKeyPath ? [sharedExtensionList valueForKeyPath:key forDisplayIdentifier:displayIdentifier] : [sharedExtensionList valueForKey:key forDisplayIdentifier:displayIdentifier];
            }
            @catch (NSException *exception) {
                NSLog(@"AppList: In call to valueForKey%s:%@ forDisplayIdentifier:%@ trapped %@", messageId == ELMessageIdValueForKeyPath ? "Path" : "", key, displayIdentifier, exception);
                break;
            }
            LMSendPropertyListReply(replyPort, result);
            return;
        }
        case ELMessageIdGetExtensionCount: {
            LMSendIntegerReply(replyPort, [sharedExtensionList extensionCount]);
            return;
        }
    }
    LMSendReply(replyPort, NULL, 0);
}

static void machPortCallback(CFMachPortRef port, void *bytes, CFIndex size, void *info)
{
    LMMessage *request = (LMMessage *)bytes;
    if (size < sizeof(LMMessage)) {
        LMSendReply(request->head.msgh_remote_port, NULL, 0);
        LMResponseBufferFree((LMResponseBuffer *)bytes);
        return;
    }
    // Send Response
    const void *data = LMMessageGetData(request);
    size_t length = LMMessageGetDataLength(request);
    mach_port_t replyPort = request->head.msgh_remote_port;
    CFDataRef cfdata = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)(data ?: &data), length, kCFAllocatorNull);
    processMessage(request->head.msgh_id, replyPort, cfdata);
    if (cfdata)
        CFRelease(cfdata);
    LMResponseBufferFree((LMResponseBuffer *)bytes);
}

- (id)init
{
    if ((self = [super init])) {
        kern_return_t err = LMStartService(connection.serverName, CFRunLoopGetCurrent(), machPortCallback);
        if (err) {
            NSLog(@"AppList: Unable to register mach server with error %x", err);
        }
    }
    return self;
}

static LSApplicationWorkspace *appWorkspace(void);
static LSPlugInKitProxy *extensionWithPluginIdentifier(NSString *pluginIdentifier);

static inline NSMutableDictionary *dictionaryOfExtensionsList(id<NSFastEnumeration> extensions)
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (LSPlugInKitProxy *app in extensions) {
        NSString *displayName = [[app localizedName] description];
        if (displayName) {
            NSString *displayIdentifier = [[app pluginIdentifier] description];
            if (displayIdentifier) {
                [result setObject:displayName forKey:displayIdentifier];
            }
        }
    }
    return result;
}

- (NSDictionary *)extensions {
    return dictionaryOfExtensionsList([appWorkspace() installedPlugins]);
}

-(NSInteger)extensionCount {
    return [[appWorkspace() installedPlugins] count];
}

-(NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate {
    NSArray *plugins = [appWorkspace() installedPlugins];
    if (predicate)
        plugins = [plugins filteredArrayUsingPredicate:predicate];
    return dictionaryOfExtensionsList(plugins);
}

- (NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate sysVerAvaliable:(BOOL)sysVerAvaliable titleSortedIdentifiers:(NSArray **)outSortedByTitle
{
    NSArray *apps = [appWorkspace() installedPlugins];
    if (predicate)
        apps = [apps filteredArrayUsingPredicate:predicate];
    NSMutableDictionary *result;
    if (sysVerAvaliable) {
        float sysVer = [UIDevice currentDevice].systemVersion.floatValue;
        result = dictionaryOfExtensionsList([apps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"infoPlist['MinimumOSVersion'].floatValue <= %f",sysVer]]);
    } else {
        result = dictionaryOfExtensionsList(apps);
    }
    if (outSortedByTitle) {
        // Generate a sorted list of apps
        *outSortedByTitle = [[result allKeys] sortedArrayUsingFunction:DictionaryTextComparator context:result];
    }
    return result;
}

- (id)valueForKeyPath:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier
{
    return [extensionWithPluginIdentifier(displayIdentifier) valueForKeyPath:keyPath];
}

- (id)valueForKey:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier
{
    return [extensionWithPluginIdentifier(displayIdentifier) valueForKey:keyPath];
}

- (CGImageRef)copyIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier
{
    if (![NSThread isMainThread]) {
        return [super copyIconOfSize:iconSize forDisplayIdentifier:displayIdentifier];
    }
    return NULL;
}

@end

static LSApplicationWorkspace *appWorkspace(void)
{
    static LSApplicationWorkspace *cached;
    LSApplicationWorkspace *result = cached;
    if (!result) {
        result = cached = (LSApplicationWorkspace *)[%c(LSApplicationWorkspace) defaultWorkspace];
    }
    return result;
}

static LSPlugInKitProxy *extensionWithPluginIdentifier(NSString *displayIdentifier)
{
    return [%c(LSPlugInKitProxy) pluginKitProxyForIdentifier:displayIdentifier];
}

%ctor
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (%c(SBIconModel)) {
        sharedExtensionList = [[ELExtensionListImpl alloc] init];
    }
    [pool drain];
}
