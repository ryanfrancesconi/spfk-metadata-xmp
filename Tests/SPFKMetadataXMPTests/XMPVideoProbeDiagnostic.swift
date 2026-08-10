// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import SPFKTesting
import Testing

@testable import SPFKMetadataXMP

/// TEMPORARY diagnostic — writes XMP into the file named by `SPFK_XMP_PROBE_FILE` and prints the
/// track set either side. Delete once the video track-loss defect is characterized.
@Suite(.tags(.development))
final class XMPVideoProbeDiagnostic {
    private func trackSummary(_ url: URL) async throws -> String {
        let tracks = try await AVURLAsset(url: url).load(.tracks)
        var parts: [String] = []
        for track in tracks {
            let formats = try await track.load(.formatDescriptions)
            let fourCC = formats.first.map { desc -> String in
                let c = CMFormatDescriptionGetMediaSubType(desc)
                let bytes = [UInt8((c >> 24) & 0xFF), UInt8((c >> 16) & 0xFF), UInt8((c >> 8) & 0xFF), UInt8(c & 0xFF)]
                return String(bytes: bytes, encoding: .ascii) ?? "?"
            } ?? "?"
            parts.append("\(track.mediaType.rawValue):\(fourCC)")
        }
        return parts.joined(separator: ", ")
    }

    @Test func probe() async throws {
        guard let path = ProcessInfo.processInfo.environment["SPFK_XMP_PROBE_FILE"] else {
            print("PROBE: no SPFK_XMP_PROBE_FILE set, skipping")
            return
        }

        let url = URL(fileURLWithPath: path)
        let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0

        print("PROBE: file \(url.lastPathComponent) size \(size)")
        print("PROBE: before  \(try await trackSummary(url))")
        print("PROBE: audio frames before \((try? AVAudioFile(forReading: url))?.length ?? -1)")

        let xmp = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="probe">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
            xmlns:dc="http://purl.org/dc/elements/1.1/">
           <dc:title>
            <rdf:Alt><rdf:li xml:lang="x-default">probe</rdf:li></rdf:Alt>
           </dc:title>
          </rdf:Description>
         </rdf:RDF>
        </x:xmpmeta>
        """

        do {
            try XMP.write(string: xmp, to: url)
            print("PROBE: XMP write ok")
        } catch {
            print("PROBE: XMP write threw \(error)")
        }

        let sizeAfter = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        print("PROBE: size after \(sizeAfter) delta \(sizeAfter - size)")
        print("PROBE: after   \(try await trackSummary(url))")
        print("PROBE: audio frames after \((try? AVAudioFile(forReading: url))?.length ?? -1)")
    }
}
