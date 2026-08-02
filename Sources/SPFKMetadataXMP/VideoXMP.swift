// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataImage

/// Reads and writes the same fourteen XMP fields `ImageXMP` handles, for QuickTime containers.
///
/// A separate type because the mechanism is entirely different, not because the vocabulary is:
/// `ImageXMP` is ImageIO-based (`CGImageSource`) and will not open a `.mov` at all, while this
/// goes through the Adobe toolkit in `spfk-metadata-xmp`. Both address the same
/// ``XMPField`` set, which is what keeps a video and an image from supporting different
/// fields -- the drift the workspace CLAUDE.md warns about for format-capability lists.
///
/// Verified against a real 4K iPhone `.mov` (2026-08-02): all fourteen fields write, read back and
/// clear, with the file's QuickTime user data -- GPS, make, model, capture date -- duration and
/// track count all preserved, in single-digit milliseconds. The toolkit appends an XMP atom rather
/// than rewriting the container.
///
/// Lives here rather than in a product package so ShadowTag inherits it: video capability is the
/// one direction that flows TorchTag → ShadowTag, per the workspace CLAUDE.md. ShadowTag writes
/// video metadata through TagLib today, which reaches 4 of these 14 fields and cannot express
/// keywords at all.
public enum VideoXMP {
    /// Reads every modeled field in one open/read/close cycle.
    ///
    /// A file with no XMP packet reports every field empty rather than failing -- that is the
    /// normal state of a camera original, not an error.
    public static func readMetadata(from url: URL) throws -> XMPMetadata {
        let fields = XMPField.allCases

        let values = try XMP.getProperties(
            fields.map { XMPPropertyRead(namespace: $0.namespace, name: $0.localName, isArray: $0.isArray) },
            url: url
        )

        // getProperties guarantees index alignment with the requests; zip rather than index so a
        // future change to that contract fails to compile instead of silently misfiling values.
        return XMPMetadata(fieldValues: Dictionary(uniqueKeysWithValues: zip(fields, values)))
    }

    /// Writes every populated field and **removes** every empty one, in a single open/write cycle.
    ///
    /// Sending removals rather than skipping absent fields is what makes emptying a field in the
    /// editor empty it on the file. It is safe here for the same reason it is in the image path:
    /// the caller's metadata carries the complete state of the modeled set, because
    /// ``readMetadata(from:)`` populates all fourteen.
    ///
    /// - Important: this is only sound while reading and writing cover the same field set. If a
    ///   field is ever added to ``XMPField`` and read but not written -- or vice versa --
    ///   saving would erase it. Both sides iterate `allCases` precisely so that cannot happen
    ///   silently.
    public static func writeMetadata(_ metadata: XMPMetadata, url: URL) throws {
        let properties: [XMPPropertyWrite] = XMPField.allCases.map { field in
            let values = metadata.values(for: field)

            guard values.isNotEmpty else {
                return .removal(namespace: field.namespace, name: field.localName)
            }

            return field.isArray
                ? .array(namespace: field.namespace, name: field.localName, values: values)
                : .simple(namespace: field.namespace, name: field.localName, value: values[0])
        }

        try XMP.setProperties(properties, url: url)
    }
}
