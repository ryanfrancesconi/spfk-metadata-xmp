// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPUtil_H
#define XMPUtil_H

#include <iostream>
#include <string>
#include <vector>

#include "XMPLifecycleCXX.hpp"

/// Describes one property to write in a batch `setXMPProperties` call.
/// `isRemoval` deletes the property; otherwise `isArray` selects between `SetProperty`
/// (single value, `values[0]` used) and the array replace path (`DeleteProperty` +
/// `AppendArrayItem` per value).
struct XMPPropertyWrite {
    std::string ns;
    std::string propName;
    std::vector<std::string> values;
    bool isArray;

    /// Removes the property outright rather than writing a value, via `DeleteProperty`.
    ///
    /// Necessary because an empty value is not a removal: `SetProperty` with `""` writes a
    /// literal empty value, and on a property the toolkit has reconciled into a language
    /// alternative (`dc:title`, `dc:description`, `dc:rights`) it throws outright --
    /// "Composite nodes can't have values". `DeleteProperty` takes the whole subtree, so a
    /// lang-alt is cleared in every language rather than leaving entries the user cannot see.
    ///
    /// Takes precedence over `values`/`isArray` when set, so a caller cannot ask for both.
    bool isRemoval = false;
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

    /// One property to read in a batch `getXMPProperties` call.
    struct XMPPropertyRead {
        std::string ns;
        std::string propName;
        /// Read every item of an `rdf:Bag`/`rdf:Seq` rather than a single value.
        bool isArray;
    };

    /// Reads several properties in one open/read/close cycle.
    ///
    /// Results are index-aligned with `requests`: a scalar yields zero or one value, an array
    /// yields one entry per item, and a property that is absent yields an empty vector -- absence
    /// is not an error, it is the ordinary state of most fields on most files.
    ///
    /// Scalars go through `GetLocalizedText` first so a language alternative (`dc:title`,
    /// `dc:description`, `dc:rights`) returns its `x-default` text rather than nothing;
    /// `GetProperty` is the fallback for plain values. Asking for the wrong one of those two is
    /// otherwise silent -- a lang-alt read with `GetProperty` simply comes back empty.
    static bool getXMPProperties(
        const std::string& filePath,
        const std::vector<XMPPropertyRead>& requests,
        std::vector<std::vector<std::string>>* results,
        std::string* errorMessage
    );

    /// Write the xml string into the file (XMP chunk only, no reconciliation).
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    ///   - errorMessage: if non-null and the call fails, receives a description of the
    ///     actual failure (the caught `XMP_Error`'s message, or the specific open/put
    ///     failure reason) — otherwise left untouched.
    static bool writeXMP(const std::string& xmlString, const std::string& filePath, std::string* errorMessage = nullptr);

    /// Write XMP and allow Adobe SDK reconciliation to update native chunks
    /// (BEXT, iXML). Used for explicit "Sync XMP → iXML" operations.
    ///
    /// - Parameters:
    ///   - xmlString: xml
    ///   - filePath: path to the file
    ///   - errorMessage: see `writeXMP`.
    static bool writeXMPReconciled(const std::string& xmlString, const std::string& filePath, std::string* errorMessage = nullptr);

    /// Sets a single simple-value XMP property, preserving all other existing content.
    /// Loads the existing XMP packet first (load-then-mutate-then-put), unlike `writeXMP`
    /// which blindly overwrites the whole packet.
    ///
    /// - Parameters:
    ///   - filePath: path to the file
    ///   - ns: schema namespace URI
    ///   - propName: property name (may include a registered prefix, e.g. "xmpDM:scene")
    ///   - value: the new property value
    ///   - errorMessage: see `writeXMP`.
    static bool setXMPProperty(
        const std::string& filePath,
        const std::string& ns,
        const std::string& propName,
        const std::string& value,
        std::string* errorMessage = nullptr
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
    ///   - errorMessage: see `writeXMP`.
    static bool setXMPArrayProperty(
        const std::string& filePath,
        const std::string& ns,
        const std::string& propName,
        const std::vector<std::string>& values,
        XMP_OptionBits arrayForm,
        std::string* errorMessage = nullptr
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
    ///   - errorMessage: see `writeXMP`.
    static bool setXMPProperties(
        const std::string& filePath,
        const std::vector<XMPPropertyWrite>& properties,
        std::string* errorMessage = nullptr
    );

    /// Writes the first item of the `xmpDM:Tracks` bag's `trackType`/`trackName` fields,
    /// creating the `Tracks` bag and its first (struct-typed) item if none exists yet —
    /// mirroring `XMPMetadata`'s read path, which already only ever looks at the first
    /// track entry found. Pass an empty string to leave a field unchanged (skips that
    /// SetProperty call rather than writing an empty value over an existing one).
    ///
    /// - Parameter errorMessage: see `writeXMP`.
    static bool setXMPTrackInfo(
        const std::string& filePath,
        const std::string& trackType,
        const std::string& trackName,
        std::string* errorMessage = nullptr
    );
};

#endif // !XMPUtil_H
