// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPUtil_H
#define XMPUtil_H

#include <iostream>
#include <string>

#include "XMPLifecycleCXX.hpp"

class XMPUtil {
private:
    /// Creates an XMP object from an RDF string.  The string is used to
    /// to simulate creating and XMP object from multiple input buffers.
    /// The last call to ParseFromBuffer has no kXMP_ParseMoreBuffers options,
    /// thereby indicating this is the last input buffer.
    ///
    /// - Parameter string: string to parse
    static SXMPMeta createXMPFromRDF(const std::string& rdfString);

public:
    static std::string getXMP(const std::string& filePath);

    /// Write the xml string into the file
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    static bool writeXMP(const std::string& xmlString, const std::string& filePath);
};

#endif // !XMPUtil_H
