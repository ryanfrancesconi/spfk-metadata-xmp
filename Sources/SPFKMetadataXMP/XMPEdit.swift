// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataImage
import UniformTypeIdentifiers

/// A pending edit to a file's XMP: the packet it began from and the packet it ends at.
///
/// Only the top-level properties that differ between the two are written, so a property another
/// app changed after `baseline` was read is kept unless the edit changed it too.
public struct XMPEdit: Sendable, Hashable {
    /// The packet the edit began from, `nil` when the file had none.
    public var baseline: String?

    /// The edited packet, `nil` to clear the file's XMP.
    public var edited: String?

    public init(baseline: String?, edited: String?) {
        self.baseline = baseline
        self.edited = edited
    }

    /// Whether a clear can remove this file's XMP while keeping its native metadata.
    public static func canClear(url: URL) -> Bool {
        XMPContainerPolicy(url: url) == .nativeOwned || XMP.canRemove(from: url)
    }

    /// The `xmpDM` fields the XMP tab edits, which ``applyProductionFieldsThroughImageIO(to:)``
    /// writes.
    public static let productionElements: [XMPElement] = [
        .cameraAngle, .cameraModel, .logComment, .scene, .shotDate, .shotLocation,
    ]

    private static let dynamicMediaNamespace = "http://ns.adobe.com/xmp/1.0/DynamicMedia/"
    private static let dynamicMediaPrefix = "xmpDM"

    /// Writes the edit with the toolkit's diff write, or removes the file's XMP for a clear.
    public func applyThroughToolkit(to url: URL) throws {
        if let edited {
            try XMP.applyChanges(from: baseline, to: edited, url: url)
        } else {
            try XMP.remove(from: url)
        }
    }

    /// The production fields that differ between `baseline` and `edited`, by local name: the new
    /// value, or `nil` for a field the edit emptied.
    public func productionFieldChanges() throws -> [String: String?] {
        guard let edited else { return [:] }

        let before = try baseline.map { try XMPDynamicMedia(xml: $0) } ?? XMPDynamicMedia()
        let after = try XMPDynamicMedia(xml: edited)

        var changes: [String: String?] = [:]

        for element in Self.productionElements {
            let value = after.value(for: element)
            guard value != before.value(for: element) else { continue }
            changes[String(element.rawValue.dropFirst(Self.dynamicMediaPrefix.count + 1))] = value
        }

        return changes
    }

    /// Writes only the production fields the edit changed, through ImageIO, for a still the toolkit
    /// cannot write. Everything else in the edit is ignored, and a clear throws.
    public func applyProductionFieldsThroughImageIO(to url: URL) throws {
        guard edited != nil else {
            throw MetadataError.unsupportedFormat(UTType(filenameExtension: url.pathExtension), .xmp)
        }

        let changes = try productionFieldChanges()
        guard changes.isNotEmpty else { return }

        try ImageXMP.writeScalarProperties(
            namespace: Self.dynamicMediaNamespace,
            prefix: Self.dynamicMediaPrefix,
            values: changes,
            url: url
        )
    }
}
