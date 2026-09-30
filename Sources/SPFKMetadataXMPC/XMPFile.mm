// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <iostream>

#import <Foundation/Foundation.h>
#import "XMPFile.h"

#import "XMPUtil.hpp"

@implementation XMPPropertyWriteEntry : NSObject

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                    values:(nonnull NSArray<NSString *> *)values
                                   isArray:(bool)isArray
                                 isOrdered:(bool)isOrdered {
    self = [super init];
    _ns = ns;
    _propName = propName;
    _values = values;
    _isArray = isArray;
    _isOrdered = isOrdered;
    _isLocalized = false;
    _isRemoval = false;
    return self;
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                            localizedValue:(nonnull NSString *)value {
    self = [super init];
    _ns = ns;
    _propName = propName;
    _values = @[value];
    _isArray = false;
    _isLocalized = true;
    _isRemoval = false;
    return self;
}

- (nonnull instancetype)initWithRemovalOfNamespace:(nonnull NSString *)ns
                                           propName:(nonnull NSString *)propName {
    self = [super init];
    _ns = ns;
    _propName = propName;
    _values = @[];
    _isArray = false;
    _isLocalized = false;
    _isRemoval = true;
    return self;
}

@end

@implementation XMPPropertyReadEntry : NSObject

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                                  propName:(nonnull NSString *)propName
                                   isArray:(bool)isArray {
    self = [super init];
    _ns = ns;
    _propName = propName;
    _isArray = isArray;
    return self;
}

@end

@implementation XMPFile : NSObject

/// Builds an `NSError` from a C++ failure message, or `nil` if the message is empty
/// (defensive — every failure path in `XMPUtil.cpp` populates it, but an empty message
/// shouldn't produce a blank-description error).
static NSError * _Nullable XMPFileError(const std::string &message) {
    if (message.empty()) {
        return nil;
    }
    NSString *description = [NSString stringWithUTF8String:message.c_str()];
    return [NSError errorWithDomain:@"XMPFile"
                                code:XMPFileErrorCodeFailed
                            userInfo:@{NSLocalizedDescriptionKey: description}];
}

+ (nullable NSString *)xmpStringAtPath:(NSString *)path
                                 error:(NSError * _Nullable * _Nullable)error {
    std::string xml;
    bool hasPacket = false;
    std::string errorMessage;

    if (!XMPUtil::getXMP(path.UTF8String, &xml, &hasPacket, &errorMessage)) {
        if (error != nullptr) {
            *error = XMPFileError(errorMessage.empty() ? "Failed to read XMP" : errorMessage);
        }
        return nil;
    }

    if (!hasPacket) {
        if (error != nullptr) {
            *error = [NSError errorWithDomain:@"XMPFile"
                                         code:XMPFileErrorCodeNoPacket
                                     userInfo:@{NSLocalizedDescriptionKey: @"The file holds no XMP"}];
        }
        return nil;
    }

    NSString *string = [NSString stringWithUTF8String:xml.c_str()];

    if (string == nil && error != nullptr) {
        *error = XMPFileError("The XMP packet is not valid UTF-8");
    }

    return string;
}

+ (bool)write:(NSString *)xmlString
       toPath:(NSString *)toPath
        error:(NSError * _Nullable * _Nullable)error {
    std::string errorMessage;
    bool ok = XMPUtil::writeXMP(xmlString.UTF8String, toPath.UTF8String, &errorMessage);
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

+ (bool)applyChangesFromBaseline:(nullable NSString *)baseline
                          edited:(NSString *)edited
                          toPath:(NSString *)toPath
                           error:(NSError * _Nullable * _Nullable)error {
    std::string baselineString = baseline == nil ? "" : baseline.UTF8String;
    std::string errorMessage;
    bool ok = XMPUtil::applyXMPChanges(
        baseline == nil ? nullptr : &baselineString, edited.UTF8String, toPath.UTF8String, &errorMessage
    );
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

+ (bool)setProperty:(NSString *)ns
            propName:(NSString *)propName
               value:(NSString *)value
              toPath:(NSString *)toPath
               error:(NSError * _Nullable * _Nullable)error {
    std::string errorMessage;
    bool ok = XMPUtil::setXMPProperty(toPath.UTF8String, ns.UTF8String, propName.UTF8String, value.UTF8String, &errorMessage);
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

+ (bool)setArrayProperty:(NSString *)ns
                 propName:(NSString *)propName
                   values:(NSArray<NSString *> *)values
                isOrdered:(bool)isOrdered
                   toPath:(NSString *)toPath
                    error:(NSError * _Nullable * _Nullable)error {
    std::vector<std::string> cppValues;
    cppValues.reserve(values.count);
    for (NSString *value in values) {
        cppValues.push_back(value.UTF8String);
    }

    XMP_OptionBits arrayForm = isOrdered ? kXMP_PropArrayIsOrdered : kXMP_PropArrayIsUnordered;

    std::string errorMessage;
    bool ok = XMPUtil::setXMPArrayProperty(toPath.UTF8String, ns.UTF8String, propName.UTF8String, cppValues, arrayForm, &errorMessage);
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

+ (bool)setProperties:(NSArray<XMPPropertyWriteEntry *> *)properties
                toPath:(NSString *)toPath
                 error:(NSError * _Nullable * _Nullable)error {
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
        write.isOrdered = entry.isOrdered;
        write.isLocalized = entry.isLocalized;
        write.isRemoval = entry.isRemoval;
        cppProperties.push_back(write);
    }

    std::string errorMessage;
    bool ok = XMPUtil::setXMPProperties(toPath.UTF8String, cppProperties, &errorMessage);
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

+ (nullable NSArray<NSArray<NSString *> *> *)getProperties:(NSArray<XMPPropertyReadEntry *> *)properties
                                                   fromPath:(NSString *)fromPath
                                                      error:(NSError * _Nullable * _Nullable)error {
    std::vector<XMPUtil::XMPPropertyRead> cppRequests;
    cppRequests.reserve(properties.count);

    for (XMPPropertyReadEntry *entry in properties) {
        XMPUtil::XMPPropertyRead request;
        request.ns = entry.ns.UTF8String;
        request.propName = entry.propName.UTF8String;
        request.isArray = entry.isArray;
        cppRequests.push_back(request);
    }

    std::vector<std::vector<std::string>> cppResults;
    std::string errorMessage;

    if (!XMPUtil::getXMPProperties(fromPath.UTF8String, cppRequests, &cppResults, &errorMessage)) {
        if (error != nullptr) {
            *error = XMPFileError(errorMessage);
        }
        return nil;
    }

    NSMutableArray<NSArray<NSString *> *> *results = [NSMutableArray arrayWithCapacity:cppResults.size()];
    for (const auto& values : cppResults) {
        NSMutableArray<NSString *> *converted = [NSMutableArray arrayWithCapacity:values.size()];
        for (const auto& value : values) {
            [converted addObject:[NSString stringWithUTF8String:value.c_str()]];
        }
        [results addObject:converted];
    }

    return results;
}

+ (bool)setTrackType:(NSString *)trackType
            trackName:(NSString *)trackName
               toPath:(NSString *)toPath
                error:(NSError * _Nullable * _Nullable)error {
    std::string errorMessage;
    bool ok = XMPUtil::setXMPTrackInfo(toPath.UTF8String, trackType.UTF8String, trackName.UTF8String, &errorMessage);
    if (!ok && error != nullptr) {
        *error = XMPFileError(errorMessage);
    }
    return ok;
}

@end
