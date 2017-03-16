//
//  ExtensionList.h
//  ExtensionList
//
//  Created by duyongchao on 2017/3/13.
//
//

#ifndef ExtensionList_h
#define ExtensionList_h

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <libkern/OSAtomic.h>

enum {
    ALApplicationIconSizeSmall = 29,
    ALApplicationIconSizeLarge = 59
};
typedef NSUInteger ALApplicationIconSize;

@interface ELExtensionList : NSObject {
@private
    NSMutableDictionary *cachedIcons;
    OSSpinLock spinLock;
}
+ (ELExtensionList *)sharedExtensionList;

@property (nonatomic, readonly) NSDictionary *extensions;
- (NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate;
- (NSDictionary *)extensionsFilteredUsingPredicate:(NSPredicate *)predicate sysVerAvaliable:(BOOL)sysVerAvaliable titleSortedIdentifiers:(NSArray **)outSortedByTitle;

- (id)valueForKeyPath:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier;
- (id)valueForKey:(NSString *)keyPath forDisplayIdentifier:(NSString *)displayIdentifier;

- (CGImageRef)copyIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier;
- (UIImage *)iconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier;
- (BOOL)hasCachedIconOfSize:(ALApplicationIconSize)iconSize forDisplayIdentifier:(NSString *)displayIdentifier;

// private
- (NSInteger)extensionCount;

@end

extern NSString *const ALIconLoadedNotification;
extern NSString *const ALDisplayIdentifierKey;
extern NSString *const ALIconSizeKey;

#endif /* ExtensionList_h */
