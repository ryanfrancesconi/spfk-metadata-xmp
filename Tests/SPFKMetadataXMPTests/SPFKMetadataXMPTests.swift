import AEXML
import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

// Global utilities for tests

let resources = BundleResources(bundleURL: Bundle.module.bundleURL)

/// The file's packet, or nil when it holds none. Any other read failure throws.
func packetIfPresent(at url: URL) throws -> String? {
    do {
        return try XMP.parse(url: url)
    } catch XMPReadError.noPacket {
        return nil
    }
}

func sample(named name: String) throws -> String {
    let url = resources.resource(named: name)
    return try String(contentsOf: url, encoding: .utf8)
}

/// convenience to write out xmp to file
func write(document: AEXMLDocument, to url: URL) throws {
    var url = url

    if url.pathExtension != "xml" {
        url = url.appendingPathExtension("xml")
    }

    try document.xml.write(
        to: url,
        atomically: false,
        encoding: .utf8
    )
}
