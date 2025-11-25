import AEXML
import Foundation
import SPFKMetadataXMP
import SPFKTesting
import SPFKUtils
import Testing
import TimecodeKit

/// XMP will translate existing metadata into XMP and return it as xml
/// see id3.xml, wave.xml
// @Suite(.serialized)
class FileTests: BinTestCase {
    let xmp = XMP.shared

    deinit {
        Log.debug("* { FileTests }")
    }

    @Test func parseMP3() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let xmp = try await XMPMetadata(url: url)
        Log.debug(xmp.document.xml)

        #expect(xmp.title == "Stonehenge")
    }

    @Test func writeID3_XMP() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        let xmpMetadata = try await XMPMetadata(url: url)
        Log.debug(xmpMetadata.document.root.xml)

        // if there is no metadata, xmp will return a minimal doc that it creates.

        // <x:xmpmeta x:xmptk="XMP Core 6.0.0" xmlns:x="adobe:ns:meta/">
        //    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        //        <rdf:Description rdf:about="" />
        //    </rdf:RDF>
        // </x:xmpmeta>

        let description = try #require(xmpMetadata.document.root[.rdf]?[.description])

        #expect(description.children.isEmpty)

        // read in an xml definition from this file
        let newXML = try xml(named: "id3.xml")

        // write to the new file
        try await xmp.write(string: newXML, to: url)

        let xmp2 = try await XMPMetadata(url: url)
        Log.debug(xmp2.document.xml)

        #expect(xmp2.title == "Stonehenge")
    }

    /// Resources/wave.xml
    @Test func parseBEXT() async throws {
        deleteBinOnExit = false

        let url = TestBundleResources.shared.wav_bext_v2
        let xmpMetadata = try await XMPMetadata(url: url)

        Log.debug(xmpMetadata.document.xml)

        #expect(xmpMetadata.title == "Stonehenge")
    }

    /// tests calling C++ API with multiple threads
    @Test func concurrentRead() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)"); defer { benchmark.stop() }

        let urls = TestBundleResources.shared.formats + TestBundleResources.shared.audioCases

        let result = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) { taskGroup in
            for url in urls {
                taskGroup.addTask {
                    try await XMPMetadata(url: url)
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

        #expect(result.count == urls.count)
    }

    @Test func concurrentWrite() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)"); defer { benchmark.stop() }

        // xmp will write these formats
        let formats: [URL] = [
            TestBundleResources.shared.tabla_aac,
            TestBundleResources.shared.tabla_aif,
            TestBundleResources.shared.tabla_m4a,
            TestBundleResources.shared.tabla_mp3,
            TestBundleResources.shared.tabla_mp4,
            TestBundleResources.shared.tabla_wav,
        ]

        let urls = try copyToBin(urls: formats)

        // read in an xml definition from this file
        let newXML = try xml(named: "id3.xml")

        // capture a local actor reference (avoids capturing self in the sending closure)
        let xmp = self.xmp

        let result = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) { taskGroup in
            for url in urls {
                // bind per-iteration values so the closure captures immutable Sendable values
                let urlCopy = url
                let xmlCopy = newXML

                taskGroup.addTask {
                    // write to the new file using the actor reference
                    try await xmp.write(string: xmlCopy, to: urlCopy)
                    return try await XMPMetadata(url: urlCopy)
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

        #expect(result.count == urls.count)

        for item in result {
            #expect(item.title == "Stonehenge", "\(item.document.xml)")
        }
    }
}
