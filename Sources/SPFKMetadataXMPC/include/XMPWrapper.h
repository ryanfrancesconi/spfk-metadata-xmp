// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps XMPLifecycle for Swift interop
@interface XMPWrapper : NSObject

+ (bool)initialize;
+ (bool)isInitialized;
+ (void)terminate;

@end

NS_ASSUME_NONNULL_END
