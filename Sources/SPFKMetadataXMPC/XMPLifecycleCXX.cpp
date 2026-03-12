// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <iostream>
#include "XMPLifecycleCXX.hpp"

std::mutex XMPLifecycleCXX::_mutex;

bool XMPLifecycleCXX::isInitialized() {
    std::lock_guard<std::mutex> lock(_mutex);
    return _isInitialized;
}

bool XMPLifecycleCXX::initialize() {
    std::lock_guard<std::mutex> lock(_mutex);

    if (_isInitialized) {
        return true;
    }

    if (!SXMPMeta::Initialize()) {
        std::cout << "Could not initialize toolkit!" << std::endl;

        return false;
    }

    XMP_OptionBits options = 0;

    // Must initialize SXMPFiles before we use it
    if (!SXMPFiles::Initialize(options) ) {
        std::cout << "Could not initialize SXMPFiles." << std::endl;
        return false;
    }

    _isInitialized = true;
    return true;
}

void XMPLifecycleCXX::terminate() {
    std::lock_guard<std::mutex> lock(_mutex);

    if (!_isInitialized) {
        return;
    }

    SXMPFiles::Terminate();
    SXMPMeta::Terminate();
    _isInitialized = false;
}
