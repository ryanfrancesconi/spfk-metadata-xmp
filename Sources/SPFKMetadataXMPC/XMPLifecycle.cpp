// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

//#ifndef XMPLifecycle_H
//#define XMPLifecycle_H
//
//#include <iostream>
//
//#define MAC_ENV              1
//
//// Must be defined to instantiate template classes
//#define TXMP_STRING_TYPE     std::string
//
//// Must be defined to give access to XMPFiles
//#define XMP_INCLUDE_XMPFILES 1
//
//// Ensure XMP templates are instantiated
//#include "XMP.incl_cpp"
//
//// Provide access to the API
//#include "XMP.hpp"
//
//class XMPLifecycle {
//private:
//    inline static bool _isInitialized = false;
//
//public:
//    // MARK: - Init
//
//    static bool isInitialized() {
//        return _isInitialized;
//    }
//
//    static bool initialize() {
//        if (_isInitialized) {
//            return true;
//        }
//
//        if (!SXMPMeta::Initialize()) {
//            std::cout << "Could not initialize toolkit!";
//
//            return false;
//        }
//
//        XMP_OptionBits options = 0;
//
//#if UNIX_ENV
//        options |= kXMPFiles_ServerMode;
//#endif
//
//        // Must initialize SXMPFiles before we use it
//        if (!SXMPFiles::Initialize(options) ) {
//            std::cout << "Could not initialize SXMPFiles.";
//            return false;
//        }
//
//        _isInitialized = true;
//        return true;
//    }
//
//    static void terminate() {
//        if (!_isInitialized) {
//            return;
//        }
//
//        SXMPFiles::Terminate();
//        SXMPMeta::Terminate();
//    }
//};
//
//#endif // !XMPLifecycle_H

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
