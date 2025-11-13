// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMP

import AEXML
import CoreMedia
import Foundation
import OTCore
import SPFKMetadataXMPC
import SPFKTime
import SPFKUtils
import TimecodeKit

/// A subset of XMP metadata focused on markers and timecode.
/// This is currently a parser only.
public struct XMPMetadata: Equatable {
    public static func == (lhs: XMPMetadata, rhs: XMPMetadata) -> Bool {
        lhs.frameRate == rhs.frameRate &&
            lhs.markers == rhs.markers &&
            lhs.nominalFrameRate == rhs.nominalFrameRate &&
            lhs.audioSampleRate == rhs.audioSampleRate &&
            lhs.audioChannelType == rhs.audioChannelType &&
            lhs.videoFrameSize == rhs.videoFrameSize &&
            lhs.videoFieldOrder == rhs.videoFieldOrder &&
            lhs.startTimecodeResolved == rhs.startTimecodeResolved &&
            lhs.trackName == rhs.trackName &&
            lhs.trackType == rhs.trackType
    }

    public private(set) var document: AEXMLDocument

    /**
     <dc:title>
         <rdf:Alt>
             <rdf:li xml:lang="x-default">HELLO</rdf:li>
         </rdf:Alt>
     </dc:title>
     */
    public var title: String?

    public var frameRate: TimecodeFrameRate? {
        startTimecode?.frameRate ?? estimatedFrameRate
    }

    public private(set) var markers: [XMPMarker]?

    /**
     <xmpDM:videoFrameRate>25.000000</xmpDM:videoFrameRate>
     */
    public private(set) var nominalFrameRate: Float?

    private var estimatedFrameRate: TimecodeFrameRate? {
        guard let fps = nominalFrameRate else { return nil }
        return TimecodeFrameRate(fps: fps)
    }

    /**
     <xmp:CreatorTool>Adobe Premiere Pro 2022.0 (Macintosh)</xmp:CreatorTool>
     */
    public private(set) var creatorTool: String?

    /**
     <xmp:CreateDate>2021-12-04T22:13:58Z</xmp:CreateDate>
     */
    public private(set) var createDate: String?

    /**
     <xmpDM:audioSampleRate>48000</xmpDM:audioSampleRate>
     */
    public private(set) var audioSampleRate: Double?

    /**
     <xmpDM:audioChannelType>Stereo</xmpDM:audioChannelType>
     */
    public private(set) var audioChannelType: String?

    /**
     <xmpDM:videoFrameSize rdf:parseType="Resource">
         <stDim:w>1920</stDim:w>
         <stDim:h>1080</stDim:h>
         <stDim:unit>pixel</stDim:unit>
     </xmpDM:videoFrameSize>
     */
    public private(set) var videoFrameSize: CGSize?

    /**
     <xmpDM:videoFieldOrder>Progressive</xmpDM:videoFieldOrder>
     */
    public private(set) var videoFieldOrder: String?

    /**
     the timecode of the first frame of video in the file, as obtained from the device control.

     <xmpDM:startTimecode rdf:parseType="Resource">
         <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat>
         <xmpDM:timeValue>00:00:00:00</xmpDM:timeValue>
     </xmpDM:startTimecode>

     23976Timecode
     24Timecode,
     25Timecode,
     2997DropTimecode (semicolon delimiter),
     2997NonDropTimecode,
     30Timecode,
     50Timecode,
     5994DropTimecode,
     5994NonDropTimecode,
     60Timecode,
     */
    public private(set) var startTimecode: Timecode?

    /**
     A timecode set by the user. When specified, it is used instead of the startTimecode.

     <xmpDM:altTimecode rdf:parseType="Resource">
         <xmpDM:timeValue>00:00:00:00</xmpDM:timeValue>
         <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat>
     </xmpDM:altTimecode>
     */
    private(set) var altTimecode: Timecode?

    public var startTimecodeResolved: Timecode? {
        altTimecode ?? startTimecode
    }

    public private(set) var startTimeScale: CMTimeScale?
    public private(set) var startTimeSampleSize: CMTimeValue?
    public private(set) var duration: TimeInterval?
    public private(set) var trackName: String?
    public private(set) var trackType: String?

    /// Create a XMPMetadata struct by passing it a URL to a file
    /// - Parameter path: the file to open
    public init(url: URL) throws {
        try self.init(path: url.path)
    }

    /// Create a XMPMetadata struct by passing it a path to a file
    /// - Parameter path: the file to open
    public init(path: String) throws {
        // XMPLifecycle.initialize()

        guard let xmlString = XMPFile(path: path)?.xmpString else {
            throw NSError(description: "Failed to find an XMP chunk in the file: " + path)
        }

        try self.init(xml: xmlString)
    }

    /// Create a XMPMetadata struct by passing it a XMP xml string
    /// - Parameter xml: a valid xml string
    public init(xml: String) throws {
        let doc = try AEXMLDocument(xml: xml)
        self.init(document: doc)
    }

    /// All Inits resolve here.
    ///
    /// Create a XMPMetadata struct by passing it a valid AEXMLDocument. This isn't an exhaustive parse, but
    /// currently only containing items of interest to us.
    ///
    /// - Parameter doc: an `AEXMLDocument`
    public init(document doc: AEXMLDocument) {
        document = doc

        // <rdf:RDF><<rdf:Description>
        guard let desc = doc.root[.rdf]?[.description] else {
            Log.error("Failed to find RDF description")
            return
        }

        title = desc[.title]?[.alt]?[.li]?.value

        creatorTool = desc[.creatorTool]?.value
        createDate = desc[.createDate]?.value

        // nominal frame rate as a Float
        if let value = desc[.videoFrameRate]?.value?.float {
            nominalFrameRate = value
        }

        // start timecode
        if let element = desc[.startTimecode],
           let value = parseTimecode(element: element) {
            startTimecode = value
        }

        // A timecode set by the user. When specified, it is used instead of the startTimecode.
        if let element = desc[.altTimecode],
           let value = parseTimecode(element: element) {
            altTimecode = value
        }

        audioSampleRate = desc[.audioSampleRate]?.value?.double
        audioChannelType = desc[.audioChannelType]?.value
        videoFieldOrder = desc[.videoFieldOrder]?.value

        // tracks location might not be consistent so search for the first occurrence of it
        let trackList = desc.allDescendants { element in
            element.name == XMPElement.tracks.rawValue
        }

        // there can be more than one track
        if let track = trackList.first,
           let list = track[.bag]?[.li] {
            trackType = list[.trackType]?.value
            trackName = list[.trackName]?.value
        }

        // Marker can appear in more than one place
        let markerList = desc.allDescendants { element in
            element.name == XMPElement.markers.rawValue
        }

        var allMarkers = [XMPMarker]()
        for list in markerList {
            if let elements = list[.seq]?[.li]?.all {
                allMarkers += parseMarkers(elements: elements) ?? []
            }
        }

        markers = allMarkers

        if let value = desc[.startTimeScale]?.value?.int32 {
            startTimeScale = CMTimeScale(value)
        }

        if let value = desc[.startTimeSampleSize]?.value?.int32 {
            startTimeSampleSize = CMTimeValue(value)
        }

        if let element = desc[.duration] {
            duration = parseDuration(element: element)
        }
    }

    /**
     <xmpDM:duration rdf:parseType="Resource">
         <xmpDM:value>8800</xmpDM:value>
         <xmpDM:scale>1/2500</xmpDM:scale>
     </xmpDM:duration>
     */
    private func parseDuration(element: AEXMLElement) -> TimeInterval? {
        // Look at this mess
        guard let frameCount = element[.value]?.value?.double,
              let scale = element[.scale]?.value,
              let frameDuration = CMTimeString.parse(string: scale)?.seconds else {
            return nil
        }

        return frameCount * frameDuration
    }

    private func parseTimecode(element: AEXMLElement) -> Timecode? {
        guard let value = element[.timeFormat]?.value,
              let timeFormat = FrameRate(rawValue: value),
              let timeValue: String = element[.timeValue]?.value else {
            return nil
        }

        guard let timecode = try? Timecode(.string(timeValue), at: timeFormat.frameRate) else { return nil }

        guard timecode.invalidComponents.isEmpty else { return nil }

        return timecode
    }

    /**
     <rdf:li rdf:parseType="Resource">
         <xmpDM:startTime>57</xmpDM:startTime>
         <xmpDM:duration>8</xmpDM:duration>
         <xmpDM:name>h</xmpDM:name>
         <xmpDM:guid>0da28cca-90e6-410f-92f7-ecc84f8bccb6</xmpDM:guid>
         <xmpDM:cuePointParams>
             <rdf:Seq>
                 <rdf:li rdf:parseType="Resource">
                     <xmpDM:key>marker_guid</xmpDM:key>
                     <xmpDM:value>0da28cca-90e6-410f-92f7-ecc84f8bccb6</xmpDM:value>
                 </rdf:li>
             </rdf:Seq>
         </xmpDM:cuePointParams>
     </rdf:li>
     */
    private func parseMarkers(elements: [AEXMLElement]) -> [XMPMarker]? {
        guard let frameRate else {
            Log.error("didn't find a frame rate in xmp data, so unable to setup timing for markers")
            return nil
        }

        var out = [XMPMarker]()

        for element in elements {
            guard let mFrame = element[.startTime]?.value?.int else { continue }

            let mName = element[.name]?.value ?? ""
            let mDuration = element[.duration]?.value?.int ?? 0
            let mComment = element[.comment]?.value ?? ""

            let marker = XMPMarker(
                name: mName,
                comment: mComment,
                startFrame: mFrame,
                durationInFrames: mDuration,
                frameRate: frameRate
            )

            out.append(marker)
        }

        return out
    }
}
