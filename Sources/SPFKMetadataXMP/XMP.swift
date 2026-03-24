// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMPC

/// Process-wide lock that serializes combined parse+write sequences.
///
/// The Adobe XMP SDK's format handlers use global `XMPFiles_IO` state that
/// persists across `OpenFile`/`CloseFile` cycles. A per-operation C++ mutex
/// (in `XMPUtil.cpp`) prevents truly concurrent SDK calls, but it releases
/// between parse and write. If a second thread's parse slips in between,
/// the SDK is left with stale `currLength` from that thread's file — causing
/// the next `OpenFile` to fail the `currLength == Host_IO::Length()` assertion.
///
/// Holding this lock for the entire parse+write sequence prevents any other
/// thread from running any XMP operation in between, eliminating the stale-state window.
private let _xmpCopyLock = NSLock()

/// Thread-safe XMP file parsing and writing.
///
/// Two-level locking:
/// - C++ mutex (`xmpOperationMutex` in `XMPUtil.cpp`): prevents simultaneous SDK calls.
/// - Swift lock (`_xmpCopyLock`): ensures parse+write pairs are atomic end-to-end.
///
/// Use ``XMP/Accessor/copyXMP(from:to:)`` (via `XMP.shared.copyXMP`) for the common
/// copy-metadata use case. Call `parse`/`write` separately only when you do not need
/// atomicity across both operations.
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

        /// Copy XMP metadata from one file to another as a single atomic operation.
        ///
        /// Holds `_xmpCopyLock` across both parse and write, preventing other threads
        /// from interleaving their own XMP operations in between. Safe to call
        /// concurrently from multiple threads (e.g., batch audio conversion).
        ///
        /// Throws if the source file contains no XMP or if the write fails.
        public func copyXMP(from input: URL, to output: URL) throws {
            _xmpCopyLock.lock()
            defer { _xmpCopyLock.unlock() }

            let xmpString = try XMP.parse(url: input)
            try XMP.write(string: xmpString, to: output)
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
