import AEXML
import Foundation
import SPFKTesting
import Testing

let resources = BundleResources(bundleURL: Bundle.module.bundleURL)

func xml(named name: String) throws -> String {
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
