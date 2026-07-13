// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <iostream>

#import <Foundation/Foundation.h>
#import "XMPFile.h"

#import "XMPUtil.hpp"

@implementation XMPPropertyWriteEntry : NSObject

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                    values:(nonnull NSArray<NSString *> *)values
                                   isArray:(bool)isArray {
    self = [super init];
    _ns = ns;
    _propName = propName;
    _values = values;
    _isArray = isArray;
    return self;
}

@end

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

+ (bool)setProperty:(NSString *)ns
            propName:(NSString *)propName
               value:(NSString *)value
              toPath:(NSString *)toPath {
    return XMPUtil::setXMPProperty(toPath.UTF8String, ns.UTF8String, propName.UTF8String, value.UTF8String);
}

+ (bool)setArrayProperty:(NSString *)ns
                 propName:(NSString *)propName
                   values:(NSArray<NSString *> *)values
                isOrdered:(bool)isOrdered
                   toPath:(NSString *)toPath {
    std::vector<std::string> cppValues;
    cppValues.reserve(values.count);
    for (NSString *value in values) {
        cppValues.push_back(value.UTF8String);
    }

    XMP_OptionBits arrayForm = isOrdered ? kXMP_PropArrayIsOrdered : kXMP_PropArrayIsUnordered;

    return XMPUtil::setXMPArrayProperty(toPath.UTF8String, ns.UTF8String, propName.UTF8String, cppValues, arrayForm);
}

+ (bool)setProperties:(NSArray<XMPPropertyWriteEntry *> *)properties
                toPath:(NSString *)toPath {
    std::vector<XMPPropertyWrite> cppProperties;
    cppProperties.reserve(properties.count);

    for (XMPPropertyWriteEntry *entry in properties) {
        std::vector<std::string> cppValues;
        cppValues.reserve(entry.values.count);
        for (NSString *value in entry.values) {
            cppValues.push_back(value.UTF8String);
        }

        XMPPropertyWrite write;
        write.ns = entry.ns.UTF8String;
        write.propName = entry.propName.UTF8String;
        write.values = cppValues;
        write.isArray = entry.isArray;
        cppProperties.push_back(write);
    }

    return XMPUtil::setXMPProperties(toPath.UTF8String, cppProperties);
}

@end
