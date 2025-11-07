
#ifndef XMPUtil_H
#define XMPUtil_H

#include <iostream>

#include "XMPLifecycle.hpp"

using namespace std;

class XMPUtil {
private:
    /// Creates an XMP object from an RDF string.  The string is used to
    /// to simulate creating and XMP object from multiple input buffers.
    /// The last call to ParseFromBuffer has no kXMP_ParseMoreBuffers options,
    /// thereby indicating this is the last input buffer.
    ///
    /// - Parameter string: string to parse
    static SXMPMeta createXMPFromRDF(string string);

public:
    static string getXMP(string filename);
    
    /// Write the xml string into the file
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    static bool writeXMP(string xmlString, string filePath);
};

#endif // !XMPUtil_H
