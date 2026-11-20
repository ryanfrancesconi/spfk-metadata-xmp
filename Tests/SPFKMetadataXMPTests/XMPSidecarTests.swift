// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Finding, reading and writing a file's sidecar.
@Suite(.tags(.file, .xmpSidecar))
final class XMPSidecarTests: BinTestCase {
    private static let xmp = "http://ns.adobe.com/xap/1.0/"
    private static let crs = "http://ns.adobe.com/camera-raw-settings/1.0/"

    @Test func writeThenReadRoundTrips() throws {
        let raw = bin.appendingPathComponent("DSCF3303.RAF")
        let packet = try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: nil)

        #expect(try XMPSidecar.packet(for: raw) == nil)

        try XMPSidecar.write(packet, for: raw)

        #expect(FileManager.default.fileExists(atPath: bin.appendingPathComponent("DSCF3303.xmp").path))
        #expect(try XMPSidecar.packet(for: raw) == packet)
    }

    @Test func anEmptyPacketRemovesTheSidecar() throws {
        let raw = bin.appendingPathComponent("DSCF3303.RAF")
        try XMPSidecar.write(try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "3")], toPacket: nil), for: raw)

        try XMPSidecar.write("", for: raw)

        #expect(try XMPSidecar.packet(for: raw) == nil)
        try XMPSidecar.write("", for: raw)
    }

    @Test func anExistingUpperCaseSidecarIsWrittenInPlace() throws {
        let raw = bin.appendingPathComponent("DSCF3303.RAF")
        let upper = bin.appendingPathComponent("DSCF3303.XMP")
        try Data(try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "1")], toPacket: nil).utf8).write(to: upper)

        #expect(XMPSidecar.url(for: raw).lastPathComponent == "DSCF3303.XMP")

        let updated = try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "5")], toPacket: XMPSidecar.packet(for: raw))
        try XMPSidecar.write(updated, for: raw)

        let names = try FileManager.default.contentsOfDirectory(atPath: bin.path).filter { $0.lowercased().hasSuffix(".xmp") }
        #expect(names == ["DSCF3303.XMP"])
        #expect(try XMP.getProperties([XMPPropertyRead(namespace: Self.xmp, name: "Rating")], inPacket: try #require(try XMPSidecar.packet(for: raw))) == [["5"]])
    }

    @Test func aReadOnlyFolderRefusesTheWrite() throws {
        let folder = bin.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }

        #expect(throws: (any Error).self) {
            try XMPSidecar.write("<x/>", for: folder.appendingPathComponent("DSCF3303.RAF"))
        }
    }

    @Test(.enabled(if: RAWSamples.folder != nil))
    func anAdobeSidecarKeepsItsPropertiesThroughAWrite() throws {
        let source = try #require(RAWSamples.url("GX010321.xmp"))
        let media = bin.appendingPathComponent("GX010321.RAF")
        try FileManager.default.copyItem(at: source, to: media.xmpSidecarURL)

        let original = try #require(try XMPSidecar.packet(for: media))
        let rawFileName = XMPPropertyRead(namespace: Self.crs, name: "RawFileName")
        let before = try XMP.getProperties([rawFileName], inPacket: original)

        try XMPSidecar.write(try XMP.applying([.simple(namespace: Self.xmp, name: "Rating", value: "4")], toPacket: original), for: media)
        let written = try #require(try XMPSidecar.packet(for: media))

        #expect(before.first?.isEmpty == false)
        #expect(try XMP.getProperties([rawFileName], inPacket: written) == before)
        #expect(try XMP.changedProperties(from: original, to: written).map(\.path) == ["xmp:Rating"])
    }
}
