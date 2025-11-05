import AEXML
import Foundation
@testable import SPFKMetadataXMP
import SPFKMetadataXMPC
import SPFKTesting
import SPFKUtils
import Testing
import TimecodeKit

class FileTests: BinTestCase {
    func write(document: AEXMLDocument, to url: URL) throws {
        try document.xml.write(
            to: url.appendingPathExtension("xml"),
            atomically: false,
            encoding: .utf8
        )
    }

    @Test func parseMP3() async throws {
        deleteBinOnExit = false

        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        let newXML = try xml(named: "sample1.xml")

        XMPWrapper.write(newXML, toPath: url.path)

        let xmp = try XMPMetadata(url: url)
        Log.debug(xmp.document.xml)
    }

    @Test func parse2() async throws {
        deleteBinOnExit = false

        let tmp = URL(fileURLWithPath: "/Users/rf/Downloads/TestResources/no metadata.mp3")
        let url = try copyToBin(url: tmp)

        let xmp = try XMPMetadata(url: url)
        Log.debug(xmp.document.xml)

        let newXML = try xml(named: "id3.xml")
        XMPWrapper.write(newXML, toPath: url.path)

        let xmp2 = try XMPMetadata(url: url)
        Log.debug(xmp2.document.xml)
    }

    @Test func parseBEXT() async throws {
        deleteBinOnExit = false

        let url = TestBundleResources.shared.wav_bext_v2
        let xmp = try XMPMetadata(url: url)

        Log.debug(xmp.document.xml)
    }
}
