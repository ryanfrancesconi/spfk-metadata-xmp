// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#pragma once

#include <iostream>
#include <mutex>
#include <string>

/// One of MAC_ENV, WIN_ENV, UNIX_ENV or IOS_ENV must be defined by the client
/// Also defined in XMP_Environment.h
#define MAC_ENV              1

/// Must be defined to instantiate template classes
#define TXMP_STRING_TYPE     std::string

/// Must be defined to give access to XMPFiles
#define XMP_INCLUDE_XMPFILES 1

/// Ensure XMP templates are instantiated
#include "XMP.incl_cpp"

/// Provide access to the API
#include "XMP.hpp"

class XMPLifecycleCXX {
private:
    inline static bool _isInitialized = false;
    static std::mutex _mutex;

public:
    static bool isInitialized();
    static bool initialize();
    static void terminate();

    /// Registers `uri` for the rest of the process, returning the prefix in use for it: the
    /// existing one when the URI is already registered. False with `errorMessage` set on failure.
    static bool registerNamespace(const std::string& uri, const std::string& suggestedPrefix, std::string* registeredPrefix, std::string* errorMessage);

    /// The operation mutex that serializes all SXMPFiles open/read/write/close calls.
    /// Exposed here so terminate() can acquire it before calling SXMPFiles::Terminate(),
    /// preventing a race where terminate() zeroes format handler pointers while another
    /// thread is inside OpenFile() dispatching through those same pointers.
    static std::mutex operationMutex;
};
