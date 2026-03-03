import AEXML
import Foundation
@testable import SPFKMetadataXMP
import SwiftTimecode
import Testing

@Suite("XMPMetadata Edge Cases")
struct XMPMetadataEdgeCaseTests {
    // MARK: - Invalid / minimal XML

    @Test("invalid XML throws")
    func invalidXML() {
        #expect(throws: (any Error).self) {
            _ = try XMPMetadata(xml: "not valid xml at all")
        }
    }

    @Test("empty RDF description results in nil properties")
    func emptyDescription() throws {
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description rdf:about="" />
            </rdf:RDF>
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)

        #expect(xmp.title == nil)
        #expect(xmp.creatorTool == nil)
        #expect(xmp.createDate == nil)
        #expect(xmp.nominalFrameRate == nil)
        #expect(xmp.audioSampleRate == nil)
        #expect(xmp.audioChannelType == nil)
        #expect(xmp.videoFieldOrder == nil)
        #expect(xmp.startTimecode == nil)
        #expect(xmp.altTimecode == nil)
        #expect(xmp.frameRate == nil)
        #expect(xmp.duration == nil)
        #expect(xmp.markers?.isEmpty == true)
    }

    @Test("missing RDF element results in nil properties")
    func missingRDF() throws {
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)

        #expect(xmp.title == nil)
        #expect(xmp.frameRate == nil)
        #expect(xmp.markers == nil)
    }

    // MARK: - startTimecodeResolved logic

    @Test("startTimecodeResolved prefers altTimecode over startTimecode")
    func resolvedPrefersAlt() throws {
        let xmp = try XMPMetadata(xml: sample(named: "sample1.xml"))

        // sample1 has different alt and start timecodes
        #expect(xmp.altTimecode != nil)
        #expect(xmp.startTimecode != nil)
        #expect(xmp.altTimecode != xmp.startTimecode)
        #expect(xmp.startTimecodeResolved == xmp.altTimecode)
    }

    @Test("startTimecodeResolved falls back to startTimecode when no alt")
    func resolvedFallsBackToStart() throws {
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/" rdf:about="">
                    <xmpDM:startTimecode rdf:parseType="Resource">
                        <xmpDM:timeFormat>25Timecode</xmpDM:timeFormat>
                        <xmpDM:timeValue>01:00:00:00</xmpDM:timeValue>
                    </xmpDM:startTimecode>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)

        #expect(xmp.altTimecode == nil)
        #expect(xmp.startTimecode?.stringValue() == "01:00:00:00")
        #expect(xmp.startTimecodeResolved == xmp.startTimecode)
    }

    // MARK: - Equatable

    @Test("Equatable compares key properties")
    func equatable() throws {
        let xmp1 = try XMPMetadata(xml: sample(named: "sample3.xml"))
        let xmp2 = try XMPMetadata(xml: sample(named: "sample3.xml"))

        #expect(xmp1 == xmp2)
    }

    @Test("Equatable detects different content")
    func equalableDifferent() throws {
        let xmp1 = try XMPMetadata(xml: sample(named: "sample3.xml"))
        let xmp2 = try XMPMetadata(xml: sample(named: "sample7.xml"))

        #expect(xmp1 != xmp2)
    }

    // MARK: - estimatedFrameRate from nominalFrameRate

    @Test("frameRate derived from nominalFrameRate when no timecode")
    func estimatedFrameRate() throws {
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/" rdf:about="">
                    <xmpDM:videoFrameRate>25.000000</xmpDM:videoFrameRate>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)

        #expect(xmp.startTimecode == nil)
        #expect(xmp.nominalFrameRate == 25.0)
        #expect(xmp.frameRate == .fps25)
    }

    // MARK: - Markers without frame rate

    @Test("markers are nil when no frame rate available")
    func markersWithoutFrameRate() throws {
        // Construct XML with markers but no timecode or videoFrameRate
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/" rdf:about="">
                    <xmpDM:Tracks>
                        <rdf:Bag>
                            <rdf:li rdf:parseType="Resource">
                                <xmpDM:markers>
                                    <rdf:Seq>
                                        <rdf:li rdf:parseType="Resource">
                                            <xmpDM:startTime>0</xmpDM:startTime>
                                            <xmpDM:name>Test</xmpDM:name>
                                        </rdf:li>
                                    </rdf:Seq>
                                </xmpDM:markers>
                            </rdf:li>
                        </rdf:Bag>
                    </xmpDM:Tracks>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)

        #expect(xmp.frameRate == nil)
        // Markers should be empty since parseMarkers returns nil without frameRate
        #expect(xmp.markers?.isEmpty == true)
    }

    // MARK: - Title parsing

    @Test("title parsed from dc:title > rdf:Alt > rdf:li")
    func titleParsing() throws {
        let xml = """
        <?xml version="1.0"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                <rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/" rdf:about="">
                    <dc:title>
                        <rdf:Alt>
                            <rdf:li xml:lang="x-default">My Title</rdf:li>
                        </rdf:Alt>
                    </dc:title>
                </rdf:Description>
            </rdf:RDF>
        </x:xmpmeta>
        """
        let xmp = try XMPMetadata(xml: xml)
        #expect(xmp.title == "My Title")
    }
}
