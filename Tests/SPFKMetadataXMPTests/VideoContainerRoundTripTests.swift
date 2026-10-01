// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataImage
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Every ``XMPField`` writes and reads back on AVI and Windows Media, and the native title follows
/// `dc:title`.
@Suite
class VideoContainerRoundTripTests: BinTestCase {
    private static let metadata = XMPMetadata(
        keywords: ["one", "two"], creators: ["First", "Second"], title: "XMP Title",
        description: "A description", copyright: "A copyright", city: "Lisbon", state: "Lisboa",
        country: "Portugal", subLocation: "Alfama", rating: 4, label: "Select", labelColor: "Red",
        accessibilityAltText: "Alt text", accessibilityDescription: "Extended description"
    )

    @Test func anAVIRoundTripsEveryFieldAndRenamesItsINFOTitle() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.sample_avi)
        #expect(try VideoXMP.readMetadata(from: url).title == "AVI Title")

        try VideoXMP.writeMetadata(Self.metadata, url: url)

        #expect(try VideoXMP.readMetadata(from: url) == Self.metadata)

        let data = try Data(contentsOf: url)
        #expect(data.range(of: Data("AVI Title".utf8)) == nil)
    }

    @Test func aWindowsMediaFileRoundTripsEveryFieldAndRenamesItsASFTitle() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.sample_wmv)
        #expect(try ASFContentDescription.title(in: url) == "WMV Title")

        try VideoXMP.writeMetadata(Self.metadata, url: url)

        #expect(try VideoXMP.readMetadata(from: url) == Self.metadata)

        #expect(try ASFContentDescription.title(in: url) == "XMP Title")
    }
}

/// The title from an ASF file's Content Description object.
enum ASFContentDescription {
    // 75B22633-668E-11CF-A6D9-00AA0062CE6C, in ASF's mixed-endian GUID layout.
    private static let guid = Data([
        0x33, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11, 0xA6, 0xD9, 0x00, 0xAA, 0x00, 0x62, 0xCE, 0x6C,
    ])

    static func title(in url: URL) throws -> String? {
        let data = try Data(contentsOf: url)
        guard let start = data.range(of: guid)?.lowerBound else { return nil }

        // GUID, 64-bit object size, then five 16-bit string lengths; the title comes first.
        let lengths = start + 24
        guard lengths + 10 <= data.count else { return nil }

        let titleLength = Int(data[lengths]) | Int(data[lengths + 1]) << 8
        let title = lengths + 10
        guard title + titleLength <= data.count else { return nil }

        return String(data: data[title ..< title + titleLength], encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }
}
