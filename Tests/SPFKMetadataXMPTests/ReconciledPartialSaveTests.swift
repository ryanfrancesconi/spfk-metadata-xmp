// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import CoreGraphics
import Foundation
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// On a reconciled container the XMP edit is its own write, so a native part that fails does not
/// cost it, and the error says the XMP was written.
@Suite
class ReconciledPartialSaveTests: BinTestCase {
    private static let packet = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/">
        <xmpDM:scene>Partial Scene</xmpDM:scene>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """

    @Test(arguments: [TestBundleResources.shared.tabla_m4a, TestBundleResources.shared.tabla_aif])
    func aFailedArtworkWriteStillWritesTheXMP(source: URL) async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: source)
        var description = try await MetaAudioFileDescription(parsing: url)

        // Wider than JPEG can store, and JPEG is where an untyped image is encoded.
        let context = try #require(CGContext(
            data: nil, width: 70000, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ))
        description.imageDescription.cgImage = context.makeImage()
        description.tagProperties[.title] = "Partial"

        let baseline = try packetIfPresent(at: url)
        let edited = try #require(try XMP.merging(changesFrom: nil, to: Self.packet, onto: baseline))

        #expect(throws: MetadataError.incompleteSave(
            written: Set(MetadataDirtyFlag.tags.components + [.xmp]),
            failures: [.writeFailed(.artwork, url)]
        )) {
            try description.save(dirtyFlags: [.tags, .image, .xmp], xmpEdit: XMPEdit(baseline: baseline, edited: edited))
        }

        #expect(try XMP.parse(url: url).contains("Partial Scene"))

        let reread = try await MetaAudioFileDescription(parsing: url)
        #expect(reread.tagProperties[.title] == "Partial")
    }
}
