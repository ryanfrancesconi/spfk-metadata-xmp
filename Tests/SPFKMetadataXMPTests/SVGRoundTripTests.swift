// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import AppKit
import Foundation
import SPFKBase
import SPFKMetadataImage
import SPFKMetadataXMP
import Testing

/// Every ``XMPField`` writes, reads back and clears on SVG, whose handler reconciles `dc:title`
/// and `dc:description` with the document's `<title>` and `<desc>`. The file must still render.
@Suite
class SVGRoundTripTests: BinTestCase {
    private static let metadata = XMPMetadata(
        keywords: ["one", "two"], creators: ["First", "Second"], title: "XMP Title",
        description: "A description", copyright: "A copyright", city: "Lisbon", state: "Lisboa",
        country: "Portugal", subLocation: "Alfama", rating: 4, label: "Select", labelColor: "Red",
        accessibilityAltText: "Alt text", accessibilityDescription: "Extended description"
    )

    private static let fixtures: [String: String] = [
        "plain": """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="40" height="20" viewBox="0 0 40 20">
          <rect width="40" height="20" fill="#ff0000"/>
        </svg>
        """,
        "packet": """
        <?xml version='1.0'?><svg xmlns="http://www.w3.org/2000/svg" width="40" height="20" viewBox="0 0 40 20">\
        <metadata><x:xmpmeta xmlns:x='adobe:ns:meta/'><rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>\
        <rdf:Description rdf:about='' xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:subject><rdf:Bag><rdf:li>old</rdf:li></rdf:Bag></dc:subject>\
        </rdf:Description></rdf:RDF></x:xmpmeta></metadata><rect width='40' height='20' fill='red'/></svg>
        """,
        "minified": #"<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20"><path d="M0 0h40v20H0z"/></svg>"#,
    ]

    private func fixture(_ name: String) throws -> URL {
        let url = bin.appendingPathComponent("\(name).svg")
        try Data((Self.fixtures[name] ?? "").utf8).write(to: url)
        return url
    }

    private func rendersAtItsSize(_ url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        return image.isValid && image.size == CGSize(width: 40, height: 20)
    }

    @Test(arguments: ["plain", "packet", "minified"])
    func everyFieldRoundTripsAndClears(name: String) throws {
        let url = try fixture(name)

        try VideoXMP.writeMetadata(Self.metadata, url: url)

        #expect(try VideoXMP.readMetadata(from: url) == Self.metadata)
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("<title>XMP Title</title>"))
        #expect(written.contains("<desc>A description</desc>"))
        #expect(rendersAtItsSize(url))

        try VideoXMP.writeMetadata(XMPMetadata(), url: url)

        #expect(try VideoXMP.readMetadata(from: url) == XMPMetadata())
        let cleared = try String(contentsOf: url, encoding: .utf8)
        #expect(!cleared.contains("<title"))
        #expect(!cleared.contains("<desc"))
        #expect(rendersAtItsSize(url))
    }

    /// With no packet, the document's own title and description are what a reader shows.
    @Test func aNativeTitleAndDescriptionReadAsTheirFields() throws {
        let url = bin.appendingPathComponent("native.svg")
        try Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20"><title>Native</title><desc>Described</desc><rect width="40" height="20"/></svg>"#.utf8)
            .write(to: url)

        let metadata = try VideoXMP.readMetadata(from: url)

        #expect(metadata.title == "Native")
        #expect(metadata.description == "Described")
    }

    // MARK: - Non-XMP RDF

    /// The shape Inkscape writes with Document Properties set: a typed `cc:Work` node, no packet.
    private static let creativeCommons = """
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" \
    xmlns:cc="http://creativecommons.org/ns#" xmlns:dc="http://purl.org/dc/elements/1.1/" width="40" height="20">
      <metadata>
        <rdf:RDF>
          <cc:Work rdf:about="">
            <dc:title>Work Title</dc:title>
            <dc:creator><cc:Agent><dc:title>An Author</dc:title></cc:Agent></dc:creator>
            <cc:license rdf:resource="http://creativecommons.org/licenses/by/4.0/"/>
          </cc:Work>
        </rdf:RDF>
      </metadata>
      <rect width="40" height="20"/>
    </svg>
    """

    @Test func aCreativeCommonsBlockIsNonXMPRDF() throws {
        let url = bin.appendingPathComponent("cc.svg")
        try Data(Self.creativeCommons.utf8).write(to: url)

        #expect(try XMP.holdsNonXMPRDF(at: url))
    }

    /// Why the check exists: the write keeps only what it was given.
    @Test func aToolkitWriteReplacesTheCreativeCommonsBlock() throws {
        let url = bin.appendingPathComponent("cc.svg")
        try Data(Self.creativeCommons.utf8).write(to: url)

        try VideoXMP.writeMetadata(XMPMetadata(title: "New"), url: url)

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(!written.contains("An Author"))
        #expect(!written.contains("creativecommons.org/licenses"))
    }

    /// Packets with and without an `xpacket` wrapper, and a toolkit-written file, are XMP.
    @Test(arguments: ["plain", "packet", "minified"])
    func anXMPPacketIsNotNonXMPRDF(name: String) throws {
        let url = try fixture(name)
        #expect(try XMP.holdsNonXMPRDF(at: url) == false)

        try VideoXMP.writeMetadata(Self.metadata, url: url)
        #expect(try XMP.holdsNonXMPRDF(at: url) == false)
    }

    @Test func onlySVGIsScanned() throws {
        let url = bin.appendingPathComponent("cc.xml")
        try Data(Self.creativeCommons.utf8).write(to: url)

        #expect(try XMP.holdsNonXMPRDF(at: url) == false)
    }
}
