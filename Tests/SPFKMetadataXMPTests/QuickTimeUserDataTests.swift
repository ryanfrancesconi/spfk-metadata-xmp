// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// An XMP write to a QuickTime movie keeps the text items in `moov/udta`, which the toolkit
/// rewrites whenever it rewrites `moov`.
@Suite
class QuickTimeUserDataTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let userDataItems: Set<String> = ["©nam", "©ART", "©cpy"]

    @Test func aFirstWriteKeepsTheUserData() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.qtmeta_mov)
        try #require(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: Self.userDataItems))

        try XMP.setProperties([.localized(namespace: Self.dc, name: "title", value: "XMP Title")], url: url)

        #expect(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: Self.userDataItems))
        #expect(try XMP.getProperties([XMPPropertyRead(namespace: Self.dc, name: "title")], url: url)[0] == ["XMP Title"])
    }

    @Test func aWriteThatOutgrowsThePaddingKeepsTheUserData() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.qtmeta_mov)
        try XMP.setProperties([.localized(namespace: Self.dc, name: "title", value: "XMP Title")], url: url)

        let description = String(repeating: "A long description. ", count: 300)
        try XMP.setProperties([.localized(namespace: Self.dc, name: "description", value: description)], url: url)

        #expect(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: Self.userDataItems))
    }

    @Test func applyingChangesKeepsTheUserData() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.qtmeta_mov)
        let edited = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:subject><rdf:Bag><rdf:li>keyword</rdf:li></rdf:Bag></dc:subject>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """

        try XMP.applyChanges(from: nil, to: edited, url: url)

        #expect(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: Self.userDataItems))
    }

    /// The toolkit exports a start timecode into the movie, which needs the native `moov`.
    @Test func anMPEG4WriteCarryingAStartTimecodeSucceeds() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_m4a)
        let edited = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/">
        <xmpDM:startTimecode rdf:parseType="Resource">
        <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat><xmpDM:timeValue>01:00:00:00</xmpDM:timeValue>
        </xmpDM:startTimecode>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """

        try XMP.applyChanges(from: nil, to: edited, url: url)

        #expect(try XMP.parse(url: url).contains("01:00:00:00"))
    }
}
