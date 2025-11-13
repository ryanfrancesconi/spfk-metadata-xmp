// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import "XMPLifecycle.hpp"
#import "XMPWrapper.h"

@implementation XMPWrapper

+ (bool)isInitialized {
    return XMPLifecycle::isInitialized();
}

+ (bool)initialize {
    XMPLifecycle::initialize();
}

+ (void)terminate {
    NSLog(@"Terminating SXMPFiles + SXMPMeta...");

    XMPLifecycle::terminate();
}

@end
