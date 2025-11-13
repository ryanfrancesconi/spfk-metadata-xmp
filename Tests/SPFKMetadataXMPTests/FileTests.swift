import AEXML
import Foundation
@testable import SPFKMetadataXMP
import SPFKMetadataXMPC
import SPFKTesting
import SPFKUtils
import Testing
import TimecodeKit

/// XMP will translate existing metadata into XMP and return it as xml
/// see id3.xml, wave.xml
@Suite(.serialized)
class FileTests: BinTestCase {
    deinit {
        Log.debug("* { FileTests }")
    }

    @Test func parseMP3() async throws {
        deleteBinOnExit = false

        let url = TestBundleResources.shared.mp3_id3
        let xmp = try XMPMetadata(url: url)
        Log.debug(xmp.document.xml)

        #expect(xmp.title == "Stonehenge")
    }

    @Test func writeID3_XMP() async throws {
        deleteBinOnExit = false

        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)
        let xmp = try XMPMetadata(url: url)
        Log.debug(xmp.document.root.xml)

        // if there is no metadata, xmp will return a minimal doc that it creates.

        // <x:xmpmeta x:xmptk="XMP Core 6.0.0" xmlns:x="adobe:ns:meta/">
        //    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        //        <rdf:Description rdf:about="" />
        //    </rdf:RDF>
        // </x:xmpmeta>

        let description = try #require(xmp.document.root[.rdf]?[.description])
        #expect(description.children.isEmpty)

        // read in an xml definition from this file
        let newXML = try xml(named: "id3.xml")

        // write to the new file
        XMPFile.write(newXML, toPath: url.path)

        let xmp2 = try XMPMetadata(url: url)
        Log.debug(xmp2.document.xml)

        #expect(xmp2.title == "Stonehenge")
    }

    /// Resources/wave.xml
    @Test func parseBEXT() async throws {
        deleteBinOnExit = false

        let url = TestBundleResources.shared.wav_bext_v2
        let xmp = try XMPMetadata(url: url)

        Log.debug(xmp.document.xml)

        #expect(xmp.title == "Stonehenge")
    }

    /// tests calling C++ API with multiple threads
    @Test func sharedState() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)"); defer { benchmark.stop() }

        let urls = TestBundleResources.shared.formats + TestBundleResources.shared.audioCases

        let group = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) { taskGroup in
            for url in urls {
                taskGroup.addTask {
                    try XMPMetadata(url: url)
                }
            }

            var mutableResults = [XMPMetadata]()

            for try await result in taskGroup {
                if let result {
                    mutableResults.append(result)
                }
            }

            return mutableResults
        }

        #expect(group.count == urls.count)
    }
}
