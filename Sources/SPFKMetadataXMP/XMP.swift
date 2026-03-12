// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMPC

/// Thread-safe XMP file parsing and writing.
///
/// Initialization of the Adobe XMP SDK is mutex-protected. The `parse` and `write`
/// methods are `nonisolated` because the underlying C++ calls use stack-local
/// `SXMPFiles` / `SXMPMeta` instances with no shared state, enabling true concurrent
/// file operations on different files.
public actor XMP {
    public static let shared = XMP()

    private init() {
        XMPLifecycle.initialize()
    }

    public var isInitialized: Bool { XMPLifecycle.isInitialized() }

    public func terminate() {
        XMPLifecycle.terminate()
    }

    /// Parse XMP metadata from an audio/video file.
    ///
    /// This is `nonisolated` — multiple files can be parsed concurrently.
    public nonisolated func parse(url: URL) throws -> String {
        guard let xmlString = XMPFile(path: url.path)?.xmpString else {
            throw NSError(description: "Failed to find an XMP chunk in the file: \(url.path)")
        }

        return xmlString
    }

    /// Write an XMP XML string to a file.
    ///
    /// This is `nonisolated` — writes to different files can run concurrently.
    /// The caller is responsible for not writing to the same file from multiple threads.
    public nonisolated func write(string: String, to url: URL) throws {
        guard XMPFile.write(string, toPath: url.path) else {
            throw NSError(description: "Failed to write XMP string to file: \(url.path)")
        }
    }
}
