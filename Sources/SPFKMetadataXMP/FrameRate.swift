// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import SwiftTimecode

// swiftformat:disable consecutiveSpaces

extension XMPMetadata {
    /**
     https://www.adobe.io/xmp/docs/XMPNamespaces/XMPDataTypes/Timecode/

     These are the frame rates that Premiere supports with their values.

     <xmpDM:startTimecode rdf:parseType="Resource">
         <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat>
         <xmpDM:timeValue>00:00:00:00</xmpDM:timeValue>
     </xmpDM:startTimecode>
     */
    public enum FrameRate: String, Sendable {
        case fps23_976 =    "23976Timecode"
        case fps24 =        "24Timecode"
        case fps25 =        "25Timecode"
        case fps29_97 =     "2997NonDropTimecode"
        case fps29_97d =    "2997DropTimecode"
        case fps30 =        "30Timecode"
        case fps50 =        "50Timecode"
        case fps59_94 =     "5994NonDropTimecode"
        case fps59_94d =    "5994DropTimecode"
        case fps60 =        "60Timecode"

        /// Return a TimecodeFrameRate based on the value
        public var frameRate: TimecodeFrameRate {
            switch self {
            case .fps23_976:    .fps23_976
            case .fps24:        .fps24
            case .fps25:        .fps25
            case .fps29_97:     .fps29_97
            case .fps29_97d:    .fps29_97d
            case .fps30:        .fps30
            case .fps50:        .fps50
            case .fps59_94:     .fps59_94
            case .fps59_94d:    .fps59_94d
            case .fps60:        .fps60
            }
        }
    }
}

// swiftformat:enable consecutiveSpaces
