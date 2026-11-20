// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase

/// A media file's XMP sidecar: `<basename>.xmp` beside it, Adobe's convention.
///
/// The sidecar is a plain packet file, read and written whole. Change it in memory with
/// ``XMP/applying(_:toPacket:)`` or ``XMP/merging(changesFrom:to:onto:)``, never through the file
/// handlers, which treat a bare `.xmp` file as unknown.
public enum XMPSidecar {
    /// Whether `url`'s metadata belongs in a sidecar: camera RAW other than DNG.
    public static func isUsed(for url: URL) -> Bool {
        url.usesXMPSidecar
    }

    /// The sidecar's URL: an existing sibling named `<basename>.xmp` in any case, else the
    /// lower-case name.
    public static func url(for url: URL) -> URL {
        url.xmpSidecarURL
    }

    /// The sidecar's packet; `nil` when there is none.
    public static func packet(for url: URL) throws -> String? {
        let sidecar = url.xmpSidecarURL
        guard FileManager.default.fileExists(atPath: sidecar.path) else { return nil }

        let data = try Data(contentsOf: sidecar)
        guard let packet = String(data: data, encoding: .utf8) else {
            throw NSError(description: "XMP sidecar is not UTF-8 text: \(sidecar.path)")
        }
        return packet
    }

    /// Writes `packet` as the sidecar, atomically. An empty packet removes the sidecar.
    ///
    /// Throws when the folder is not writable, since the sidecar may not exist yet.
    public static func write(_ packet: String, for url: URL) throws {
        let sidecar = url.xmpSidecarURL
        let folder = sidecar.deletingLastPathComponent()

        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw NSError(description: "Can't write the XMP sidecar, the folder is not writable: \(folder.path)")
        }

        guard !packet.isEmpty else {
            if FileManager.default.fileExists(atPath: sidecar.path) {
                try FileManager.default.removeItem(at: sidecar)
            }
            return
        }

        try Data(packet.utf8).write(to: sidecar, options: .atomic)
    }
}
