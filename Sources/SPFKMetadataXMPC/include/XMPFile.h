// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#ifndef XMPFile_H
#define XMPFile_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XMPFile : NSObject

@property (nonatomic, strong, nullable) NSString *xmpString;

/// get XMP metadata as a XML string
/// - Parameter path: path to the file to parse
- (nullable id)initWithPath:(nonnull NSString *)path;

/// write XMP xml string to file
+ (bool)write:(nonnull NSString *)xmlString
       toPath:(nonnull NSString *)toPath;

@end

NS_ASSUME_NONNULL_END

#endif /* XMPFile_H */
