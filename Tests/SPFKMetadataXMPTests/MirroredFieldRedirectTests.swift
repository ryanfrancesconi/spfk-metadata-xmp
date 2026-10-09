// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// On WAV and MP3 an XMP edit to a property the native metadata mirrors is written to that native
/// field, since a read takes the native value over the packet's.
@Suite
class MirroredFieldRedirectTests: BinTestCase {
    private static func packet(_ body: String) -> String {
        """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/">
        \(body)
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """
    }

    /// The packet the XMP pane would show, with `body`'s properties set over it.
    private func edit(_ url: URL, setting body: String) throws -> XMPEdit {
        let baseline = try packetIfPresent(at: url)
        let edited = try #require(try XMP.merging(changesFrom: nil, to: Self.packet(body), onto: baseline))
        return XMPEdit(baseline: baseline, edited: edited)
    }

    @Test func aSceneEditLandsInTheIXMLScene() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.ixml_chunk)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: try edit(url, setting: "<xmpDM:scene>XMP Scene</xmpDM:scene>"))

        let saved = try await MetaAudioFileDescription(parsing: url)
        #expect(try saved.iXMLMetadata.map { try IXMLMetadata(xml: $0) }?.scene == "XMP Scene")
        #expect(try XMPDynamicMedia(url: url).scene == "XMP Scene")
    }

    @Test func anXMPEditWinsOverAnIXMLEditToTheSameFieldInOneSave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.ixml_chunk)
        var description = try await MetaAudioFileDescription(parsing: url)
        let xmpEdit = try edit(url, setting: "<xmpDM:scene>XMP Scene</xmpDM:scene>")

        var ixml = try IXMLMetadata(xml: try #require(description.iXMLMetadata))
        ixml.scene = "Pane Scene"
        description.iXMLMetadata = ixml.xml

        try description.save(dirtyFlags: [.tags], xmpEdit: xmpEdit)

        let saved = try await MetaAudioFileDescription(parsing: url)
        #expect(try saved.iXMLMetadata.map { try IXMLMetadata(xml: $0) }?.scene == "XMP Scene")
    }

    /// `dc:type` mirrors INFO `ISRF`, which the description does not model.
    @Test func anUnmodeledMirroredPropertyStaysInThePacket() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: try edit(url, setting: "<dc:type><rdf:Bag><rdf:li>Sound</rdf:li></rdf:Bag></dc:type>"))

        #expect(StoredXMPPacketWrite.storedPacket(in: url)?.contains("Sound") == true)
        #expect(try IFFChunks.payload(id: "LIST", in: url, bigEndian: false) == nil)
    }

    @Test func anMP3TitleEditLandsInItsTitleFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)
        let title = "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">XMP Title</rdf:li></rdf:Alt></dc:title>"

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: try edit(url, setting: title))

        let saved = try await MetaAudioFileDescription(parsing: url)
        #expect(saved.tagProperties.tags[.title] == "XMP Title")
        #expect(try XMP.getProperties([XMPPropertyRead(namespace: "http://purl.org/dc/elements/1.1/", name: "title")], url: url)[0] == ["XMP Title"])
    }

    @Test func waveKeywordsAreJoinedIntoTheirINFOItem() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let subject = "<dc:subject><rdf:Bag><rdf:li>one</rdf:li><rdf:li>two</rdf:li></rdf:Bag></dc:subject>"

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: try edit(url, setting: subject))

        let saved = try await MetaAudioFileDescription(parsing: url)
        #expect(saved.tagProperties.tags[.keywords] == "one; two")
        #expect(try XMP.getProperties([XMPPropertyRead(namespace: "http://purl.org/dc/elements/1.1/", name: "subject", isArray: true)], url: url)[0] == ["one", "two"])
    }
}
