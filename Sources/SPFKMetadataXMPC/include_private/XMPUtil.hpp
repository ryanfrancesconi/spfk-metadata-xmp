// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPUtil_H
#define XMPUtil_H

#include <iostream>
#include <string>
#include <vector>

#include "XMPLifecycleCXX.hpp"

/// Describes one property to write in a batch `setXMPProperties` call.
/// `isArray` selects between `SetProperty` (single value, `values[0]` used)
/// and the array replace path (`DeleteProperty` + `AppendArrayItem` per value).
struct XMPPropertyWrite {
    std::string ns;
    std::string propName;
    std::vector<std::string> values;
    bool isArray;
};

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

    /// Write the xml string into the file (XMP chunk only, no reconciliation).
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    static bool writeXMP(const std::string& xmlString, const std::string& filePath);

    /// Write XMP and allow Adobe SDK reconciliation to update native chunks
    /// (BEXT, iXML). Used for explicit "Sync XMP → iXML" operations.
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    static bool writeXMPReconciled(const std::string& xmlString, const std::string& filePath);

    /// Sets a single simple-value XMP property, preserving all other existing content.
    /// Loads the existing XMP packet first (load-then-mutate-then-put), unlike `writeXMP`
    /// which blindly overwrites the whole packet.
    ///
    /// - Parameters:
    ///   - filePath: path to the file
    ///   - ns: schema namespace URI
    ///   - propName: property name (may include a registered prefix, e.g. "xmpDM:scene")
    ///   - value: the new property value
    static bool setXMPProperty(
        const std::string& filePath,
        const std::string& ns,
        const std::string& propName,
        const std::string& value
    );

    /// Replaces a whole array-value XMP property (e.g. `dc:subject`), preserving all other
    /// existing content. Clears any existing items for `propName` first, then appends `values`
    /// in order — "replace with this new set" semantics, not incremental append.
    ///
    /// - Parameters:
    ///   - filePath: path to the file
    ///   - ns: schema namespace URI
    ///   - propName: array property name
    ///   - values: the new full set of array item values, in order
    ///   - arrayForm: one of kXMP_PropArrayIsUnordered, kXMP_PropArrayIsOrdered,
    ///     kXMP_PropArrayIsAlternate (see XMP_Const.h)
    static bool setXMPArrayProperty(
        const std::string& filePath,
        const std::string& ns,
        const std::string& propName,
        const std::vector<std::string>& values,
        XMP_OptionBits arrayForm
    );

    /// Writes multiple properties (simple and/or array) in a single OpenFile/GetXMP/
    /// [mutations]/PutXMP/CloseFile cycle — fewer open/close cycles than calling
    /// setXMPProperty/setXMPArrayProperty repeatedly, and avoids the interleaved-thread
    /// stale-state window between separate calls.
    ///
    /// - Parameters:
    ///   - filePath: path to the file
    ///   - properties: the properties to write; array items use kXMP_PropArrayIsUnordered
    ///     (bag) form — sufficient for both known consumers (dc:subject and xmpDM fields),
    ///     see XMPPropertyWrite
    static bool setXMPProperties(
        const std::string& filePath,
        const std::vector<XMPPropertyWrite>& properties
    );
};

#endif // !XMPUtil_H
