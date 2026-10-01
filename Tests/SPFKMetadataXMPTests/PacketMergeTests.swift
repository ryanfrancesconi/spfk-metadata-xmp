// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKMetadataXMP
import Testing

/// Merging an edit into a stored packet without a file.
@Suite
struct PacketMergeTests {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

    private static func packet(_ body: String) -> String {
        """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/">
        \(body)
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """
    }

    private static let title = XMPPropertyRead(namespace: dc, name: "title")
    private static let city = XMPPropertyRead(namespace: photoshop, name: "City")

    @Test func anEditIsAppliedOverAPropertyTheCurrentPacketGainedElsewhere() throws {
        let baseline = Self.packet("<photoshop:State>Lisboa</photoshop:State>")
        let edited = Self.packet("<photoshop:State>Lisboa</photoshop:State><dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">New</rdf:li></rdf:Alt></dc:title>")
        let current = Self.packet("<photoshop:State>Lisboa</photoshop:State><photoshop:City>Porto</photoshop:City>")

        let merged = try #require(try XMP.merging(changesFrom: baseline, to: edited, onto: current))

        #expect(try XMP.getProperties([Self.title, Self.city], inPacket: merged) == [["New"], ["Porto"]])
        #expect(merged.hasPrefix("<?xpacket begin="))
    }

    @Test func aPropertyRemovedByTheEditIsRemovedFromTheCurrentPacket() throws {
        let baseline = Self.packet("<photoshop:City>Porto</photoshop:City><photoshop:State>Lisboa</photoshop:State>")
        let edited = Self.packet("<photoshop:State>Lisboa</photoshop:State>")

        let merged = try #require(try XMP.merging(changesFrom: baseline, to: edited, onto: baseline))

        #expect(try XMP.getProperties([Self.city], inPacket: merged) == [[]])
    }

    @Test func aMergeLeavingNoPropertiesIsNil() throws {
        let baseline = Self.packet("<photoshop:City>Porto</photoshop:City><photoshop:State>Lisboa</photoshop:State>")
        let edited = Self.packet("<photoshop:State>Lisboa</photoshop:State>")
        let current = Self.packet("<photoshop:City>Porto</photoshop:City>")

        #expect(try XMP.merging(changesFrom: baseline, to: edited, onto: current) == nil)
    }

    @Test func onlyTheEditedPropertyIsReportedChanged() throws {
        let baseline = Self.packet("<photoshop:City>Porto</photoshop:City><photoshop:State>Lisboa</photoshop:State>")
        let edited = Self.packet("<photoshop:City>Faro</photoshop:City><photoshop:State>Lisboa</photoshop:State>")

        #expect(try XMP.changedProperties(from: baseline, to: edited) == [
            XMPPropertyKey(namespace: Self.photoshop, path: "photoshop:City"),
        ])
    }
}
