// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SwiftTimecode

/// https://developer.adobe.com/xmp/docs/XMPNamespaces/XMPDataTypes/Marker/
///
/// `time` and `duration` are authoritative. The frame fields are set only when the marker's track
/// counts in a rate a timecode can express; an audio track counting in samples has none.
public struct XMPMarker: Equatable, CustomStringConvertible, Sendable {
    // Formatted as Swift initializer source, so a logged marker can be pasted into a test.
    public var description: String {
        let frameRateString = frameRate?.stringValueVerbose ?? "nil"
        return "XMPMarker(name: \"\(name)\", comment: \"\(comments)\", "
            + "time: \(time), duration: \(duration), "
            + "startFrame: \(startFrame.map(String.init) ?? "nil"), "
            + "durationInFrames: \(durationInFrames.map(String.init) ?? "nil"), frameRate: \(frameRateString))"
    }

    public var name: String
    public var comments: String
    public var startFrame: Int?
    public var durationInFrames: Int?
    public var frameRate: TimecodeFrameRate?
    /// Seconds from the start of the media.
    public var time: TimeInterval
    /// Seconds.
    public var duration: TimeInterval

    public var startTimecode: Timecode? {
        guard let startFrame, let frameRate else { return nil }
        return try? Timecode(.frames(startFrame), at: frameRate, base: .max100SubFrames)
    }

    public init(
        name: String = "",
        comment: String = "",
        startFrame: Int,
        durationInFrames: Int = 0,
        frameRate: TimecodeFrameRate
    ) {
        self.init(
            name: name,
            comment: comment,
            time: startFrame.double * frameRate.frameDurationInSeconds,
            duration: durationInFrames.double * frameRate.frameDurationInSeconds,
            startFrame: startFrame,
            durationInFrames: durationInFrames,
            frameRate: frameRate
        )
    }

    public init(
        name: String = "",
        comment: String = "",
        time: TimeInterval,
        duration: TimeInterval = 0,
        startFrame: Int? = nil,
        durationInFrames: Int? = nil,
        frameRate: TimecodeFrameRate? = nil
    ) {
        self.name = name.trimmed
        comments = comment.trimmed
        self.time = time
        self.duration = duration
        self.startFrame = startFrame
        self.durationInFrames = durationInFrames
        self.frameRate = frameRate
    }
}
