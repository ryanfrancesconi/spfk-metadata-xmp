// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataImage
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// `dc:title`, `dc:description` and `dc:rights` are language alternatives: the toolkit turns a
/// plain value into an `rdf:Alt` whenever it parses a packet, so every write after the first meets
/// an existing `rdf:Alt`.
@Suite
class LanguageAlternativeWriteTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

    private func title(of url: URL) throws -> [String] {
        try XMP.getProperties([XMPPropertyRead(namespace: Self.dc, name: "title")], url: url)[0]
    }

    @Test func writingATitleTwiceSucceeds() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperties([.simple(namespace: Self.dc, name: "title", value: "One")], url: url)
        try XMP.setProperties([.simple(namespace: Self.dc, name: "title", value: "Two")], url: url)

        #expect(try title(of: url) == ["Two"])
    }

    @Test func aBatchWithATitleStillWritesItsOtherFields() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperties([.simple(namespace: Self.dc, name: "title", value: "First")], url: url)

        try XMP.setProperties([
            .simple(namespace: Self.dc, name: "title", value: "Second"),
            .simple(namespace: Self.photoshop, name: "City", value: "Lisbon"),
        ], url: url)

        let values = try XMP.getProperties([
            XMPPropertyRead(namespace: Self.dc, name: "title"),
            XMPPropertyRead(namespace: Self.photoshop, name: "City"),
        ], url: url)

        #expect(values == [["Second"], ["Lisbon"]])
    }

    /// Three entries rather than two: parsing an `rdf:Alt` holding `x-default` and one other
    /// language sets that language to the `x-default` text, so a two-entry seed loses its German.
    @Test func writingDefaultLanguageKeepsOtherLanguages() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        let packet = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
           <dc:title>
            <rdf:Alt>
             <rdf:li xml:lang="x-default">Hello</rdf:li>
             <rdf:li xml:lang="de-DE">Hallo</rdf:li>
             <rdf:li xml:lang="fr-FR">Bonjour</rdf:li>
            </rdf:Alt>
           </dc:title>
          </rdf:Description>
         </rdf:RDF>
        </x:xmpmeta>
        """
        try XMP.write(string: packet, to: url)
        try #require(try XMP.parse(url: url).contains("Hallo"))

        try XMP.setProperties([.simple(namespace: Self.dc, name: "title", value: "Goodbye")], url: url)

        let written = try XMP.parse(url: url)
        #expect(written.contains("Goodbye"))
        #expect(written.contains("Hallo"))
        #expect(written.contains("Bonjour"))
    }

    @Test func videoMetadataSavesTwiceWithTitleDescriptionAndCopyright() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        var metadata = try VideoXMP.readMetadata(from: url)
        metadata.title = "Title 1"
        metadata.description = "Description 1"
        metadata.copyright = "Copyright 1"
        try VideoXMP.writeMetadata(metadata, url: url)

        metadata.title = "Title 2"
        metadata.description = "Description 2"
        metadata.copyright = "Copyright 2"
        try VideoXMP.writeMetadata(metadata, url: url)

        let readBack = try VideoXMP.readMetadata(from: url)
        #expect(readBack.title == "Title 2")
        #expect(readBack.description == "Description 2")
        #expect(readBack.copyright == "Copyright 2")
    }
}
