// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMP

#ifndef SPFKXMPFILE_H
#define SPFKXMPFILE_H

#import <Foundation/Foundation.h>

#include "SPFKXMPFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPFKXMPFile : NSObject

@property (nonatomic, strong, nullable) NSString *xmpString;

- (nullable id)initWithPath:(nonnull NSString *)path;

+ (void)write:(nonnull NSString *)xmlString
       toPath:(nonnull NSString *)toPath;

@end

NS_ASSUME_NONNULL_END

#endif /* SPFKXMPFILE_H */
