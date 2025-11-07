#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#import "SPFKXMP.h"
#import "XMPUtil.hpp"

@implementation SPFKXMP

+ (bool)isInitialized {
    return XMPUtil::isInitialized();
}

+ (bool)initialize {
    XMPUtil::initialize();
}

+ (void)terminate {
    NSLog(@"Terminating SXMPFiles + SXMPMeta...");

    XMPUtil::terminate();
}

@end
