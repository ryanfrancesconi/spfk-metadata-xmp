// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#include <iostream>
#include "XMPLifecycle.hpp"

bool XMPLifecycle::isInitialized() {
    return _isInitialized;
}

bool XMPLifecycle::initialize() {
    if (_isInitialized) {
        return true;
    }

    if (!SXMPMeta::Initialize()) {
        std::cout << "Could not initialize toolkit!";

        return false;
    }

    XMP_OptionBits options = 0;

#if UNIX_ENV
    options |= kXMPFiles_ServerMode;
#endif

    // Must initialize SXMPFiles before we use it
    if (!SXMPFiles::Initialize(options) ) {
        std::cout << "Could not initialize SXMPFiles.";
        return false;
    }

    _isInitialized = true;
    return true;
}

void XMPLifecycle::terminate() {
    if (!_isInitialized) {
        return;
    }

    SXMPFiles::Terminate();
    SXMPMeta::Terminate();
}
