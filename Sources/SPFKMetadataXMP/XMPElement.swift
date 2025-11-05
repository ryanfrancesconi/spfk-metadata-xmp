// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/SPFKMetadataXMP

import AEXML
import Foundation
import SPFKUtils

/// https://www.adobe.io/xmp/docs/XMPNamespaces/
/// https://www.w3.org/TR/rdf-syntax-grammar/
public enum XMPElement: String {
    /// Adobe XMP Basic namespace
    case creatorTool = "xmp:CreatorTool"
    case createDate = "xmp:CreateDate"

    /// <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    case rdf = "rdf:RDF"

    /// <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:stEvt="http://ns.adobe.com/xap/1.0/sType/ResourceEvent#" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/" xmlns:xmpMM="http://ns.adobe.com/xap/1.0/mm/" rdf:about="">
    case description = "rdf:Description"
    case bag = "rdf:Bag"
    case li = "rdf:li"
    case seq = "rdf:Seq"
    case alt = "rdf:Alt"

    /// XMP Dynamic Media namespace
    /// https://www.adobe.io/xmp/docs/XMPNamespaces/xmpDM/

    case audioChannelType = "xmpDM:audioChannelType"
    case audioSampleRate = "xmpDM:audioSampleRate"
    case videoFrameRate = "xmpDM:videoFrameRate"
    case videoFieldOrder = "xmpDM:videoFieldOrder"

    /// https://www.adobe.io/xmp/docs/XMPNamespaces/XMPDataTypes/Track/
    case tracks = "xmpDM:Tracks"

    /// https://developer.adobe.com/xmp/docs/XMPNamespaces/XMPDataTypes/Marker/
    case markers = "xmpDM:markers"
    case trackType = "xmpDM:trackType"
    case trackName = "xmpDM:trackName"

    case startTimecode = "xmpDM:startTimecode"
    case startTimeScale = "xmpDM:startTimeScale"
    case startTimeSampleSize = "xmpDM:startTimeSampleSize"
    case duration = "xmpDM:duration"

    /// A timecode set by the user. When specified, it is used instead of the startTimecode.
    case altTimecode = "xmpDM:altTimecode"

    // Timecode
    case timeFormat = "xmpDM:timeFormat"
    case timeValue = "xmpDM:timeValue"

    /*
     <xmpDM:duration rdf:parseType="Resource">
         <xmpDM:value>77077</xmpDM:value>
         <xmpDM:scale>1/24000</xmpDM:scale>
     </xmpDM:duration>

     https://www.adobe.io/xmp/docs/XMPNamespaces/XMPDataTypes/Time/
     */
    /// duration values
    case value = "xmpDM:value"
    case scale = "xmpDM:scale"

    /// Marker, Comment, Chapter
    case type = "xmpDM:type"
    case name = "xmpDM:name"
    case comment = "xmpDM:comment"
    case startTime = "xmpDM:startTime"

    /// DC
    case title = "dc:title"
}

extension AEXMLElement {
    public subscript(key: XMPElement) -> AEXMLElement? {
        let value = self[key.rawValue]
        guard value.error == nil else { return nil }
        return value
    }
}
