// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import ImageIO
import SPFKBase
import SPFKMetadata
import SPFKMetadataImage
import SPFKMetadataXMP
import SPFKTesting
import Testing
import UniformTypeIdentifiers

/// An `XMPEdit` written to a file without a `MetaAudioFileDescription`: the toolkit's diff write or
/// clear, and the production fields alone through ImageIO for a still the toolkit cannot write.
@Suite(.tags(.xmp))
class XMPEditApplyTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let dm = "http://ns.adobe.com/xmp/1.0/DynamicMedia/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

    private func packet(_ fields: [String: String]) -> String {
        var media = XMPDynamicMedia()
        if let v = fields["scene"] { media.scene = v }
        if let v = fields["cameraModel"] { media.cameraModel = v }
        if let v = fields["shotLocation"] { media.shotLocation = v }
        return media.xml
    }

    // MARK: - Toolkit

    @Test func aMovieEditAddsSceneAndKeepsAnotherAppsProperty() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)
        let baseline = try? XMP.parse(url: url)

        var edited = try baseline.map { try XMPDynamicMedia(xml: $0) } ?? XMPDynamicMedia()
        edited.scene = "A1"

        // Another app writes after the baseline was read.
        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "Lisbon", url: url)

        try XMPEdit(baseline: baseline, edited: edited.xml).applyThroughToolkit(to: url)

        let read = try XMP.getProperties([
            XMPPropertyRead(namespace: Self.dm, name: "scene"),
            XMPPropertyRead(namespace: Self.photoshop, name: "City"),
        ], url: url)
        #expect(read[0] == ["A1"])
        #expect(read[1] == ["Lisbon"])
    }

    @Test func aMovieClearDropsPacketOnlyPropertiesAndKeepsUserData() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.qtmeta_mov)
        let subject = XMPPropertyRead(namespace: Self.dc, name: "subject", isArray: true)
        let userDataBefore = try QuickTimeBoxes.userDataTypes(in: url)

        try XMP.setProperties([.array(namespace: Self.dc, name: "subject", values: ["keyword"])], url: url)
        let baseline = try XMP.parse(url: url)

        try XMPEdit(baseline: baseline, edited: nil).applyThroughToolkit(to: url)

        #expect(try XMP.getProperties([subject], url: url)[0].isEmpty)
        #expect(try QuickTimeBoxes.userDataTypes(in: url).isSuperset(of: userDataBefore))
    }

    // MARK: - ImageIO

    private func imageIOValue(_ url: URL, _ name: String) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
              let tag = CGImageMetadataCopyTagWithPath(metadata, nil, "xmpDM:\(name)" as CFString)
        else { return nil }
        return CGImageMetadataTagCopyValue(tag) as? String
    }

    private func pixels(_ url: URL) throws -> Data {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data)
        return Data(bytes: bytes, count: image.width * image.height * 4)
    }

    @Test(arguments: [TestBundleResources.shared.sharksandwich, TestBundleResources.shared.sharksandwich_heic])
    func productionFieldsRoundTripThroughImageIO(fixture: URL) throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: fixture)
        try ImageXMP.writeMetadata(XMPMetadata(title: "Kept Title"), url: url)
        let pixelsBefore = try pixels(url)

        try XMPEdit(baseline: nil, edited: packet(["scene": "A1", "cameraModel": "Model X"]))
            .applyProductionFieldsThroughImageIO(to: url)

        #expect(imageIOValue(url, "scene") == "A1")
        #expect(imageIOValue(url, "cameraModel") == "Model X")
        #expect(try ImageXMP.readMetadata(from: url).title == "Kept Title")
        #expect(try pixels(url) == pixelsBefore)
    }

    @Test func aJPEGsProductionFieldsReadBackThroughTheToolkit() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sharksandwich)

        try XMPEdit(baseline: nil, edited: packet(["scene": "A1"])).applyProductionFieldsThroughImageIO(to: url)

        #expect(try XMPDynamicMedia(xml: XMP.parse(url: url)).scene == "A1")
    }

    @Test(arguments: [TestBundleResources.shared.sharksandwich, TestBundleResources.shared.sharksandwich_heic])
    func anEmptiedFieldIsRemovedAndAnUntouchedOneKept(fixture: URL) throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: fixture)
        let first = packet(["scene": "A1", "shotLocation": "Stage 4"])
        try XMPEdit(baseline: nil, edited: first).applyProductionFieldsThroughImageIO(to: url)

        try XMPEdit(baseline: first, edited: packet(["shotLocation": "Stage 4"]))
            .applyProductionFieldsThroughImageIO(to: url)

        #expect(imageIOValue(url, "scene") == nil)
        #expect(imageIOValue(url, "shotLocation") == "Stage 4")
    }

    @Test func aClearThroughImageIOIsRefusedAndTheFileIsUntouched() throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sharksandwich_heic)
        let before = try Data(contentsOf: url)

        #expect(throws: MetadataError.unsupportedFormat(UTType(filenameExtension: "heic"), .xmp)) {
            try XMPEdit(baseline: "", edited: nil).applyProductionFieldsThroughImageIO(to: url)
        }
        #expect(try Data(contentsOf: url) == before)
    }

    @Test func onlyChangedProductionFieldsAreReported() throws {
        let baseline = packet(["scene": "A1", "cameraModel": "Model X"])
        let edited = packet(["scene": "B2", "cameraModel": "Model X", "shotLocation": "Stage 4"])

        let changes = try XMPEdit(baseline: baseline, edited: edited).productionFieldChanges()

        #expect(changes == ["scene": "B2", "shotLocation": "Stage 4"])
    }
}
