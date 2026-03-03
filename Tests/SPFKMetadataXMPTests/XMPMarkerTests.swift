import Foundation
@testable import SPFKMetadataXMP
import SwiftTimecode
import Testing

@Suite("XMPMarker")
struct XMPMarkerTests {
    @Test("init computes time from startFrame and frameRate")
    func initComputesTime() {
        let marker = XMPMarker(
            name: "Test",
            comment: "A comment",
            startFrame: 25,
            durationInFrames: 10,
            frameRate: .fps25
        )

        #expect(marker.name == "Test")
        #expect(marker.comments == "A comment")
        #expect(marker.startFrame == 25)
        #expect(marker.durationInFrames == 10)
        #expect(marker.frameRate == .fps25)
        // 25 frames at 25fps = 1.0 second
        #expect(marker.time == 1.0)
        // 10 frames at 25fps = 0.4 seconds
        #expect(marker.duration == 0.4)
    }

    @Test("init with zero duration")
    func initZeroDuration() {
        let marker = XMPMarker(
            startFrame: 0,
            frameRate: .fps24
        )

        #expect(marker.name == "")
        #expect(marker.comments == "")
        #expect(marker.startFrame == 0)
        #expect(marker.durationInFrames == 0)
        #expect(marker.time == 0)
        #expect(marker.duration == 0)
    }

    @Test("init trims whitespace from name and comment")
    func initTrimsWhitespace() {
        let marker = XMPMarker(
            name: "  Padded Name  ",
            comment: "  Padded Comment  ",
            startFrame: 0,
            frameRate: .fps25
        )

        #expect(marker.name == "Padded Name")
        #expect(marker.comments == "Padded Comment")
    }

    @Test("description format for copy-paste usage")
    func descriptionFormat() {
        let marker = XMPMarker(
            name: "Hit",
            comment: "impact",
            startFrame: 48,
            durationInFrames: 5,
            frameRate: .fps25
        )

        let desc = marker.description
        #expect(desc.contains("XMPMarker("))
        #expect(desc.contains("name: \"Hit\""))
        #expect(desc.contains("startFrame: 48"))
        #expect(desc.contains("durationInFrames: 5"))
        #expect(desc.contains("frameRate: 25 fps"))
    }

    @Test("Equatable compares all stored properties")
    func equatable() {
        let a = XMPMarker(name: "A", startFrame: 10, frameRate: .fps25)
        let b = XMPMarker(name: "A", startFrame: 10, frameRate: .fps25)
        let c = XMPMarker(name: "B", startFrame: 10, frameRate: .fps25)
        let d = XMPMarker(name: "A", startFrame: 20, frameRate: .fps25)

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("time calculation at various frame rates")
    func timeAtVariousRates() {
        // 48 frames at 24fps = 2.0 seconds
        let m24 = XMPMarker(startFrame: 48, frameRate: .fps24)
        #expect(abs(m24.time - 2.0) < 0.001)

        // 30 frames at 30fps = 1.0 second
        let m30 = XMPMarker(startFrame: 30, frameRate: .fps30)
        #expect(abs(m30.time - 1.0) < 0.001)

        // 60 frames at 60fps = 1.0 second
        let m60 = XMPMarker(startFrame: 60, frameRate: .fps60)
        #expect(abs(m60.time - 1.0) < 0.001)
    }
}
