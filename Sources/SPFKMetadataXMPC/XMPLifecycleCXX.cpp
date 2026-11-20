// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#include <iostream>
#include "XMPLifecycleCXX.hpp"

std::mutex XMPLifecycleCXX::_mutex;
std::mutex XMPLifecycleCXX::operationMutex;

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
    // Acquire the operation mutex first so we cannot race with an in-progress
    // getXMP/writeXMP call that is already inside OpenFile().  Without this,
    // SXMPFiles::Terminate() would zero the format-handler function pointers
    // while another thread is dispatching through them, causing a null-pointer crash.
    std::lock_guard<std::mutex> opLock(operationMutex);
    std::lock_guard<std::mutex> lock(_mutex);

    if (!_isInitialized) {
        return;
    }

    SXMPFiles::Terminate();
    SXMPMeta::Terminate();
    _isInitialized = false;
}

bool XMPLifecycleCXX::registerNamespace(const std::string& uri, const std::string& suggestedPrefix, std::string* registeredPrefix, std::string* errorMessage) {
    initialize();
    std::lock_guard<std::mutex> lock(operationMutex);

    try {
        SXMPMeta::RegisterNamespace(uri.c_str(), suggestedPrefix.c_str(), registeredPrefix);
    } catch (XMP_Error & e) {
        if (errorMessage != nullptr) *errorMessage = e.GetErrMsg();
        return false;
    }

    return true;
}
