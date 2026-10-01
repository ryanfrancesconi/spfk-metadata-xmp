// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPPacket_H
#define XMPPacket_H

#import <Foundation/Foundation.h>

#import "XMPFile.h"

NS_ASSUME_NONNULL_BEGIN

/// Packet operations that touch no file: XMPCore alone, no format handler.
@interface XMPPacket : NSObject

/// `XMPFile.getProperties:fromPath:error:` over a packet string.
+ (nullable NSArray<NSArray<NSString *> *> *)getProperties:(nonnull NSArray<XMPPropertyReadEntry *> *)properties
                                                  inPacket:(nonnull NSString *)packet
                                                     error:(NSError * _Nullable * _Nullable)error;

/// The top-level properties that differ between the packets, each as `[namespace, path]`.
+ (nullable NSArray<NSArray<NSString *> *> *)changedPropertiesFromBaseline:(nullable NSString *)baseline
                                                                    edited:(nonnull NSString *)edited
                                                                     error:(NSError * _Nullable * _Nullable)error;

/// Applies the properties that differ between `baseline` and `edited` onto `current`, serialized
/// with the packet wrapper and padding. An empty string when the result holds no properties.
+ (nullable NSString *)mergeChangesFromBaseline:(nullable NSString *)baseline
                                         edited:(nonnull NSString *)edited
                                           onto:(nullable NSString *)current
                                          error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* XMPPacket_H */
