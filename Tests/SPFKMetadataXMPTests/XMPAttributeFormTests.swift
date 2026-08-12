// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SwiftTimecode
import Testing

@testable import SPFKMetadataXMP

/// RDF lets a structured property put its fields in child elements or in attributes of the same
/// qualified name, and both appear in the wild: Premiere writes children, QuickTime-authored files
/// write attributes. Reading only children drops the attribute form silently — every value comes
/// back `nil` with no parse error to notice.
@Suite
final class XMPAttributeFormTests {
    private func document(body: String) -> String {
        """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
           xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/"
           \(body)
         </rdf:RDF>
        </x:xmpmeta>
        """
    }

    // MARK: - Timecode

    @Test func timecodeParsesFromChildElements() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
        >
           <xmpDM:startTimecode rdf:parseType="Resource">
            <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat>
            <xmpDM:timeValue>01:00:00:00</xmpDM:timeValue>
           </xmpDM:startTimecode>
          </rdf:Description>
        """))

        let start = try #require(xmp.startTimecodeResolved)
        #expect(start.frameRate == .fps25)
        #expect(start.stringValue() == "01:00:00:00")
    }

    @Test func timecodeParsesFromAttributes() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
        >
           <xmpDM:startTimecode
            xmpDM:timeValue="01;00;00;01"
            xmpDM:timeFormat="5994DropTimecode"/>
          </rdf:Description>
        """))

        let start = try #require(xmp.startTimecodeResolved)
        #expect(start.frameRate == .fps59_94d)
        #expect(start.stringValue() == "01:00:00;01")
    }

    /// The two carriers can name different positions, and the spec says the user-set one wins. The
    /// attribute-form file this was measured against relies on it: its `startTimecode` is
    /// `00;00;00;00` while the position it actually starts at sits in `altTimecode`.
    @Test func altTimecodeWinsInAttributeForm() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
        >
           <xmpDM:altTimecode
            xmpDM:timeValue="01;00;00;01"
            xmpDM:timeFormat="5994DropTimecode"/>
           <xmpDM:startTimecode
            xmpDM:timeValue="00;00;00;00"
            xmpDM:timeFormat="5994DropTimecode"/>
          </rdf:Description>
        """))

        #expect(xmp.startTimecodeResolved?.stringValue() == "01:00:00;01")
    }

    /// Drop is a property of the declared `timeFormat`, not something inferred from the separator,
    /// so it survives a carrier that spells the value with colons.
    @Test func dropFlagComesFromTimeFormat() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
        >
           <xmpDM:startTimecode
            xmpDM:timeValue="00;00;10;00"
            xmpDM:timeFormat="2997DropTimecode"/>
          </rdf:Description>
        """))

        #expect(xmp.startTimecodeResolved?.frameRate == .fps29_97d)
        #expect(xmp.frameRate == .fps29_97d)
    }

    // MARK: - Other structured and flat properties

    /// `duration` is the same shape as `startTimecode` and was missed the same way.
    @Test func durationParsesFromAttributes() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
        >
           <xmpDM:duration
            xmpDM:value="1799798"
            xmpDM:scale="1/60000"/>
          </rdf:Description>
        """))

        let duration = try #require(xmp.duration)
        #expect(abs(duration - 1799798.0 / 60000.0) < 0.001)
    }

    @Test func flatPropertiesParseFromAttributes() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
           xmpDM:startTimeScale="60000"
           xmpDM:startTimeSampleSize="1001"
           xmpDM:videoFrameRate="59.940060"
           xmpDM:audioSampleRate="48000"/>
        """))

        #expect(xmp.startTimeScale == 60000)
        #expect(xmp.startTimeSampleSize == 1001)
        #expect(xmp.audioSampleRate == 48000)
        #expect(xmp.nominalFrameRate == 59.94006)
    }

    /// A child element and an attribute of the same name should not both be consulted in a way that
    /// lets the attribute shadow real content.
    @Test func childElementWinsOverAttributeOfSameName() throws {
        let xmp = try XMPDynamicMedia(xml: document(body: """
           xmpDM:audioChannelType="Mono">
           <xmpDM:audioChannelType>Stereo</xmpDM:audioChannelType>
          </rdf:Description>
        """))

        #expect(xmp.audioChannelType == "Stereo")
    }
}
