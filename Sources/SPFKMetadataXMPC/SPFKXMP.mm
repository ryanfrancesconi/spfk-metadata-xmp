#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import "SPFKXMP.h"
#import "XMPLifecycle.hpp"

@implementation SPFKXMP

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
