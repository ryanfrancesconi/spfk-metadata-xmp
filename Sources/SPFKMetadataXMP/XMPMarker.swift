// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMP

import Foundation
import TimecodeKit

/// https://developer.adobe.com/xmp/docs/XMPNamespaces/XMPDataTypes/Marker/
public struct XMPMarker: Equatable, CustomStringConvertible, Sendable {
    // copy and paste the output into a test to instantiate this marker value
    public var description: String {
        return "XMPMarker(name: \"\(name)\", comment: \"\(comments)\", " +
            "startFrame: \(startFrame), durationInFrames: \(durationInFrames), frameRate: .\(frameRate.rawValue))"
    }

    public var name: String
    public var comments: String
    public var startFrame: Int
    public var durationInFrames: Int = 0
    public var frameRate: TimecodeFrameRate
    public var time: TimeInterval
    public var duration: TimeInterval

    public lazy var startTimecode: Timecode? = {
        try? Timecode(.frames(startFrame), at: frameRate, base: .max100SubFrames)
    }()

    public init(
        name: String = "",
        comment: String = "",
        startFrame: Int,
        durationInFrames: Int = 0,
        frameRate: TimecodeFrameRate
    ) {
        self.name = name.trimmed
        comments = comment.trimmed
        self.startFrame = startFrame
        self.frameRate = frameRate
        self.durationInFrames = durationInFrames

        time = startFrame.double * frameRate.frameDurationInSeconds
        duration = durationInFrames.double * frameRate.frameDurationInSeconds
    }
}
