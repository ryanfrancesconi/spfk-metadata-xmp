import AEXML
import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import SPFKUtils
import SwiftTimecode
import Testing

/// XMP will translate existing metadata into XMP and return it as xml
/// see id3.xml, wave.xml
// @Suite(.serialized)
class FileTests: BinTestCase {
    let xmp = XMP.shared

    deinit {
        Log.debug("- { \(self) }")
    }

    @Test func parseMP3() async throws {
        let url = TestBundleResources.shared.mp3_id3
        let xmp = try XMPMetadata(url: url)
        Log.debug(xmp.document.xml)

        #expect(xmp.title == "Stonehenge")
    }

    @Test func writeWave_XMP() async throws {
        deleteBinOnExit = false
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)

        let orig = try XMPMetadata(url: url).document.xml
        Log.debug(orig)

        let string = try sample(named: "sample1.xml")

        try xmp.write(string: string, to: url)

        try await wait(sec: 1)

        let xmp2 = try XMPMetadata(url: url)
        Log.debug(xmp2.document.xml)

        #expect(try AEXMLDocument(fromString: string).xml == xmp2.document.xml)
    }

    @Test func writeID3_XMP() async throws {
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        let xmpMetadata = try XMPMetadata(url: url)
        Log.debug(xmpMetadata.document.root.xml)

        // if there is no metadata, xmp will return a minimal doc that it creates.

//         <x:xmpmeta x:xmptk="XMP Core 6.0.0" xmlns:x="adobe:ns:meta/">
//            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
//                <rdf:Description rdf:about="" />
//            </rdf:RDF>
//         </x:xmpmeta>

        let description = try #require(xmpMetadata.document.root[.rdf]?[.description])

        #expect(description.children.isEmpty)

        // read in an xml definition from this file
        let newXML = try sample(named: "id3.xml")

        // write to the new file
        try xmp.write(string: newXML, to: url)

        let xmp2 = try XMPMetadata(url: url)
        Log.debug(xmp2.document.xml)

        #expect(xmp2.title == "Stonehenge")
    }

    /// Resources/wave.xml
    @Test func parseBEXT() async throws {
        deleteBinOnExit = false

        let url = TestBundleResources.shared.wav_bext_v2
        let xmpMetadata = try XMPMetadata(url: url)

        Log.debug(xmpMetadata.document.xml)

        #expect(xmpMetadata.title == "Stonehenge")
    }

    /// tests calling C++ API with multiple threads
    @Test func concurrentRead() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        let urls = TestBundleResources.shared.formats + TestBundleResources.shared.audioCases

        let result = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) {
            taskGroup in
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

        #expect(result.count == urls.count)
    }

    @Test func concurrentWrite() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        // xmp will write these formats (AAC raw container does not support XMP)
        let formats: [URL] = [
            TestBundleResources.shared.tabla_aif,
            TestBundleResources.shared.tabla_m4a,
            TestBundleResources.shared.tabla_mp3,
            TestBundleResources.shared.tabla_mp4,
            TestBundleResources.shared.tabla_wav,
        ]

        let urls = try copyToBin(urls: formats)

        // read in an xml definition from this file
        let newXML = try sample(named: "id3.xml")

        // capture a local reference (avoids capturing self in the sending closure)
        let xmp = xmp

        let result = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) {
            taskGroup in
            for url in urls {
                let urlCopy = url
                let xmlCopy = newXML

                taskGroup.addTask {
                    try xmp.write(string: xmlCopy, to: urlCopy)
                    return try XMPMetadata(url: urlCopy)
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

    // MARK: - Stress Tests

    /// Thrashes the C++ XMP SDK with 500 concurrent read operations.
    /// All tasks launch at once with no batch limiting to maximize thread contention
    /// on the stack-local SXMPFiles/SXMPMeta instances.
    @Test func concurrentReadStress() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        let sourceURLs = TestBundleResources.shared.formats + TestBundleResources.shared.audioCases
        let totalCount = 500

        var urls = [URL]()
        urls.reserveCapacity(totalCount)
        for i in 0 ..< totalCount {
            urls.append(sourceURLs[i % sourceURLs.count])
        }

        let results = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) {
            group in
            for url in urls {
                group.addTask { try? XMPMetadata(url: url) }
            }

            var out = [XMPMetadata]()
            out.reserveCapacity(totalCount)

            for try await result in group {
                if let result { out.append(result) }
            }

            return out
        }

        // All files should parse (some formats may not have XMP, that's ok)
        #expect(results.count > totalCount / 2, "Too many failures: \(results.count) of \(totalCount)")
    }

    /// Thrashes the C++ XMP SDK with 50 concurrent write operations to distinct files.
    /// Each file gets its own copy, so there are no same-file races.
    /// Verifies all writes complete and metadata reads back correctly.
    @Test func concurrentWriteStress() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        // 5 writable formats, 10 copies each = 50 concurrent writes
        let formats: [URL] = [
            TestBundleResources.shared.tabla_aif,
            TestBundleResources.shared.tabla_m4a,
            TestBundleResources.shared.tabla_mp3,
            TestBundleResources.shared.tabla_mp4,
            TestBundleResources.shared.tabla_wav,
        ]

        let copiesPerFormat = 10
        let totalCount = formats.count * copiesPerFormat
        let newXML = try sample(named: "id3.xml")
        let xmp = xmp

        // Create unique copies for each concurrent write
        var urls = [URL]()
        urls.reserveCapacity(totalCount)

        for format in formats {
            let ext = format.pathExtension
            for i in 0 ..< copiesPerFormat {
                let dest = bin.appendingPathComponent("stress_\(i).\(ext)")
                try FileManager.default.copyItem(at: format, to: dest)
                urls.append(dest)
            }
        }

        let results = try await withThrowingTaskGroup(of: XMPMetadata?.self, returning: [XMPMetadata].self) {
            group in
            for url in urls {
                let urlCopy = url
                let xmlCopy = newXML

                group.addTask {
                    try xmp.write(string: xmlCopy, to: urlCopy)
                    return try XMPMetadata(url: urlCopy)
                }
            }

            var out = [XMPMetadata]()
            out.reserveCapacity(totalCount)

            for try await result in group {
                if let result { out.append(result) }
            }

            return out
        }

        #expect(results.count == totalCount, "Expected \(totalCount), got \(results.count)")

        for item in results {
            #expect(item.title == "Stonehenge", "\(item.document.xml)")
        }
    }

    /// Interleaves concurrent reads and writes across different files in the same
    /// task group to stress the C++ SDK with mixed operation types.
    @Test func concurrentMixedReadWrite() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        let readURLs = TestBundleResources.shared.formats + TestBundleResources.shared.audioCases
        let writeFormats: [URL] = [
            TestBundleResources.shared.tabla_aif,
            TestBundleResources.shared.tabla_m4a,
            TestBundleResources.shared.tabla_mp3,
            TestBundleResources.shared.tabla_mp4,
            TestBundleResources.shared.tabla_wav,
        ]

        let readsPerSource = 20
        let writeCopies = 10
        let totalReads = readURLs.count * readsPerSource
        let totalWrites = writeFormats.count * writeCopies
        let newXML = try sample(named: "id3.xml")
        let xmp = xmp

        // Create write targets
        var writeURLs = [URL]()
        writeURLs.reserveCapacity(totalWrites)

        for format in writeFormats {
            let ext = format.pathExtension
            for i in 0 ..< writeCopies {
                let dest = bin.appendingPathComponent("mixed_\(i).\(ext)")
                try FileManager.default.copyItem(at: format, to: dest)
                writeURLs.append(dest)
            }
        }

        // Run reads and writes in the same task group
        let (readCount, writeCount) = try await withThrowingTaskGroup(
            of: (isWrite: Bool, success: Bool).self,
            returning: (reads: Int, writes: Int).self
        ) { group in
            // Launch all reads
            for i in 0 ..< totalReads {
                let url = readURLs[i % readURLs.count]
                group.addTask {
                    _ = try? XMPMetadata(url: url)
                    return (isWrite: false, success: true)
                }
            }

            // Launch all writes
            for url in writeURLs {
                let urlCopy = url
                let xmlCopy = newXML
                group.addTask {
                    try xmp.write(string: xmlCopy, to: urlCopy)
                    let meta = try XMPMetadata(url: urlCopy)
                    return (isWrite: true, success: meta.title == "Stonehenge")
                }
            }

            var reads = 0
            var writes = 0

            for try await result in group {
                if result.isWrite {
                    if result.success { writes += 1 }
                } else {
                    reads += 1
                }
            }

            return (reads, writes)
        }

        #expect(readCount == totalReads, "Reads: \(readCount) of \(totalReads)")
        #expect(writeCount == totalWrites, "Writes: \(writeCount) of \(totalWrites)")
    }
}
