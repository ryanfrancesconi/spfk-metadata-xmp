// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
@testable import SPFKMetadataXMP
import SwiftTimecode
import Testing

/// A marker's `startTime` counts in its own track's `xmpDM:frameRate`, not the file's video rate.
@Suite("XMPMarker track rate")
struct XMPMarkerTrackRateTests {
    private let sampleRate = 48000

    /// sample3 with its marker track counting in samples, and marker "t" one second in.
    private func audioRatePacket() throws -> String {
        let xml = try sample(named: "sample3.xml")
        #expect(xml.contains("<xmpDM:frameRate>f25</xmpDM:frameRate>"))
        #expect(xml.contains("<xmpDM:startTime>16</xmpDM:startTime>"))
        return xml
            .replacingOccurrences(of: "<xmpDM:frameRate>f25</xmpDM:frameRate>", with: "<xmpDM:frameRate>f\(sampleRate)</xmpDM:frameRate>")
            .replacingOccurrences(of: "<xmpDM:startTime>16</xmpDM:startTime>", with: "<xmpDM:startTime>\(sampleRate)</xmpDM:startTime>")
    }

    @Test func aMarkerOnASampleRateTrackIsTimedBySamples() throws {
        let xmp = try XMPDynamicMedia(xml: audioRatePacket())
        let marker = try #require(xmp.markers?.first { $0.name == "t" })

        #expect(marker.time == 1.0)
        #expect(marker.startTimecode == nil)
    }

    @Test func aSampleRateTrackIsReadWithoutAFileFrameRate() throws {
        var xml = try audioRatePacket()
        for element in ["xmpDM:startTimecode", "xmpDM:altTimecode"] {
            let start = try #require(xml.range(of: "<\(element) "))
            let end = try #require(xml.range(of: "</\(element)>"))
            xml.removeSubrange(start.lowerBound ..< end.upperBound)
        }
        let rateLine = try #require(xml.range(of: "<xmpDM:videoFrameRate>25.000000</xmpDM:videoFrameRate>"))
        xml.removeSubrange(rateLine)

        let xmp = try XMPDynamicMedia(xml: xml)
        #expect(xmp.frameRate == nil)

        let marker = try #require(xmp.markers?.first { $0.name == "t" })
        #expect(marker.time == 1.0)
    }

    @Test func aRationalTrackRateKeepsItsFrameFields() throws {
        let frames = 1001
        let xml = try sample(named: "sample3.xml")
            .replacingOccurrences(of: "<xmpDM:frameRate>f25</xmpDM:frameRate>", with: "<xmpDM:frameRate>f24000s1001</xmpDM:frameRate>")
            .replacingOccurrences(of: "<xmpDM:startTime>16</xmpDM:startTime>", with: "<xmpDM:startTime>\(frames)</xmpDM:startTime>")

        let xmp = try XMPDynamicMedia(xml: xml)
        let marker = try #require(xmp.markers?.first { $0.name == "t" })

        let expected = Double(frames) * 1001 / 24000
        #expect(abs(marker.time - expected) < 1e-9)
        #expect(marker.frameRate == .fps23_976)
        #expect(marker.startFrame == frames)
    }
}
