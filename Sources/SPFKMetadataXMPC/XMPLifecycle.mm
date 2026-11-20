// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import "XMPFile.h"
#import "XMPLifecycle.h"
#import "XMPLifecycleCXX.hpp"

@implementation XMPLifecycle

+ (bool)isInitialized {
    return XMPLifecycleCXX::isInitialized();
}

+ (bool)initialize {
    return XMPLifecycleCXX::initialize();
}

+ (void)terminate {
    NSLog(@"Terminating SXMPFiles + SXMPMeta...");

    XMPLifecycleCXX::terminate();
}

+ (nullable NSString *)registerNamespace:(NSString *)uri
                         suggestedPrefix:(NSString *)suggestedPrefix
                                   error:(NSError * _Nullable * _Nullable)error {
    std::string registeredPrefix;
    std::string errorMessage;

    if (!XMPLifecycleCXX::registerNamespace(uri.UTF8String, suggestedPrefix.UTF8String, &registeredPrefix, &errorMessage)) {
        if (error != nullptr) {
            NSString *description = [NSString stringWithUTF8String:errorMessage.c_str()] ?: @"";
            *error = [NSError errorWithDomain:@"XMPFile"
                                         code:XMPFileErrorCodeFailed
                                     userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    // The toolkit returns the prefix with its separator, `prefix:`.
    if (!registeredPrefix.empty() && registeredPrefix.back() == ':') registeredPrefix.pop_back();

    return [NSString stringWithUTF8String:registeredPrefix.c_str()];
}

@end
