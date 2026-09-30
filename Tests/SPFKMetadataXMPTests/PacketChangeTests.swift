// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// `applyChanges` writes only what an edit changed, so anything the file gained after the edit
/// began is kept.
@Suite
class PacketChangeTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"
    private static let xmpDM = "http://ns.adobe.com/xmp/1.0/DynamicMedia/"
    private static let bext = "http://ns.adobe.com/bwf/bext/1.0/"

    private static func packet(_ properties: [String: String]) -> String {
        let attributes = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
        return """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\
        <rdf:Description rdf:about="" xmlns:photoshop="\(photoshop)" \(attributes)/>\
        </rdf:RDF></x:xmpmeta>
        """
    }

    private func value(_ namespace: String, _ name: String, url: URL) throws -> [String] {
        try XMP.getProperties([XMPPropertyRead(namespace: namespace, name: name)], url: url)[0]
    }

    @Test func onlyDifferingPropertiesAreWritten() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        let baseline = Self.packet(["photoshop:City": "a", "photoshop:State": "b"])
        try XMP.write(string: baseline, to: url)
        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "disk", url: url)

        try XMP.applyChanges(from: baseline, to: Self.packet(["photoshop:City": "a", "photoshop:State": "c"]), url: url)

        #expect(try value(Self.photoshop, "City", url: url) == ["disk"])
        #expect(try value(Self.photoshop, "State", url: url) == ["c"])
    }

    @Test func aPropertyAbsentFromTheEditIsRemoved() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        let baseline = Self.packet(["photoshop:City": "a", "photoshop:State": "b"])
        try XMP.write(string: baseline, to: url)

        try XMP.applyChanges(from: baseline, to: Self.packet(["photoshop:City": "a"]), url: url)

        #expect(try value(Self.photoshop, "City", url: url) == ["a"])
        #expect(try value(Self.photoshop, "State", url: url).isEmpty)
    }

    @Test func aFileWithoutAPacketTakesTheWholeEdit() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.applyChanges(from: nil, to: Self.packet(["photoshop:City": "a"]), url: url)

        #expect(try value(Self.photoshop, "City", url: url) == ["a"])
    }

    /// On a WAV, `setProperties` exports `bext:description` into the BEXT chunk. An edit begun
    /// before that must not put the old description back.
    @Test func nativeMetadataChangedAfterTheBaselineSurvives() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)

        let baseline = try XMP.parse(url: url)
        try #require(try value(Self.bext, "description", url: url).first?.isNotEmpty == true)

        try XMP.setProperties([.simple(namespace: Self.bext, name: "description", value: "Changed since")], url: url)

        var edited = try XMPDynamicMedia(xml: baseline)
        edited.scene = "New Scene"
        try XMP.applyChanges(from: baseline, to: edited.xml, url: url)

        #expect(try value(Self.bext, "description", url: url) == ["Changed since"])
        #expect(try value(Self.xmpDM, "scene", url: url) == ["New Scene"])
    }

    @Test(arguments: ["", "not xml at all", "<a>unterminated"])
    func anUnparseableEditIsRefusedAndTheFileIsUntouched(edited: String) async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)
        let baseline = try XMP.parse(url: url)
        let before = try Data(contentsOf: url)

        #expect(throws: (any Error).self) {
            try XMP.applyChanges(from: baseline, to: edited, url: url)
        }

        #expect(try Data(contentsOf: url) == before)
    }
}
