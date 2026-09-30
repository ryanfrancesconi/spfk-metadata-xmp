import Foundation
import SPFKBase
@testable import SPFKMetadataXMP
import Testing

@Suite("XMPDynamicMedia editable video-metadata fields")
struct XMPMetadataAccessorTests {
    @Test("setting a field on a fresh empty document round-trips")
    func setOnEmptyDocumentRoundTrips() throws {
        var metadata = XMPDynamicMedia()
        metadata.scene = "INT. KITCHEN - DAY"

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == "INT. KITCHEN - DAY")
    }

    @Test("setting all six fields round-trips")
    func setAllFieldsRoundTrips() throws {
        var metadata = XMPDynamicMedia()
        metadata.scene = "Scene 4"
        metadata.cameraAngle = "Wide Shot"
        metadata.logComment = "Boom shadow in frame 120"
        metadata.cameraModel = "iPhone 15 Pro"
        metadata.shotDate = "2026-07-12"
        metadata.shotLocation = "37.7749,-122.4194"

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == "Scene 4")
        #expect(reparsed.cameraAngle == "Wide Shot")
        #expect(reparsed.logComment == "Boom shadow in frame 120")
        #expect(reparsed.cameraModel == "iPhone 15 Pro")
        #expect(reparsed.shotDate == "2026-07-12")
        #expect(reparsed.shotLocation == "37.7749,-122.4194")
    }

    @Test("setting a field preserves unrelated existing content")
    func setPreservesUnrelatedContent() throws {
        var metadata = try XMPDynamicMedia(xml: sample(named: "sample3.xml"))
        metadata.scene = "Scene 4"

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == "Scene 4")
        // sample3-specific content should survive the round-trip untouched.
        #expect(reparsed.creatorTool == "Adobe Premiere Pro 2022.0 (Macintosh)")
        #expect(reparsed.videoFrameSize == CGSize(width: 1920, height: 1080))
        #expect(reparsed.markers?.count == 4)
    }

    @Test("updating an existing field replaces rather than duplicates")
    func updatingExistingFieldReplaces() throws {
        var metadata = XMPDynamicMedia()
        metadata.scene = "First"
        metadata.scene = "Second"

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == "Second")
    }

    @Test("setting a field to nil removes it")
    func settingNilRemovesField() throws {
        var metadata = XMPDynamicMedia()
        metadata.scene = "Scene 4"
        metadata.scene = nil

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == nil)
    }

    @Test("setting a field to empty string removes it")
    func settingEmptyStringRemovesField() throws {
        var metadata = XMPDynamicMedia()
        metadata.scene = "Scene 4"
        metadata.scene = ""

        let reparsed = try XMPDynamicMedia(xml: metadata.xml)
        #expect(reparsed.scene == nil)
    }

    // MARK: - A field stored as an attribute

    private static let attributeFormPacket = """
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
     <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description rdf:about="" xmlns:xmpDM="http://ns.adobe.com/xmp/1.0/DynamicMedia/" xmpDM:scene="A"/>
     </rdf:RDF>
    </x:xmpmeta>
    """

    /// Element and attribute forms, each counted once.
    private static func sceneOccurrences(in xml: String) -> Int {
        (xml.components(separatedBy: "<xmpDM:scene").count - 1) + (xml.components(separatedBy: "xmpDM:scene=").count - 1)
    }

    @Test("clearing a field stored as an attribute removes it")
    func clearingAnAttributeFormFieldRemovesIt() throws {
        var metadata = try XMPDynamicMedia(xml: Self.attributeFormPacket)
        try #require(metadata.scene == "A")

        metadata.scene = nil

        #expect(metadata.scene == nil)
        #expect(Self.sceneOccurrences(in: metadata.xml) == 0)
    }

    @Test("editing a field stored as an attribute leaves one copy")
    func editingAnAttributeFormFieldLeavesOneCopy() throws {
        var metadata = try XMPDynamicMedia(xml: Self.attributeFormPacket)
        try #require(metadata.scene == "A")

        metadata.scene = "B"

        #expect(metadata.scene == "B")
        #expect(Self.sceneOccurrences(in: metadata.xml) == 1, "\(metadata.xml)")
    }
}
