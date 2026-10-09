// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataXMP
import SPFKTesting
import Testing
import UniformTypeIdentifiers

/// Removing a file's XMP is possible only where the toolkit keeps XMP apart from the native
/// metadata it mirrors.
@Suite
class RemoveTests: BinTestCase {
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"
    private static let dc = "http://purl.org/dc/elements/1.1/"

    @Test(arguments: [TestBundleResources.shared.sample_mov, TestBundleResources.shared.tabla_m4a])
    func removingClearsTheMPEG4FamilysXMP(fixture: URL) async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: fixture)
        let city = XMPPropertyRead(namespace: Self.photoshop, name: "City")

        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "Lisbon", url: url)
        try #require(try XMP.getProperties([city], url: url)[0] == ["Lisbon"])

        try XMP.remove(from: url)

        #expect(try XMP.getProperties([city], url: url)[0].isEmpty)
    }

    /// Clearing a movie's XMP keeps the native metadata the toolkit mirrors into the packet.
    @Test func removingKeepsAMoviesUserDataAndDropsPacketOnlyProperties() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.qtmeta_mov)
        let subject = XMPPropertyRead(namespace: Self.dc, name: "subject", isArray: true)

        try XMP.setProperties([.array(namespace: Self.dc, name: "subject", values: ["keyword"])], url: url)
        try #require(try XMP.getProperties([subject], url: url)[0] == ["keyword"])

        try XMP.remove(from: url)

        #expect(try XMP.getProperties([subject], url: url)[0].isEmpty)
        #expect(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: ["©nam", "©ART", "©cpy"]))
    }

    @Test func removingKeepsAnMPEG4Copyright() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.tabla_cprt_m4a)
        let city = XMPPropertyRead(namespace: Self.photoshop, name: "City")

        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "Lisbon", url: url)

        try XMP.remove(from: url)

        #expect(try QuickTimeBoxes.userDataTypes(in: url).contains("cprt"))
        #expect(try XMP.getProperties([XMPPropertyRead(namespace: Self.dc, name: "rights")], url: url)[0] == ["ISO Copy"])
        #expect(try XMP.getProperties([city], url: url)[0].isEmpty)
    }

    @Test func removingFromAWAVIsRefusedAndTheFileIsUntouched() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)
        let before = try Data(contentsOf: url)

        #expect(XMP.canRemove(from: url) == false)
        #expect(throws: MetadataError.unsupportedFormat(UTType(filenameExtension: "wav"), .xmp)) {
            try XMP.remove(from: url)
        }

        #expect(try Data(contentsOf: url) == before)
    }

    /// A container with no XMP writer refuses the save as a typed error naming the file type.
    @Test func anXMPSaveToAContainerWithoutAWriterIsRefused() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mka)
        let before = try Data(contentsOf: url)
        var description = MetaAudioFileDescription(url: url, fileType: .mka)

        #expect(throws: MetadataError.unsupportedFormat(UTType(filenameExtension: "mka"), .xmp)) {
            try description.save(dirtyFlags: [.xmp], xmpEdit: XMPEdit(baseline: nil, edited: nil))
        }

        #expect(try Data(contentsOf: url) == before)
    }
}
