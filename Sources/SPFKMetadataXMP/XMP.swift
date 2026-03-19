// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMPC

/// Thread-safe XMP file parsing and writing.
///
/// Initialization of the Adobe XMP SDK is mutex-protected in the C++ layer.
/// The `parse`, `write`, and `writeReconciled` methods use stack-local
/// `SXMPFiles` / `SXMPMeta` instances with no shared state, enabling true
/// concurrent file operations on different files.
///
/// This is an enum namespace (not an actor) to avoid deadlocks when called
/// from synchronous contexts. The C++ mutex handles all thread safety.
public enum XMP {
    /// Singleton-like access point. Kept for API compatibility with existing
    /// `XMP.shared.parse(...)` call sites — `shared` is simply `XMP.self`.
    public static let shared = Accessor()

    /// Lightweight accessor that forwards to the static methods.
    /// Exists solely so `XMP.shared.parse(url:)` continues to compile.
    public struct Accessor: Sendable {
        public var isInitialized: Bool { XMPLifecycle.isInitialized() }

        public func terminate() {
            XMPLifecycle.terminate()
        }

        /// Parse XMP metadata from an audio/video file.
        public func parse(url: URL) throws -> String {
            try XMP.parse(url: url)
        }

        /// Write an XMP XML string to a file.
        public func write(string: String, to url: URL) throws {
            try XMP.write(string: string, to: url)
        }

        /// Write XMP with Adobe SDK reconciliation enabled.
        public func writeReconciled(string: String, to url: URL) throws {
            try XMP.writeReconciled(string: string, to: url)
        }
    }

    // MARK: - Static API

    /// Parse XMP metadata from an audio/video file.
    public static func parse(url: URL) throws -> String {
        XMPLifecycle.initialize()

        guard let xmlString = XMPFile(path: url.path)?.xmpString else {
            throw NSError(description: "Failed to find an XMP chunk in the file: \(url.path)")
        }

        return xmlString
    }

    /// Write an XMP XML string to a file.
    ///
    /// The caller is responsible for not writing to the same file from multiple threads.
    public static func write(string: String, to url: URL) throws {
        XMPLifecycle.initialize()

        guard XMPFile.write(string, toPath: url.path) else {
            throw NSError(description: "Failed to write XMP string to file: \(url.path)")
        }
    }

    /// Write XMP with Adobe SDK reconciliation enabled.
    ///
    /// This allows the SDK to sync `bext:` and `iXML:` namespace properties
    /// back to native RIFF chunks. Used for explicit "Sync XMP → iXML" operations.
    public static func writeReconciled(string: String, to url: URL) throws {
        XMPLifecycle.initialize()

        guard XMPFile.writeReconciled(string, toPath: url.path) else {
            throw NSError(description: "Failed to write reconciled XMP to file: \(url.path)")
        }
    }
}
