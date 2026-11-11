import AEXML
import Foundation
@testable import SPFKMetadataXMP
import Testing

@Suite("XMPElement")
struct XMPElementTests {
    @Test("AEXMLElement subscript returns element when present")
    func subscriptPresent() throws {
        let xml = """
        <root>
            <xmpDM:name>TestName</xmpDM:name>
        </root>
        """
        let doc = try AEXMLDocument(xml: xml)
        let result = doc.root[XMPElement.name]
        #expect(result != nil)
        #expect(result?.value == "TestName")
    }

    @Test("AEXMLElement subscript returns nil when absent")
    func subscriptAbsent() throws {
        let xml = "<root><other>value</other></root>"
        let doc = try AEXMLDocument(xml: xml)
        let result = doc.root[XMPElement.name]
        #expect(result == nil)
    }
}
