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
}
