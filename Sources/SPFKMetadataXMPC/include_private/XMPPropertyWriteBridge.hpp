// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#pragma once

#import <Foundation/Foundation.h>

#include <vector>

#include "XMPUtil.hpp"

@class XMPPropertyWriteEntry;

namespace XMPPropertyWriteBridge {
    /// The C++ writes the entries describe, in order.
    std::vector<XMPPropertyWrite> fromEntries(NSArray<XMPPropertyWriteEntry *> *entries);
}
