import Foundation
@testable import SPFKMetadataXMP
import SwiftTimecode
import Testing

@Suite("FrameRate")
struct FrameRateTests {
    @Test("all raw values map to valid TimecodeFrameRate")
    func allCasesMapToFrameRate() {
        let cases: [(XMPDynamicMedia.FrameRate, TimecodeFrameRate)] = [
            (.fps23_976, .fps23_976),
            (.fps24, .fps24),
            (.fps25, .fps25),
            (.fps29_97, .fps29_97),
            (.fps29_97d, .fps29_97d),
            (.fps30, .fps30),
            (.fps50, .fps50),
            (.fps59_94, .fps59_94),
            (.fps59_94d, .fps59_94d),
            (.fps60, .fps60),
        ]

        for (xmpRate, expected) in cases {
            #expect(xmpRate.frameRate == expected, "Expected \(xmpRate.rawValue) to map to \(expected)")
        }
    }

    @Test("raw values match XMP timecode format strings")
    func rawValues() {
        #expect(XMPDynamicMedia.FrameRate.fps23_976.rawValue == "23976Timecode")
        #expect(XMPDynamicMedia.FrameRate.fps24.rawValue == "24Timecode")
        #expect(XMPDynamicMedia.FrameRate.fps25.rawValue == "25Timecode")
        #expect(XMPDynamicMedia.FrameRate.fps29_97.rawValue == "2997NonDropTimecode")
        #expect(XMPDynamicMedia.FrameRate.fps29_97d.rawValue == "2997DropTimecode")
        #expect(XMPDynamicMedia.FrameRate.fps30.rawValue == "30Timecode")
        #expect(XMPDynamicMedia.FrameRate.fps50.rawValue == "50Timecode")
        #expect(XMPDynamicMedia.FrameRate.fps59_94.rawValue == "5994NonDropTimecode")
        #expect(XMPDynamicMedia.FrameRate.fps59_94d.rawValue == "5994DropTimecode")
        #expect(XMPDynamicMedia.FrameRate.fps60.rawValue == "60Timecode")
    }

    @Test("init from invalid raw value returns nil")
    func invalidRawValue() {
        #expect(XMPDynamicMedia.FrameRate(rawValue: "120Timecode") == nil)
        #expect(XMPDynamicMedia.FrameRate(rawValue: "") == nil)
    }
}
