// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Writing properties into a packet in memory.
@Suite(.tags(.xmpSidecar))
struct PacketWriteTests {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let xmp = "http://ns.adobe.com/xap/1.0/"
    private static let crs = "http://ns.adobe.com/camera-raw-settings/1.0/"
    private static let xmpMM = "http://ns.adobe.com/xap/1.0/mm/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

    /// A Camera Raw style sidecar: `crs:` and `xmpMM:` beside the fields the writes touch.
    private static let lightroomPacket = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about=""
            xmlns:xmp="http://ns.adobe.com/xap/1.0/"
            xmlns:dc="http://purl.org/dc/elements/1.1/"
            xmlns:photoshop="http://ns.adobe.com/photoshop/1.0/"
            xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/"
            xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
            xmp:Rating="2" photoshop:City="Porto"
            xmpMM:DocumentID="xmp.did:1234" crs:Exposure2012="+0.50" crs:RawFileName="DSCF3303.RAF">
        <dc:subject><rdf:Bag><rdf:li>old</rdf:li></rdf:Bag></dc:subject>
        <crs:ToneCurvePV2012><rdf:Seq><rdf:li>0, 0</rdf:li><rdf:li>255, 255</rdf:li></rdf:Seq></crs:ToneCurvePV2012>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """

    private static let rating = XMPPropertyRead(namespace: xmp, name: "Rating")
    private static let subject = XMPPropertyRead(namespace: dc, name: "subject", isArray: true)
    private static let city = XMPPropertyRead(namespace: photoshop, name: "City")
    private static let untouched = [
        XMPPropertyRead(namespace: xmpMM, name: "DocumentID"),
        XMPPropertyRead(namespace: crs, name: "Exposure2012"),
        XMPPropertyRead(namespace: crs, name: "RawFileName"),
        XMPPropertyRead(namespace: crs, name: "ToneCurvePV2012", isArray: true),
    ]

    @Test func writesChangeExactlyTheirPropertiesAndKeepTheRest() throws {
        let packet = try XMP.applying([
            .simple(namespace: Self.xmp, name: "Rating", value: "4"),
            .array(namespace: Self.dc, name: "subject", values: ["a", "b"]),
            .removal(namespace: Self.photoshop, name: "City"),
        ], toPacket: Self.lightroomPacket)

        #expect(try XMP.getProperties([Self.rating, Self.subject, Self.city], inPacket: packet) == [["4"], ["a", "b"], []])
        #expect(
            try XMP.getProperties(Self.untouched, inPacket: packet)
                == XMP.getProperties(Self.untouched, inPacket: Self.lightroomPacket)
        )

        let changed = Set(try XMP.changedProperties(from: Self.lightroomPacket, to: packet).map(\.path))
        #expect(changed == ["xmp:Rating", "dc:subject", "photoshop:City"])
    }

    @Test func writesToNoPacketMakeOneHoldingOnlyThem() throws {
        let packet = try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: nil)

        #expect(packet.hasPrefix("<?xpacket begin="))
        #expect(try XMP.changedProperties(from: nil, to: packet).map(\.path) == ["xmp:Rating"])
        #expect(try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: "") == packet)
    }

    @Test func removingTheLastPropertyLeavesAnEmptyPacket() throws {
        let packet = try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: nil)
        #expect(try XMP.applying([.removal(namespace: Self.xmp, name: "Rating")], toPacket: packet) == "")
    }

    @Test func anEmptyArraySurvivesASerializeAndReadsAsPresent() throws {
        let written = try XMP.applying([.array(namespace: Self.dc, name: "subject", values: [])], toPacket: Self.lightroomPacket)
        let reparsed = try XMP.applying([], toPacket: written)

        #expect(try XMP.getProperties([Self.subject], inPacket: reparsed) == [[]])
        #expect(try XMP.changedProperties(from: nil, to: reparsed).map(\.path).contains("dc:subject"))
    }

    @Test func anEmptyScalarSurvivesASerializeAndReadsAsPresent() throws {
        let written = try XMP.applying([
            .simple(namespace: Self.photoshop, name: "City", value: ""),
            .localized(namespace: Self.dc, name: "title", value: ""),
        ], toPacket: nil)
        let reparsed = try XMP.applying([], toPacket: written)

        #expect(Set(try XMP.changedProperties(from: nil, to: reparsed).map(\.path)) == ["photoshop:City", "dc:title"])
    }

    @Test func aPacketHoldingNoPropertiesIsRefused() {
        #expect(throws: (any Error).self) {
            try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: "not xmp")
        }
    }
}
