// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps XMPLifecycle for Swift interop. API will be initialized automatically lazily, but
/// terminate should be called on application shutdown once.
@interface XMPLifecycle : NSObject

+ (bool)initialize;
+ (bool)isInitialized;
+ (void)terminate;

/// Registers a schema namespace for the rest of the process, returning the prefix in use for it.
/// Repeating the call returns the prefix already registered.
+ (nullable NSString *)registerNamespace:(nonnull NSString *)uri
                         suggestedPrefix:(nonnull NSString *)suggestedPrefix
                                   error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
