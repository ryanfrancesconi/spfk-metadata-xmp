// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// On WAV and MP3 an XMP edit is stored by TagLib beside the native chunks, which it leaves as
/// the native save wrote them.
@Suite
class NativeOwnedXMPSaveTests: BinTestCase {
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"
    private static let city = XMPPropertyRead(namespace: photoshop, name: "City")

    private static let addition = """
    <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about="" xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/">
    <photoshop:City>Lisbon</photoshop:City>
    </rdf:Description></rdf:RDF></x:xmpmeta>
    """

    /// The packet the XMP pane would show, plus a City.
    private func cityEdit(for url: URL) throws -> XMPEdit {
        let baseline = try packetIfPresent(at: url)
        let edited = try #require(try XMP.merging(changesFrom: nil, to: Self.addition, onto: baseline))
        return XMPEdit(baseline: baseline, edited: edited)
    }

    private func saveCity(to url: URL) async throws {
        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [.tags], xmpEdit: try cityEdit(for: url))
    }

    @Test(arguments: [TestBundleResources.shared.cowbell_bext_wav, TestBundleResources.shared.tabla_mp3])
    func theStoredPacketIsReadBackByTheToolkit(fixture: URL) async throws {
        let url = try copyToBin(url: fixture)

        try await saveCity(to: url)

        #expect(try XMP.getProperties([Self.city], url: url)[0] == ["Lisbon"])
    }

    @Test func aWaveKeepsItsBEXTVersion2AndLoudness() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let bext = try #require(try IFFChunks.payload(id: "bext", in: url, bigEndian: false))

        try await saveCity(to: url)

        #expect(try IFFChunks.payload(id: "bext", in: url, bigEndian: false) == bext)
    }

    /// A WAV's chunk IDs without the `JUNK` the save signs as its own filler (`SPFK`), which
    /// reserves room after a chunk it writes and stands in for one it removes.
    private static func chunkIDs(in url: URL) throws -> [String] {
        try RIFFChunks(contentsOf: url).chunks
            .filter { !($0.id == "JUNK" && $0.payload.prefix(4) == Data("SPFK".utf8)) }
            .map(\.id)
    }

    @Test func aWaveGainsOnlyThePacketChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let before = try Self.chunkIDs(in: url)

        try await saveCity(to: url)

        // As a set: the native save moves `bext` after `data`, packet or not.
        #expect(try Set(Self.chunkIDs(in: url)) == Set(before + ["_PMX"]))
    }

    @Test func aWavesIXMLIsByteIdentical() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.ixml_chunk)
        let ixml = try #require(try IFFChunks.payload(id: "iXML", in: url, bigEndian: false))

        try await saveCity(to: url)

        #expect(try IFFChunks.payload(id: "iXML", in: url, bigEndian: false) == ixml)
    }

    /// Against a tags-only save of the same file, the XMP save adds the packet frame and nothing else.
    @Test func anMP3sFramesMatchATagsOnlySave() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp3)
        let reference = bin.appendingPathComponent("reference.mp3")
        try FileManager.default.copyItem(at: url, to: reference)

        var tagsOnly = try await MetaAudioFileDescription(parsing: reference)
        try tagsOnly.save(dirtyFlags: [.tags])

        try await saveCity(to: url)

        let frames = try ID3v2Frames.frames(in: url).filter { $0.id != "PRIV" }
        let expected = try ID3v2Frames.frames(in: reference)

        #expect(frames.map(\.id) == expected.map(\.id))
        #expect(frames.map(\.body) == expected.map(\.body))
        #expect(try ID3v2Frames.hasID3v1(in: url) == ID3v2Frames.hasID3v1(in: reference))
        #expect(try ID3v2Frames.xmpPacket(in: url) != nil)
    }

    @Test func clearingAWaveRemovesOnlyThePacketChunk() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_bext_wav)
        let before = try Self.chunkIDs(in: url)
        let bext = try IFFChunks.payload(id: "bext", in: url, bigEndian: false)
        try await saveCity(to: url)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: XMPEdit(baseline: try XMP.parse(url: url), edited: nil))

        #expect(try Set(Self.chunkIDs(in: url)) == Set(before))
        #expect(try IFFChunks.payload(id: "bext", in: url, bigEndian: false) == bext)
        #expect(try XMP.getProperties([Self.city], url: url)[0].isEmpty)
    }

    @Test func clearingAnMP3RemovesThePacketFrame() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_xmp)
        try #require(try ID3v2Frames.xmpPacket(in: url) != nil)

        var description = try await MetaAudioFileDescription(parsing: url)
        try description.save(dirtyFlags: [], xmpEdit: XMPEdit(baseline: try XMP.parse(url: url), edited: nil))

        #expect(try ID3v2Frames.xmpPacket(in: url) == nil)
        #expect(description.tagProperties.tags[.title] == "Stonehenge")
    }

    @Test func clearingIsAvailableWhereNativeMetadataSurvivesIt() {
        for pathExtension in ["wav", "mp3", "m4a", "mov"] {
            #expect(XMPEdit.canClear(url: URL(fileURLWithPath: "/tmp/a.\(pathExtension)")), "\(pathExtension)")
        }

        for pathExtension in ["aif", "dng"] {
            #expect(!XMPEdit.canClear(url: URL(fileURLWithPath: "/tmp/a.\(pathExtension)")), "\(pathExtension)")
        }
    }
}
