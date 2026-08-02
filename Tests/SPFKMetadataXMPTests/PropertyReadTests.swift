// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import SPFKUtils
import Testing

/// Reading properties back out, the counterpart to `PropertyRemovalTests`.
///
/// The shapes matter here for the same reason they do when writing: the toolkit reconciles some
/// scalars into language alternatives, and a lang-alt read with `GetProperty` comes back empty
/// with no error -- a field would look absent when it is present. These pin each shape.
@Suite
class PropertyReadTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"
    private static let xmpNS = "http://ns.adobe.com/xap/1.0/"

    @Test func readsBackEveryShapeItWrote() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperties([
            .simple(namespace: Self.dc, name: "title", value: "TheTitle"),
            .simple(namespace: Self.photoshop, name: "City", value: "Portland"),
            .simple(namespace: Self.xmpNS, name: "Rating", value: "4"),
            .array(namespace: Self.dc, name: "subject", values: ["kw1", "kw2"]),
        ], url: url)

        let values = try XMP.getProperties([
            // dc:title is the language alternative -- the case a plain GetProperty misses.
            XMPPropertyRead(namespace: Self.dc, name: "title"),
            XMPPropertyRead(namespace: Self.photoshop, name: "City"),
            XMPPropertyRead(namespace: Self.xmpNS, name: "Rating"),
            XMPPropertyRead(namespace: Self.dc, name: "subject", isArray: true),
        ], url: url)

        #expect(values[0] == ["TheTitle"])
        #expect(values[1] == ["Portland"])
        #expect(values[2] == ["4"])
        #expect(values[3] == ["kw1", "kw2"])
    }

    /// Absence is the ordinary state of most fields, so it reports empty rather than throwing.
    @Test func absentPropertiesReportEmptyRatherThanFailing() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        let values = try XMP.getProperties([
            XMPPropertyRead(namespace: Self.dc, name: "title"),
            XMPPropertyRead(namespace: Self.dc, name: "subject", isArray: true),
        ], url: url)

        #expect(values[0].isEmpty)
        #expect(values[1].isEmpty)
    }

    /// Results are index-aligned with the requests, which is the contract a caller mapping them
    /// onto named fields depends on -- a shifted result would silently put one field's value in
    /// another field.
    @Test func resultsStayAlignedWithRequestsAcrossPresentAndAbsentFields() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "Portland", url: url)

        let values = try XMP.getProperties([
            XMPPropertyRead(namespace: Self.dc, name: "title"),
            XMPPropertyRead(namespace: Self.photoshop, name: "City"),
            XMPPropertyRead(namespace: Self.dc, name: "rights"),
        ], url: url)

        #expect(values.count == 3)
        #expect(values[0].isEmpty)
        #expect(values[1] == ["Portland"])
        #expect(values[2].isEmpty)
    }

    /// A round trip through removal: what was written reads back, and what was removed reads back
    /// as absent rather than as a stale value.
    @Test func aRemovedPropertyReadsBackAsAbsent() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "Temporary", url: url)
        try XMP.setProperties([.removal(namespace: Self.dc, name: "title")], url: url)

        let values = try XMP.getProperties([XMPPropertyRead(namespace: Self.dc, name: "title")], url: url)
        #expect(values[0].isEmpty)
    }
}
