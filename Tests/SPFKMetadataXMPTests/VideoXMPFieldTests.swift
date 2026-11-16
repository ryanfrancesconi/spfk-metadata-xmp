// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataImage
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Every ``XMPField`` through the toolkit on a QuickTime movie, and the contact struct's children.
@Suite
class VideoXMPFieldTests: BinTestCase {
    private static func sample(for field: XMPField) -> [String] {
        switch field.shape {
        case .bag, .seq: ["\(field.rawValue) one", "\(field.rawValue) two"]
        case .integer: ["3"]
        case .bool: ["True"]
        case .text, .langAlt, .struct: ["\(field.rawValue) value"]
        }
    }

    @Test func everyFieldWritesReadsAndClears() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        for field in XMPField.allCases {
            var metadata = XMPMetadata()
            metadata[field] = Self.sample(for: field)

            try VideoXMP.writeMetadata(metadata, url: url)
            #expect(try VideoXMP.readMetadata(from: url) == metadata, "\(field)")
        }

        try VideoXMP.writeMetadata(XMPMetadata(), url: url)
        #expect(try VideoXMP.readMetadata(from: url) == XMPMetadata())
    }

    @Test func contactChildrenAreSetChangedAndClearedWithoutLeavingAnEmptyStruct() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        var metadata = XMPMetadata()
        metadata[.contactEmail] = ["a@example.com"]
        metadata[.contactPhone] = ["555-0100"]
        metadata[.contactCity] = ["Portland"]
        try VideoXMP.writeMetadata(metadata, url: url)
        #expect(try VideoXMP.readMetadata(from: url) == metadata)

        let children = try XMP.getProperties(
            [XMPPropertyRead(namespace: XMPField.contactEmail.namespace, name: "CreatorContactInfo/Iptc4xmpCore:CiEmailWork")],
            url: url
        )
        #expect(children == [["a@example.com"]])

        metadata[.contactEmail] = ["b@example.com"]
        try VideoXMP.writeMetadata(metadata, url: url)
        #expect(try VideoXMP.readMetadata(from: url) == metadata)

        metadata[.contactPhone] = []
        try VideoXMP.writeMetadata(metadata, url: url)
        #expect(try VideoXMP.readMetadata(from: url) == metadata)

        metadata[.contactEmail] = []
        metadata[.contactCity] = []
        try VideoXMP.writeMetadata(metadata, url: url)
        #expect(try VideoXMP.readMetadata(from: url) == XMPMetadata())
        #expect(try !XMP.parse(url: url).contains("CreatorContactInfo"))
    }
}
