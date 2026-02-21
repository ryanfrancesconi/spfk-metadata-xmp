import Foundation
@testable import SPFKMetadataXMP
import SPFKTesting
import SPFKUtils
import SwiftTimecode
import Testing

class ParserTests {
    @Test func parseSample1() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample1.xml"))

        let altTimecode = try #require(xmp.altTimecode)
        let testTimecode = try Timecode(.components(Timecode.Components(h: 1, f: 1)), at: .fps59_94d)

        #expect(altTimecode == testTimecode)
        #expect(altTimecode.stringValue() == "01:00:00;01")

        // Should be zero at ._59_94_drop
        #expect(xmp.startTimecode == Timecode(.zero, at: .fps59_94d))

        // Double check zero property
        #expect(xmp.startTimecode == xmp.startTimecode?.zero)

        // It should choose the alt timecode
        #expect(altTimecode == xmp.startTimecodeResolved)
        #expect(altTimecode != xmp.startTimecode)

        #expect(xmp.title == "Timecode Offset Test 59.94 Drop, 1 hour 1 minute")
        #expect(xmp.startTimeScale == 60000)
        #expect(xmp.startTimeSampleSize == 1001)
    }

    @Test func parseSample2() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample2.xml"))
        #expect(xmp.duration == 3.52)
    }

    @Test func parseSample4() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample4.xml"))
        let markers = try #require(xmp.markers)

        #expect(markers.count == 7)

        let expectComment = """
        ambiance, nighttime
                [3:07PM January 20th, 2022]
                [3:38PM January 20th, 2022]
        """

        if let marker = markers.first {
            #expect(marker.name == "Gabe [#70c166b9-969e-4110-a6cb-b8cceaf74a82]")
            #expect(marker.comments == expectComment)
            #expect(marker.startFrame == 3)
            #expect(marker.frameRate == .fps24)
            #expect(marker.durationInFrames == 0)
            #expect(marker.time == 0.125)
            #expect(marker.duration == 0)
        }
    }

    @Test func parseSample8() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample8.xml"))

        let markers = try #require(xmp.markers)

        #expect(markers.count == 10, "Marker count is \(markers.count)")
        #expect(xmp.startTimecode?.stringValue() == "00:02:13:25")
        #expect(xmp.altTimecode?.stringValue() == "00:02:13:25")
        #expect(xmp.frameRate == .fps29_97)
        #expect(xmp.nominalFrameRate == 29.97003)
    }
}
