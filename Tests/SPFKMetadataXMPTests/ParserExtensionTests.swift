import Foundation
@testable import SPFKMetadataXMP
import SwiftTimecode
import Testing

@Suite("XMPMetadata Parser - Additional Samples")
struct ParserExtensionTests {
    // MARK: - sample3: 25fps, 4 markers, Premiere Pro, videoFrameSize, duration

    @Test("sample3 parses Premiere Pro 25fps with markers")
    func parseSample3() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample3.xml"))

        #expect(xmp.creatorTool == "Adobe Premiere Pro 2022.0 (Macintosh)")
        #expect(xmp.createDate == "2021-12-04T22:13:58Z")
        #expect(xmp.nominalFrameRate == 25.0)
        #expect(xmp.frameRate == .fps25)
        #expect(xmp.audioSampleRate == 48000)
        #expect(xmp.audioChannelType == "Stereo")
        #expect(xmp.videoFieldOrder == "Progressive")
        #expect(xmp.startTimeScale == 25)
        #expect(xmp.startTimeSampleSize == 1)

        #expect(xmp.startTimecode?.stringValue() == "00:00:00:00")
        #expect(xmp.altTimecode?.stringValue() == "00:00:00:00")

        // startTimecodeResolved should prefer altTimecode
        #expect(xmp.startTimecodeResolved == xmp.altTimecode)

        let markers = try #require(xmp.markers)
        #expect(markers.count == 4)

        // duration: 255360 * 1/90000 = 2.8373... seconds
        let duration = try #require(xmp.duration)
        #expect(abs(duration - 2.8373) < 0.01)
    }

    // MARK: - sample5: 25fps, multiple marker tracks

    @Test("sample5 parses Media Encoder with markers")
    func parseSample5() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample5.xml"))

        #expect(xmp.creatorTool == "Adobe Adobe Media Encoder 2022.0 (Macintosh)")
        #expect(xmp.nominalFrameRate == 25.0)
        #expect(xmp.frameRate == .fps25)
        #expect(xmp.audioSampleRate == 48000)
        #expect(xmp.audioChannelType == "Stereo")

        let markers = try #require(xmp.markers)
        // sample5 has markers in the Markers track
        #expect(markers.count >= 2)
    }

    // MARK: - sample6: minimal, 23.976, no markers, no frame rate in description

    @Test("sample6 parses minimal 23.976 metadata")
    func parseSample6() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample6.xml"))

        // sample6 has altTimecode with 23976Timecode
        #expect(xmp.altTimecode?.stringValue() == "00:00:00:00")
        #expect(xmp.frameRate == .fps23_976)
        #expect(xmp.startTimeScale == 24000)
        #expect(xmp.startTimeSampleSize == 1001)

        // duration: 77077 * 1/24000 = ~3.2115 seconds
        let duration = try #require(xmp.duration)
        #expect(abs(duration - 3.2115) < 0.01)

        // No markers in this file
        #expect(xmp.markers?.isEmpty == true)
    }

    // MARK: - sample7: 23.976, 16 markers, non-zero start TC

    @Test("sample7 parses 23.976fps with 16 markers and offset timecode")
    func parseSample7() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample7.xml"))

        #expect(xmp.creatorTool == "Adobe Premiere Pro 2022.0 (Macintosh)")
        #expect(xmp.frameRate == .fps23_976)
        #expect(xmp.audioSampleRate == 48000)

        #expect(xmp.startTimecode?.stringValue() == "00:00:10:01")
        #expect(xmp.altTimecode?.stringValue() == "00:00:10:01")

        let markers = try #require(xmp.markers)
        #expect(markers.count == 14)

        #expect(xmp.startTimeScale == 24000)
        #expect(xmp.startTimeSampleSize == 1001)
    }

    // MARK: - sample9: 29.97 non-drop, 10 markers

    @Test("sample9 parses 29.97 non-drop with markers")
    func parseSample9() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample9.xml"))

        #expect(xmp.frameRate == .fps29_97)
        #expect(xmp.audioSampleRate == 48000)
        #expect(xmp.audioChannelType == "Stereo")

        #expect(xmp.startTimecode?.stringValue() == "00:02:13:25")
        #expect(xmp.altTimecode?.stringValue() == "00:02:13:25")

        let markers = try #require(xmp.markers)
        #expect(markers.count == 10)
    }

    // MARK: - sample10: BWF/iXML audio metadata, 23.976

    @Test("sample10 parses BWF audio metadata with high timecode")
    func parseSample10() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample10.xml"))

        #expect(xmp.audioSampleRate == 48000)

        // sample10 has a start timecode of 14:27:39:00 at 23.976
        let tc = try #require(xmp.startTimecode)
        #expect(tc.stringValue() == "14:27:39:00")
        #expect(xmp.frameRate == .fps23_976)
    }
}
