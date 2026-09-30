// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

#ifndef XMPUtil_H
#define XMPUtil_H

#include <iostream>
#include <string>
#include <vector>

#include "XMPLifecycleCXX.hpp"

/// Describes one property to write in a batch `setXMPProperties` call.
/// `isRemoval` deletes the property; otherwise `isArray` selects between a single value
/// (`values[0]`, see `setScalarProperty`) and the array replace path (`DeleteProperty` +
/// `AppendArrayItem` per value).
struct XMPPropertyWrite {
    std::string ns;
    std::string propName;
    std::vector<std::string> values;
    bool isArray;

    /// Writes the single value as the `x-default` entry of an `rdf:Alt` language alternative.
    bool isLocalized = false;

    /// Removes the property outright rather than writing a value, via `DeleteProperty`.
    ///
    /// An empty value is not a removal: it stores a literal empty value. `DeleteProperty` takes
    /// the whole subtree, so a language alternative is cleared in every language.
    ///
    /// Takes precedence over `values`/`isArray` when set, so a caller cannot ask for both.
    bool isRemoval = false;
};

class XMPUtil {
private:
    /// Parses an RDF/XML string into a new `SXMPMeta` in one `ParseFromBuffer` call.
    ///
    /// - Parameter string: string to parse
    static SXMPMeta createXMPFromRDF(const std::string& rdfString);

    /// Parses `xmlString` into `meta`, failing when it holds no properties.
    ///
    /// The toolkit's parser accepts empty or non-XMP text without an error and returns an empty
    /// tree, which written whole would erase the file's packet.
    static bool parsePacket(const std::string& xmlString, SXMPMeta* meta, std::string* errorMessage);

    /// Writes one value, as a language alternative's `x-default` entry when `isLocalized` is set
    /// or the existing node already is an `rdf:Alt`, and as a simple value otherwise.
    ///
    /// `SetProperty` throws on an `rdf:Alt` ("Composite nodes can't have values"), and
    /// `SetLocalizedText` throws on an existing simple value, which is deleted first. Other
    /// languages keep their entries unless they held the old `x-default` text, which is updated too.
    static void setScalarProperty(
        SXMPMeta& meta,
        const std::string& ns,
        const std::string& propName,
        const std::string& value,
        bool isLocalized
    );

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
    /// `GetProperty` reads the shape; an alt-text value is then read with `GetLocalizedText`.
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
    ///   - arrayForm: kXMP_PropArrayIsOrdered or kXMP_PropArrayIsUnordered.
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
    /// mirroring `XMPDynamicMedia`'s read path, which already only ever looks at the first
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
