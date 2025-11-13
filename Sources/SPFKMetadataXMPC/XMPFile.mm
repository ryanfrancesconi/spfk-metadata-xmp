// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#include <iostream>

#import <Foundation/Foundation.h>
#import "XMPFile.h"

#import "XMPUtil.hpp"

@implementation XMPFile : NSObject

- (nullable id)initWithPath:(nonnull NSString *)path {
    self = [super init];

    std::string xml = XMPUtil::getXMP(path.UTF8String);

    if (xml.length() == 0) {
        return NULL;
    }

    _xmpString = [NSString stringWithCString:xml.c_str()
                                    encoding:NSUTF8StringEncoding];

    return self;
}

+ (void)write:(NSString *)xmlString
       toPath:(NSString *)toPath {
    //
    XMPUtil::writeXMP(xmlString.UTF8String, toPath.UTF8String);
}

@end
