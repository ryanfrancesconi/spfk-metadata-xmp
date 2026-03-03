import AEXML
import Foundation
@testable import SPFKMetadataXMP
import Testing

@Suite("XMPElement")
struct XMPElementTests {
    @Test("raw values match XMP namespace prefixes")
    func rawValues() {
        #expect(XMPElement.rdf.rawValue == "rdf:RDF")
        #expect(XMPElement.description.rawValue == "rdf:Description")
        #expect(XMPElement.bag.rawValue == "rdf:Bag")
        #expect(XMPElement.li.rawValue == "rdf:li")
        #expect(XMPElement.seq.rawValue == "rdf:Seq")
        #expect(XMPElement.alt.rawValue == "rdf:Alt")
        #expect(XMPElement.tracks.rawValue == "xmpDM:Tracks")
        #expect(XMPElement.markers.rawValue == "xmpDM:markers")
        #expect(XMPElement.startTime.rawValue == "xmpDM:startTime")
        #expect(XMPElement.name.rawValue == "xmpDM:name")
        #expect(XMPElement.title.rawValue == "dc:title")
        #expect(XMPElement.creatorTool.rawValue == "xmp:CreatorTool")
    }

    @Test("AEXMLElement subscript returns element when present")
    func subscriptPresent() throws {
        let xml = """
        <root>
            <xmpDM:name>TestName</xmpDM:name>
        </root>
        """
        let doc = try AEXMLDocument(xml: xml)
        let result = doc.root[.name]
        #expect(result != nil)
        #expect(result?.value == "TestName")
    }

    @Test("AEXMLElement subscript returns nil when absent")
    func subscriptAbsent() throws {
        let xml = "<root><other>value</other></root>"
        let doc = try AEXMLDocument(xml: xml)
        let result = doc.root[.name]
        #expect(result == nil)
    }
}
