// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKUtils

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
}

extension MetaAudioFileDescription {
    /// Writes what `dirtyFlags` names and the XMP edit, by the container's ``XMPContainerPolicy``.
    ///
    /// Native-owned (WAV, MP3): an edit to a property the native metadata mirrors is applied to
    /// that native field, and the whole edit is merged into the stored packet, which TagLib writes
    /// in the same save as the native chunks. The toolkit never opens the file for update.
    /// Reconciled: the native save runs first, then the toolkit applies the edit.
    public mutating func save(dirtyFlags: Set<MetadataDirtyFlag>, xmpEdit: XMPEdit?) throws {
        guard let xmpEdit else {
            try save(dirtyFlags: dirtyFlags)
            return
        }

        switch XMPContainerPolicy(url: url) {
        case .nativeOwned:
            var dirtyFlags = dirtyFlags
            var packet = StoredXMPPacketWrite.remove

            if try applyMirroredChanges(of: xmpEdit) {
                dirtyFlags.insert(.metadata)
            }

            if let edited = xmpEdit.edited {
                let merged = try XMP.merging(
                    changesFrom: xmpEdit.baseline, to: edited, onto: StoredXMPPacketWrite.storedPacket(in: url)
                )
                packet = merged.map { .replace($0) } ?? .remove
            }

            try save(dirtyFlags: dirtyFlags, storedXMPPacket: packet)

        case .reconciled:
            try saveReconciled(dirtyFlags: dirtyFlags, xmpEdit: xmpEdit)

        case .unsupported, nil:
            throw NSError(description: "XMP can't be written to a .\(url.pathExtension) file")
        }
    }

    /// The native save, then the toolkit's XMP write, which a native part that failed does not
    /// skip. Either one's failures arrive in one ``MetadataError/incompleteSave(written:failures:)``.
    private mutating func saveReconciled(dirtyFlags: Set<MetadataDirtyFlag>, xmpEdit: XMPEdit) throws {
        var written = dirtyFlags.subtracting([.xmp])
        var failures: [MetadataError] = []

        do {
            try save(dirtyFlags: dirtyFlags)
        } catch let MetadataError.incompleteSave(nativeWritten, nativeFailures) {
            written = nativeWritten
            failures = nativeFailures
        }

        do {
            if let edited = xmpEdit.edited {
                try XMP.applyChanges(from: xmpEdit.baseline, to: edited, url: url)
            } else {
                try XMP.remove(from: url)
            }

            written.formUnion(dirtyFlags.intersection([.xmp]))
        } catch {
            // Nothing else was written, so the toolkit's own reason is the whole story.
            guard written.isNotEmpty || failures.isNotEmpty else { throw error }

            Log.error(error)
            failures.append(.writeFailed(.xmp, url))
        }

        // The native save read the date before the toolkit moved it.
        urlProperties = URLProperties(url: url)

        if failures.isNotEmpty {
            throw MetadataError.incompleteSave(written: written, failures: failures)
        }
    }
}
