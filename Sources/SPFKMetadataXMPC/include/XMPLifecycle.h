// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#ifndef XMPWrapper_H
#define XMPWrapper_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps XMPLifecycle for Swift interop. API will be initialized automatically lazily, but
/// terminate should be called on application shutdown once.
@interface XMPLifecycle : NSObject

+ (bool)initialize;
+ (bool)isInitialized;
+ (void)terminate;

@end

NS_ASSUME_NONNULL_END

#endif // !XMPWrapper_H
