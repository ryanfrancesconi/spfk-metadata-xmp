// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMP

import Foundation
import SPFKBase
import SPFKMetadataXMPC

public actor XMP {
    public static let shared = XMP()

    private init() {
        XMPLifecycle.initialize()
    }

    public var isInitialized: Bool { XMPLifecycle.isInitialized() }

    public func terminate() {
        XMPLifecycle.terminate()
    }

    public func parse(url: URL) throws -> String {
        guard let xmlString = XMPFile(path: url.path)?.xmpString else {
            throw NSError(description: "Failed to find an XMP chunk in the file: \(url.path)")
        }

        return xmlString
    }

    public func write(string: String, to url: URL) throws {
        guard XMPFile.write(string, toPath: url.path) else {
            throw NSError(description: "Failed to write XMP string to file: \(url.path)")
        }
    }
}
