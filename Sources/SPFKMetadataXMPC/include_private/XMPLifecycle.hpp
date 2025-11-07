// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMPC

#ifndef XMPLifecycle_H
#define XMPLifecycle_H

#include <iostream>

#define MAC_ENV              1

// Must be defined to instantiate template classes
#define TXMP_STRING_TYPE     std::string

// Must be defined to give access to XMPFiles
#define XMP_INCLUDE_XMPFILES 1

// Ensure XMP templates are instantiated
#include "XMP.incl_cpp"

// Provide access to the API
#include "XMP.hpp"

class XMPLifecycle {
private:
    inline static bool _isInitialized = false;

public:
    static bool isInitialized();
    static bool initialize();
    static void terminate();
};

#endif // !XMPLifecycle_H
