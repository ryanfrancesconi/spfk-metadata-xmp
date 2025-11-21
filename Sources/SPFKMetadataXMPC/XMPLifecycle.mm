// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import "XMPLifecycleCXX.hpp"
#import "XMPLifecycle.h"

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

@end
