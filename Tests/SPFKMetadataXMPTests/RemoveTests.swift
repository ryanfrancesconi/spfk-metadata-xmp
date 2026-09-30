// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Removing a file's XMP is possible only where the toolkit keeps XMP apart from the native
/// metadata it mirrors.
@Suite
class RemoveTests: BinTestCase {
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

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

    @Test func removingFromAWAVIsRefusedAndTheFileIsUntouched() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)
        let before = try Data(contentsOf: url)

        #expect(XMP.canRemove(from: url) == false)
        #expect(throws: (any Error).self) {
            try XMP.remove(from: url)
        }

        #expect(try Data(contentsOf: url) == before)
    }
}
