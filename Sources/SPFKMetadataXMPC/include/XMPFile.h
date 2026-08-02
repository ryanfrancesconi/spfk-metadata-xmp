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

@property (nonatomic, readonly) bool isRemoval;

/// `isArray: false` uses `values.firstObject` as a single simple value.
/// `isArray: true` replaces the whole array with `values`, in order (rdf:Bag form).
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                    values:(nonnull NSArray<NSString *> *)values
                                   isArray:(bool)isArray;

/// Removes the property entirely rather than writing a value.
///
/// An empty value is not a removal: writing `""` stores a literal empty value, and on a
/// property the toolkit has reconciled into a language alternative (`dc:title`,
/// `dc:description`, `dc:rights`) it fails outright with "Composite nodes can't have values".
/// This deletes the whole subtree, so a lang-alt clears in every language rather than leaving
/// entries the user cannot see or edit.
- (nonnull instancetype)initWithRemovalOfNamespace:(nonnull NSString *)ns
                                           propName:(nonnull NSString *)propName;

@end

@interface XMPFile : NSObject

@property (nonatomic, strong, nullable) NSString *xmpString;

/// get XMP metadata as a XML string
/// - Parameter path: path to the file to parse
- (nullable instancetype)initWithPath:(nonnull NSString *)path;

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
