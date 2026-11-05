// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKUtils

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
                dirtyFlags.insert(.tags)
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
            throw MetadataError.unsupportedFormat(fileType?.utType, .xmp)
        }
    }

    /// The native save, then the toolkit's XMP write, which a native part that failed does not
    /// skip. Either one's failures arrive in one ``MetadataError/incompleteSave(written:failures:)``.
    private mutating func saveReconciled(dirtyFlags: Set<MetadataDirtyFlag>, xmpEdit: XMPEdit) throws {
        var written = Set(dirtyFlags.subtracting([.xmp]).flatMap(\.components))
        var failures: [MetadataError] = []

        do {
            try save(dirtyFlags: dirtyFlags)
        } catch let MetadataError.incompleteSave(nativeWritten, nativeFailures) {
            written = nativeWritten
            failures = nativeFailures
        }

        do {
            try xmpEdit.applyThroughToolkit(to: url)

            if dirtyFlags.contains(.xmp) { written.insert(.xmp) }
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
