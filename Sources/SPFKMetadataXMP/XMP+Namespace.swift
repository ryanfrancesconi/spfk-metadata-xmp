// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMPC

extension XMP {
    /// Registers a schema namespace for the rest of the process, so properties in it can be
    /// written with ``setProperties(_:url:)``. Safe to repeat.
    ///
    /// - Returns: the prefix in use for `uri`, which is the one first registered for it.
    @discardableResult
    public static func registerNamespace(_ uri: String, suggestedPrefix: String) throws -> String {
        XMPLifecycle.initialize()

        do {
            return try XMPLifecycle.registerNamespace(uri, suggestedPrefix: suggestedPrefix)
        } catch {
            throw NSError(description: "Failed to register XMP namespace \(uri) - \(error.localizedDescription)")
        }
    }
}
