// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

@preconcurrency import AEXML
import CoreMedia
import Foundation
import SPFKBase
import SPFKTime
import SPFKUtils
import SwiftExtensions
import SwiftTimecode

/// Adobe's XMP Dynamic Media schema (`xmpDM`) -- markers, timecode, tracks, and the frame/sample
/// rates that give them meaning, plus a few `dc:`/`xmp:` fields that travel alongside.
///
/// Parses what this codebase actually consumes rather than the whole schema, and writes only the
/// editable fields in ``XMPDynamicMedia+Accessors``.
///
/// **Not the general XMP entry point**, despite once being named as though it were: descriptive
/// Dublin Core / IPTC metadata -- title, keywords, creator, rating, location -- is ``XMPMetadata``
/// in `spfk-metadata-image`, reached through `ImageXMP` or `VideoXMP`. This type is the technical,
/// time-based half of XMP; that one is the descriptive half. They share a namespace vocabulary and
/// nothing else.
public struct XMPDynamicMedia: Equatable, Sendable {
    public static func == (lhs: XMPDynamicMedia, rhs: XMPDynamicMedia) -> Bool {
        lhs.frameRate == rhs.frameRate && lhs.markers == rhs.markers && lhs.nominalFrameRate == rhs.nominalFrameRate
            && lhs.audioSampleRate == rhs.audioSampleRate && lhs.audioChannelType == rhs.audioChannelType
            && lhs.videoFrameSize == rhs.videoFrameSize && lhs.videoFieldOrder == rhs.videoFieldOrder
            && lhs.startTimecodeResolved == rhs.startTimecodeResolved && lhs.trackName == rhs.trackName
            && lhs.trackType == rhs.trackType && lhs.scene == rhs.scene && lhs.cameraAngle == rhs.cameraAngle
            && lhs.logComment == rhs.logComment && lhs.cameraModel == rhs.cameraModel
            && lhs.shotDate == rhs.shotDate && lhs.shotLocation == rhs.shotLocation
            && lhs.keywords == rhs.keywords
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
        startTimecodeResolved?.frameRate ?? estimatedFrameRate
    }

    public private(set) var markers: [XMPMarker]?

    /**
     <dc:subject>
         <rdf:Bag>
             <rdf:li>mountains</rdf:li>
             <rdf:li>california</rdf:li>
         </rdf:Bag>
     </dc:subject>
     */
    public private(set) var keywords: [String] = []

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

    /// Creates an empty `XMPDynamicMedia` with a minimal valid RDF/XMP document shell.
    ///
    /// Used when a file has no existing XMP packet but the user wants to set
    /// video-metadata fields (``scene``, ``cameraAngle``, etc.) for the first time.
    /// Declares only the `xmpDM` namespace, since that's the only one these
    /// editable fields write into.
    public init() {
        let doc = AEXMLDocument()
        let xmpmeta = doc.addChild(name: "x:xmpmeta", attributes: ["xmlns:x": "adobe:ns:meta/"])
        let rdf = xmpmeta.addChild(
            name: XMPElement.rdf.rawValue,
            attributes: ["xmlns:rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#"]
        )
        rdf.addChild(
            name: XMPElement.description.rawValue,
            attributes: [
                "rdf:about": "",
                "xmlns:xmpDM": "http://ns.adobe.com/xmp/1.0/DynamicMedia/",
            ]
        )
        self.init(document: doc)
    }

    /// Create a XMPDynamicMedia struct by passing it a URL to a file.
    ///
    /// Thread-safe — multiple instances can be created concurrently.
    /// - Parameter url: the file to open
    public init(url: URL) throws {
        let xmlString = try XMP.shared.parse(url: url)
        try self.init(xml: xmlString)
    }

    /// Create a XMPDynamicMedia struct by passing it a XMP xml string
    /// - Parameter xml: a valid xml string
    public init(xml: String) throws {
        let doc = try AEXMLDocument(xml: xml)
        self.init(document: doc)
    }

    /// All Inits resolve here.
    ///
    /// Create a XMPDynamicMedia struct by passing it a valid AEXMLDocument. This isn't an exhaustive parse, but
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

        if let items = desc[.subject]?[.bag]?[.li]?.all {
            keywords = items.compactMap(\.value)
        }

        creatorTool = desc.value(for: .creatorTool)
        createDate = desc.value(for: .createDate)

        // nominal frame rate as a Float
        if let value = desc.value(for: .videoFrameRate)?.float {
            nominalFrameRate = value
        }

        // start timecode
        if let element = desc[.startTimecode],
            let value = parseTimecode(element: element)
        {
            startTimecode = value
        }

        // A timecode set by the user. When specified, it is used instead of the startTimecode.
        if let element = desc[.altTimecode],
            let value = parseTimecode(element: element)
        {
            altTimecode = value
        }

        audioSampleRate = desc.value(for: .audioSampleRate)?.double
        audioChannelType = desc.value(for: .audioChannelType)
        videoFieldOrder = desc.value(for: .videoFieldOrder)

        if let frameSize = desc[.videoFrameSize],
            let width = frameSize.value(for: .dimensionsWidth)?.double,
            let height = frameSize.value(for: .dimensionsHeight)?.double
        {
            videoFrameSize = CGSize(width: width, height: height)
        }

        // tracks location might not be consistent so search for the first occurrence of it
        let trackList = desc.allDescendants { element in
            element.name == XMPElement.tracks.rawValue
        }

        // there can be more than one track
        if let track = trackList.first,
            let list = track[.bag]?[.li]
        {
            trackType = list.value(for: .trackType)
            trackName = list.value(for: .trackName)
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

        if let value = desc.value(for: .startTimeScale)?.int32 {
            startTimeScale = CMTimeScale(value)
        }

        if let value = desc.value(for: .startTimeSampleSize)?.int32 {
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
        guard let frameCount = element.value(for: .value)?.double,
            let scale = element.value(for: .scale),
            let frameDuration = CMTimeString.parse(string: scale)?.seconds
        else {
            return nil
        }

        return frameCount * frameDuration
    }

    private func parseTimecode(element: AEXMLElement) -> Timecode? {
        guard let value = element.value(for: .timeFormat),
            let timeFormat = FrameRate(rawValue: value),
            let timeValue = element.value(for: .timeValue)
        else {
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
            guard let mFrame = element.value(for: .startTime)?.int else { continue }

            let mName = element.value(for: .name) ?? ""
            let mDuration = element.value(for: .duration)?.int ?? 0
            let mComment = element.value(for: .comment) ?? ""

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
