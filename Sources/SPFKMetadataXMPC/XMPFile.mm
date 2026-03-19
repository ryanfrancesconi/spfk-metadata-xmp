// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <iostream>

#import <Foundation/Foundation.h>
#import "XMPFile.h"

#import "XMPUtil.hpp"

@implementation XMPFile : NSObject

- (nullable instancetype)initWithPath:(nonnull NSString *)path {
    self = [super init];

    std::string xml = XMPUtil::getXMP(path.UTF8String);

    if (xml.length() == 0) {
        return NULL;
    }

    _xmpString = [NSString stringWithCString:xml.c_str()
                                    encoding:NSUTF8StringEncoding];

    return self;
}

+ (bool)write:(NSString *)xmlString
       toPath:(NSString *)toPath {
    //
    return XMPUtil::writeXMP(xmlString.UTF8String, toPath.UTF8String);
}

+ (bool)writeReconciled:(NSString *)xmlString
                 toPath:(NSString *)toPath {
    return XMPUtil::writeXMPReconciled(xmlString.UTF8String, toPath.UTF8String);
}

@end
