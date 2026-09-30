// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPFile_H
#define XMPFile_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One property to write in a batch `setProperties:toPath:` call.
/// Mirrors the C++ `XMPPropertyWrite` struct on the ObjC++ side of the bridge.
@interface XMPPropertyWriteEntry : NSObject

@property (nonatomic, strong, readonly) NSString *ns;
@property (nonatomic, strong, readonly) NSString *propName;
@property (nonatomic, strong, readonly) NSArray<NSString *> *values;
@property (nonatomic, readonly) bool isArray;
@property (nonatomic, readonly) bool isOrdered;
@property (nonatomic, readonly) bool isLocalized;

@property (nonatomic, readonly) bool isRemoval;

/// `isArray: false` uses `values.firstObject` as a single simple value.
/// `isArray: true` replaces the whole array with `values`, in order: an `rdf:Seq` when
/// `isOrdered`, an `rdf:Bag` otherwise.
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                    values:(nonnull NSArray<NSString *> *)values
                                   isArray:(bool)isArray
                                 isOrdered:(bool)isOrdered;

/// Writes `value` as the `x-default` entry of an `rdf:Alt` language alternative, keeping the
/// other languages' entries.
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                            localizedValue:(nonnull NSString *)value;

/// Removes the property entirely rather than writing a value.
///
/// An empty value is not a removal: writing `""` stores a literal empty value. This deletes the
/// whole subtree, so a language alternative clears in every language rather than leaving
/// entries the user cannot see or edit.
- (nonnull instancetype)initWithRemovalOfNamespace:(nonnull NSString *)ns
                                           propName:(nonnull NSString *)propName;

@end

/// One property to read in a batch `getProperties:fromPath:error:` call.
@interface XMPPropertyReadEntry : NSObject

@property (nonatomic, strong, readonly) NSString *ns;
@property (nonatomic, strong, readonly) NSString *propName;
@property (nonatomic, readonly) bool isArray;

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                   isArray:(bool)isArray;

@end

/// `NSError` codes in the `XMPFile` domain.
typedef NS_ENUM(NSInteger, XMPFileErrorCode) {
    /// The file could not be opened or the toolkit failed reading it.
    XMPFileErrorCodeFailed = 1,
    /// The file was read and holds no XMP.
    XMPFileErrorCodeNoPacket = 2,
};

@interface XMPFile : NSObject

/// The file's XMP packet as an XML string, or nil with an error whose code is
/// `XMPFileErrorCodeNoPacket` when it has none and `XMPFileErrorCodeFailed` when it can't be read.
+ (nullable NSString *)xmpStringAtPath:(nonnull NSString *)path
                                 error:(NSError * _Nullable * _Nullable)error;

/// write XMP xml string to file (XMP chunk only, no reconciliation)
+ (bool)write:(nonnull NSString *)xmlString
       toPath:(nonnull NSString *)toPath
        error:(NSError * _Nullable * _Nullable)error;

/// write XMP xml string to file WITH reconciliation to native chunks (BEXT, iXML)
+ (bool)writeReconciled:(nonnull NSString *)xmlString
                 toPath:(nonnull NSString *)toPath
                  error:(NSError * _Nullable * _Nullable)error;

/// Set a single simple-value XMP property, preserving all other existing content
/// (load-then-mutate-then-put, unlike write:toPath: which overwrites the whole packet).
+ (bool)setProperty:(nonnull NSString *)ns
            propName:(nonnull NSString *)propName
               value:(nonnull NSString *)value
              toPath:(nonnull NSString *)toPath
               error:(NSError * _Nullable * _Nullable)error;

/// Replace a whole array-value XMP property (e.g. dc:subject) with `values`, preserving
/// all other existing content. `isOrdered` selects rdf:Seq (true) vs rdf:Bag (false, the
/// default for most XMP arrays including dc:subject).
+ (bool)setArrayProperty:(nonnull NSString *)ns
                 propName:(nonnull NSString *)propName
                   values:(nonnull NSArray<NSString *> *)values
                isOrdered:(bool)isOrdered
                   toPath:(nonnull NSString *)toPath
                    error:(NSError * _Nullable * _Nullable)error;

/// Write multiple properties (simple, array, and/or removals) in a single open/read/[mutations]/
/// write/close cycle — fewer open/close cycles than repeated setProperty/setArrayProperty
/// calls, and avoids the interleaved-thread stale-state window between separate calls.
+ (bool)setProperties:(nonnull NSArray<XMPPropertyWriteEntry *> *)properties
                toPath:(nonnull NSString *)toPath
                 error:(NSError * _Nullable * _Nullable)error;

/// Reads several properties in one open/read/close cycle. The returned array is index-aligned
/// with `properties`: a scalar yields zero or one value, an array yields one entry per item, and
/// an absent property yields an empty array — absence is the ordinary state of most fields.
+ (nullable NSArray<NSArray<NSString *> *> *)getProperties:(nonnull NSArray<XMPPropertyReadEntry *> *)properties
                                                   fromPath:(nonnull NSString *)fromPath
                                                      error:(NSError * _Nullable * _Nullable)error;

/// Writes the first item of the xmpDM:Tracks bag's trackType/trackName fields, creating
/// the Tracks bag and its first (struct-typed) item if none exists yet. Pass an empty
/// string to leave a field unchanged.
+ (bool)setTrackType:(nonnull NSString *)trackType
            trackName:(nonnull NSString *)trackName
               toPath:(nonnull NSString *)toPath
                error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif /* XMPFile_H */
