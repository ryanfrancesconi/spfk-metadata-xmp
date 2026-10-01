// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#import <Foundation/Foundation.h>

#import "XMPPacket.h"
#import "XMPUtil.hpp"

@implementation XMPPacket : NSObject

static NSError *XMPPacketError(const std::string &message) {
    NSString *description = [NSString stringWithUTF8String:message.empty() ? "XMP packet operation failed" : message.c_str()];
    return [NSError errorWithDomain:@"XMPFile"
                                code:XMPFileErrorCodeFailed
                            userInfo:@{NSLocalizedDescriptionKey: description ?: @""}];
}

static NSString *XMPPacketString(const std::string &value) {
    return [NSString stringWithUTF8String:value.c_str()] ?: @"";
}

+ (nullable NSArray<NSArray<NSString *> *> *)getProperties:(NSArray<XMPPropertyReadEntry *> *)properties
                                                  inPacket:(NSString *)packet
                                                     error:(NSError * _Nullable * _Nullable)error {
    std::vector<XMPUtil::XMPPropertyRead> requests;
    requests.reserve(properties.count);

    for (XMPPropertyReadEntry *entry in properties) {
        requests.push_back({ entry.ns.UTF8String, entry.propName.UTF8String, entry.isArray });
    }

    std::vector<std::vector<std::string>> values;
    std::string errorMessage;

    if (!XMPUtil::getPacketProperties(packet.UTF8String, requests, &values, &errorMessage)) {
        if (error != nullptr) *error = XMPPacketError(errorMessage);
        return nil;
    }

    NSMutableArray<NSArray<NSString *> *> *results = [NSMutableArray arrayWithCapacity:values.size()];
    for (const auto &items : values) {
        NSMutableArray<NSString *> *converted = [NSMutableArray arrayWithCapacity:items.size()];
        for (const auto &item : items) {
            [converted addObject:XMPPacketString(item)];
        }
        [results addObject:converted];
    }

    return results;
}

+ (nullable NSArray<NSArray<NSString *> *> *)changedPropertiesFromBaseline:(nullable NSString *)baseline
                                                                    edited:(NSString *)edited
                                                                     error:(NSError * _Nullable * _Nullable)error {
    std::string baselineString = baseline == nil ? "" : baseline.UTF8String;
    std::vector<XMPUtil::PropertyKey> changed;
    std::string errorMessage;

    if (!XMPUtil::changedXMPProperties(baseline == nil ? nullptr : &baselineString, edited.UTF8String, &changed, &errorMessage)) {
        if (error != nullptr) *error = XMPPacketError(errorMessage);
        return nil;
    }

    NSMutableArray<NSArray<NSString *> *> *results = [NSMutableArray arrayWithCapacity:changed.size()];
    for (const auto &key : changed) {
        [results addObject:@[ XMPPacketString(key.first), XMPPacketString(key.second) ]];
    }

    return results;
}

+ (nullable NSString *)mergeChangesFromBaseline:(nullable NSString *)baseline
                                         edited:(NSString *)edited
                                           onto:(nullable NSString *)current
                                          error:(NSError * _Nullable * _Nullable)error {
    std::string baselineString = baseline == nil ? "" : baseline.UTF8String;
    std::string currentString = current == nil ? "" : current.UTF8String;
    std::string merged;
    std::string errorMessage;

    bool ok = XMPUtil::mergeXMPChanges(
        baseline == nil ? nullptr : &baselineString,
        edited.UTF8String,
        current == nil ? nullptr : &currentString,
        &merged,
        &errorMessage
    );

    if (!ok) {
        if (error != nullptr) *error = XMPPacketError(errorMessage);
        return nil;
    }

    return XMPPacketString(merged);
}

@end
