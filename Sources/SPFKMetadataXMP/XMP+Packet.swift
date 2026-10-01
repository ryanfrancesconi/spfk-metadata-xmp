// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMPC

/// A schema namespace and a top-level property path within it, such as `xmpDM:scene`.
public struct XMPPropertyKey: Hashable, Sendable {
    public let namespace: String
    public let path: String

    public init(namespace: String, path: String) {
        self.namespace = namespace
        self.path = path
    }
}

/// Packet operations that open no file, for a caller storing the packet itself.
public extension XMP {
    /// ``applyChanges(from:to:url:)`` in memory: the top-level properties that differ between
    /// `baseline` and `edited` are applied onto `current`.
    ///
    /// - Returns: the merged packet with its wrapper and padding, ready to embed, or `nil` when
    ///   it holds no properties.
    static func merging(changesFrom baseline: String?, to edited: String, onto current: String?) throws -> String? {
        XMPLifecycle.initialize()

        let merged = try XMPPacket.mergeChanges(fromBaseline: baseline, edited: edited, onto: current)
        return merged.isEmpty ? nil : merged
    }

    /// The top-level properties that differ between `baseline` (`nil` for none) and `edited`.
    static func changedProperties(from baseline: String?, to edited: String) throws -> [XMPPropertyKey] {
        XMPLifecycle.initialize()

        return try XMPPacket.changedProperties(fromBaseline: baseline, edited: edited).compactMap { pair in
            guard pair.count == 2 else { return nil }
            return XMPPropertyKey(namespace: pair[0], path: pair[1])
        }
    }

    /// ``getProperties(_:url:)`` over a packet string.
    static func getProperties(_ requests: [XMPPropertyRead], inPacket packet: String) throws -> [[String]] {
        XMPLifecycle.initialize()

        let entries = requests.map {
            XMPPropertyReadEntry(namespace: $0.namespace, propName: $0.name, isArray: $0.isArray)
        }

        return try XMPPacket.getProperties(entries, inPacket: packet)
    }
}
