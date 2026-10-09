// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataBase
import SPFKMetadataXMPC
import UniformTypeIdentifiers

/// Thread-safe XMP file parsing and writing.
///
/// Every call into the toolkit holds one C++ mutex (`XMPLifecycleCXX::operationMutex`) for its
/// whole body, so no two SDK operations run at once. Two separate calls, such as a parse followed
/// by a write, are not atomic together.
public enum XMP {
    /// Singleton-like access point. Kept for API compatibility with existing
    /// `XMP.shared.parse(...)` call sites — `shared` is an `Accessor` instance forwarding to the
    /// static functions.
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

        /// Sets a single simple-value XMP property, preserving all other existing content.
        public func setProperty(namespace: String, name: String, value: String, url: URL) throws {
            try XMP.setProperty(namespace: namespace, name: name, value: value, url: url)
        }

        /// Replaces a whole array-value XMP property (e.g. `dc:subject`/keywords),
        /// preserving all other existing content.
        public func setArrayProperty(namespace: String, name: String, values: [String], isOrdered: Bool = false, url: URL) throws {
            try XMP.setArrayProperty(namespace: namespace, name: name, values: values, isOrdered: isOrdered, url: url)
        }

        /// Writes multiple properties (simple and/or array) in a single open/read/write/close cycle.
        public func setProperties(_ properties: [XMPPropertyWrite], url: URL) throws {
            try XMP.setProperties(properties, url: url)
        }

        /// Writes the first `xmpDM:Tracks` item's `trackType`/`trackName`, creating the
        /// Tracks bag and its first item if none exists yet. Pass `nil` to leave a field unchanged.
        public func setTrackInfo(trackType: String?, trackName: String?, url: URL) throws {
            try XMP.setTrackInfo(trackType: trackType, trackName: trackName, url: url)
        }
    }

    // MARK: - Static API

    /// Parse XMP metadata from an audio/video file.
    ///
    /// - Throws: ``XMPReadError/noPacket`` for a file that holds no XMP, and
    ///   ``XMPReadError/readFailed(_:)`` for one that could not be read.
    public static func parse(url: URL) throws -> String {
        XMPLifecycle.initialize()

        do {
            return try XMPFile.xmpString(atPath: url.path)
        } catch let error as NSError where error.domain == "XMPFile" && error.code == XMPFileErrorCode.noPacket.rawValue {
            throw XMPReadError.noPacket
        } catch {
            throw XMPReadError.readFailed("\(url.path) — \(error.localizedDescription)")
        }
    }

    /// Replaces the file's XMP packet with an XML string.
    ///
    /// The toolkit also rewrites the native metadata the packet mirrors -- BEXT, INFO, iXML, ID3,
    /// TIFF tags, MPEG-4 `cprt` and timecode -- so a packet lacking those properties removes them
    /// from the file. Throws for a packet holding no XMP properties.
    ///
    /// The caller is responsible for not writing to the same file from multiple threads.
    public static func write(string: String, to url: URL) throws {
        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.write(string, toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to write XMP string to file: \(url.path) — \(reason)")
        }
    }

    /// Applies an edit to the file's current packet: only the top-level properties that differ
    /// between `baseline` and `edited` are written, and one missing from `edited` is removed.
    ///
    /// Metadata the file gained since `baseline` was read -- another app's edit, or native metadata
    /// the toolkit imported after a tag save -- is kept. Throws for an `edited` packet holding no
    /// properties.
    ///
    /// - Parameter baseline: the packet the edit started from, `nil` when the file had none.
    public static func applyChanges(from baseline: String?, to edited: String, url: URL) throws {
        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.applyChanges(fromBaseline: baseline, edited: edited, toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to apply XMP changes to file: \(url.path) — \(reason)")
        }
    }

    /// Removes the file's XMP-only properties.
    ///
    /// Only for the MPEG-4 family (see ``canRemove(from:)``). Properties the toolkit mirrors from
    /// native metadata -- `mvhd` dates, `cprt`, timecode -- are kept, since a packet without them
    /// deletes them from the file. Other formats throw without the file being touched.
    public static func remove(from url: URL) throws {
        guard canRemove(from: url) else {
            throw MetadataError.unsupportedFormat(UTType(filenameExtension: url.pathExtension), .xmp)
        }

        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.remove(fromPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to remove XMP from file: \(url.path) — \(reason)")
        }
    }

    /// Extensions whose XMP ``remove(from:)`` can remove: the MPEG-4 family, whose handler mirrors
    /// a known, small set of native fields. AIFF and DNG are reconciled too, but every packet
    /// property there can be native-backed.
    public static let removablePathExtensions: Set<String> = ["mp4", "m4a", "m4v", "m4b", "mov"]

    /// Whether ``remove(from:)`` can remove this file's XMP, from the path extension.
    public static func canRemove(from url: URL) -> Bool {
        removablePathExtensions.contains(url.pathExtension.lowercased())
    }

    /// Sets a single simple-value XMP property, preserving all other existing content
    /// (load-then-mutate-then-put — unlike `write(string:to:)`, which replaces the whole packet).
    ///
    /// The whole load-mutate-put sequence happens within one C++ call, under the toolkit mutex.
    public static func setProperty(namespace: String, name: String, value: String, url: URL) throws {
        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.setProperty(namespace, propName: name, value: value, toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to set XMP property \(namespace):\(name) on file: \(url.path) — \(reason)")
        }
    }

    /// Replaces a whole array-value XMP property (e.g. `dc:subject`/keywords) with `values`,
    /// preserving all other existing content. `isOrdered` selects `rdf:Seq` (true) vs.
    /// `rdf:Bag` (false, the default — correct for `dc:subject`).
    public static func setArrayProperty(namespace: String, name: String, values: [String], isOrdered: Bool = false, url: URL) throws {
        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.setArrayProperty(namespace, propName: name, values: values, isOrdered: isOrdered, toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to set XMP array property \(namespace):\(name) on file: \(url.path) — \(reason)")
        }
    }

    /// Writes multiple properties (simple, array, and/or removals) in a single open/read/write/close cycle —
    /// fewer open/close cycles than repeated `setProperty`/`setArrayProperty` calls, and avoids
    /// the interleaved-thread stale-state window between separate calls.
    public static func setProperties(_ properties: [XMPPropertyWrite], url: URL) throws {
        XMPLifecycle.initialize()

        let entries = properties.map { property in
            if property.isRemoval {
                XMPPropertyWriteEntry(removalOfNamespace: property.namespace, propName: property.name)
            } else if property.isLocalized, let value = property.values.first {
                XMPPropertyWriteEntry(namespace: property.namespace, propName: property.name, localizedValue: value)
            } else {
                XMPPropertyWriteEntry(
                    namespace: property.namespace, propName: property.name, values: property.values,
                    isArray: property.isArray, isOrdered: property.isOrdered
                )
            }
        }

        var error: NSError?
        guard XMPFile.setProperties(entries, toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to set XMP properties on file: \(url.path) — \(reason)")
        }
    }

    /// Reads several properties in one open/read/close cycle.
    ///
    /// Returns values index-aligned with `requests`: a scalar yields zero or one value, an array
    /// yields one entry per item, and an absent property yields an empty array. **Absence is not
    /// an error** -- it is the ordinary state of most fields on most files, and a file with no XMP
    /// packet at all simply reports every field empty.
    ///
    /// Scalars resolve a language alternative (`dc:title`, `dc:description`, `dc:rights`) to its
    /// `x-default` text automatically, so a caller does not need to know which fields the toolkit
    /// has reconciled into one.
    public static func getProperties(_ requests: [XMPPropertyRead], url: URL) throws -> [[String]] {
        XMPLifecycle.initialize()

        let entries = requests.map {
            XMPPropertyReadEntry(namespace: $0.namespace, propName: $0.name, isArray: $0.isArray)
        }

        // Imported as `throws`: the ObjC method returns a nullable array with an NSError** out
        // param, so Swift folds the error into the throw and drops the parameter.
        do {
            return try XMPFile.getProperties(entries, fromPath: url.path)
        } catch {
            throw NSError(description: "Failed to read XMP properties from file: \(url.path) — \(error.localizedDescription)")
        }
    }

    /// Writes the first `xmpDM:Tracks` item's `trackType`/`trackName`, creating the Tracks
    /// bag and its first item if none exists yet. Pass `nil` to leave a field unchanged.
    public static func setTrackInfo(trackType: String?, trackName: String?, url: URL) throws {
        XMPLifecycle.initialize()

        var error: NSError?
        guard XMPFile.setTrackType(trackType ?? "", trackName: trackName ?? "", toPath: url.path, error: &error) else {
            let reason = error?.localizedDescription ?? "unknown reason"
            throw NSError(description: "Failed to set XMP track info on file: \(url.path) — \(reason)")
        }
    }
}

/// Why ``XMP/parse(url:)`` returned no packet.
public enum XMPReadError: Error, Equatable, LocalizedError {
    /// The file was read and holds no XMP.
    case noPacket

    /// The file could not be opened or read.
    case readFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noPacket: "The file holds no XMP"
        case let .readFailed(reason): "Failed to read XMP: \(reason)"
        }
    }
}

/// One property to read in a batch `XMP.getProperties(_:url:)` call.
public struct XMPPropertyRead: Sendable {
    public let namespace: String
    public let name: String

    /// Read every item of an `rdf:Bag`/`rdf:Seq` rather than a single value.
    public let isArray: Bool

    public init(namespace: String, name: String, isArray: Bool = false) {
        self.namespace = namespace
        self.name = name
        self.isArray = isArray
    }
}

/// One property to write -- or remove -- in a batch `XMP.setProperties(_:url:)` call.
public struct XMPPropertyWrite: Sendable {
    public let namespace: String
    public let name: String
    public let values: [String]
    public let isArray: Bool

    /// Writes an array as an `rdf:Seq` rather than an `rdf:Bag`.
    public let isOrdered: Bool

    /// Writes the single value as the `x-default` entry of an `rdf:Alt` language alternative.
    public let isLocalized: Bool

    /// Removes the property instead of writing it. Takes precedence over `values`/`isArray`.
    public let isRemoval: Bool

    init(
        namespace: String, name: String, values: [String], isArray: Bool,
        isOrdered: Bool = false, isLocalized: Bool = false, isRemoval: Bool = false
    ) {
        self.namespace = namespace
        self.name = name
        self.values = values
        self.isArray = isArray
        self.isOrdered = isOrdered
        self.isLocalized = isLocalized
        self.isRemoval = isRemoval
    }

    /// A single simple-value property write. A property the file already holds as a language
    /// alternative is written as one.
    public static func simple(namespace: String, name: String, value: String) -> XMPPropertyWrite {
        XMPPropertyWrite(namespace: namespace, name: name, values: [value], isArray: false)
    }

    /// A language-alternative write: `value` becomes the `x-default` entry, and entries in other
    /// languages are kept. For `dc:title`, `dc:description`, `dc:rights` and the other `rdf:Alt`
    /// properties.
    public static func localized(namespace: String, name: String, value: String) -> XMPPropertyWrite {
        XMPPropertyWrite(namespace: namespace, name: name, values: [value], isArray: false, isLocalized: true)
    }

    /// A whole-array-replace property write: an `rdf:Seq` when `isOrdered`, an `rdf:Bag` otherwise.
    public static func array(namespace: String, name: String, values: [String], isOrdered: Bool = false) -> XMPPropertyWrite {
        XMPPropertyWrite(namespace: namespace, name: name, values: values, isArray: true, isOrdered: isOrdered)
    }

    /// Removes a property entirely.
    ///
    /// **Not the same as writing an empty value**, which stores a literal empty value.
    ///
    /// Deletes the whole subtree, so a language alternative clears in every language rather than
    /// leaving entries the user cannot see or edit. Removing a property that is not present is a
    /// no-op, not an error -- clearing an already-empty field is the ordinary case.
    public static func removal(namespace: String, name: String) -> XMPPropertyWrite {
        XMPPropertyWrite(namespace: namespace, name: name, values: [], isArray: false, isRemoval: true)
    }
}
