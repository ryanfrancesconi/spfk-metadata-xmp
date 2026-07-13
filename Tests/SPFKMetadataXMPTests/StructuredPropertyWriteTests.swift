import AEXML
import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Verifies `XMP.setProperty`/`setArrayProperty`/`setProperties` use the
/// load-then-mutate-then-put pattern (preserving unrelated existing content),
/// unlike `write(string:to:)`'s whole-packet overwrite.
@Suite(.serialized)
class StructuredPropertyWriteTests: BinTestCase {
    let xmp = XMP.shared

    let xmpDMNamespace = "http://ns.adobe.com/xmp/1.0/DynamicMedia/"
    let dcNamespace = "http://purl.org/dc/elements/1.1/"

    /// Copies `cowbell_wav` into `bin` and seeds it with `sample1.xml`'s multi-property
    /// packet (xmpDM:startTimeScale, xmpMM:InstanceID, xmp:ModifyDate, etc.) so tests have
    /// real pre-existing, unrelated content to verify survives a structured write.
    private func seededFile() async throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)
        let string = try sample(named: "sample1.xml")
        try xmp.write(string: string, to: url)
        return url
    }

    // MARK: - Phase 1: simple-value write

    @Test func setPropertyRoundTrips() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setProperty(namespace: xmpDMNamespace, name: "scene", value: "interior-day", url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("interior-day"))
    }

    /// The test that actually matters: confirms setProperty does NOT blind-overwrite —
    /// pre-existing, unrelated properties from sample1.xml must survive.
    @Test func setPropertyPreservesUnrelatedContent() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        let before = try xmp.parse(url: url)
        #expect(before.contains("60000")) // xmpDM:startTimeScale
        #expect(before.contains("xmp.iid:c74f1ed7-7900-4a34-9586-c5f82754b692")) // xmpMM:InstanceID

        try xmp.setProperty(namespace: xmpDMNamespace, name: "scene", value: "interior-day", url: url)

        let after = try xmp.parse(url: url)
        #expect(after.contains("interior-day"))
        #expect(after.contains("60000"), "xmpDM:startTimeScale should survive an unrelated property write")
        #expect(
            after.contains("xmp.iid:c74f1ed7-7900-4a34-9586-c5f82754b692"),
            "xmpMM:InstanceID should survive an unrelated property write"
        )
    }

    @Test func setPropertyOnFileWithNoExistingXMPSucceeds() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        try xmp.setProperty(namespace: xmpDMNamespace, name: "scene", value: "interior-day", url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("interior-day"))
    }

    // MARK: - Phase 2: array-value write

    @Test func setArrayPropertyRoundTrips() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setArrayProperty(namespace: dcNamespace, name: "subject", values: ["drums", "percussion", "loop"], url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("drums"))
        #expect(xml.contains("percussion"))
        #expect(xml.contains("loop"))
    }

    @Test func setArrayPropertyPreservesUnrelatedContent() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setArrayProperty(namespace: dcNamespace, name: "subject", values: ["drums", "percussion"], url: url)

        let after = try xmp.parse(url: url)
        #expect(after.contains("60000"), "xmpDM:startTimeScale should survive an array property write")
    }

    /// Replace semantics: writing a new, shorter array must remove the old items,
    /// not just overwrite the first N and leave stragglers behind.
    @Test func setArrayPropertyReplacesRatherThanAppends() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setArrayProperty(namespace: dcNamespace, name: "subject", values: ["one", "two", "three"], url: url)
        try xmp.setArrayProperty(namespace: dcNamespace, name: "subject", values: ["only"], url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("only"))
        #expect(!xml.contains("two"))
        #expect(!xml.contains("three"))
    }

    // MARK: - Phase 3: batch write

    @Test func setPropertiesBatchAppliesAllValues() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setProperties(
            [
                .simple(namespace: xmpDMNamespace, name: "scene", value: "interior-day"),
                .simple(namespace: xmpDMNamespace, name: "cameraAngle", value: "wide"),
                .array(namespace: dcNamespace, name: "subject", values: ["drums", "loop"]),
            ],
            url: url
        )

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("interior-day"))
        #expect(xml.contains("wide"))
        #expect(xml.contains("drums"))
        #expect(xml.contains("loop"))
    }

    @Test func setPropertiesBatchPreservesUnrelatedContent() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setProperties(
            [
                .simple(namespace: xmpDMNamespace, name: "scene", value: "interior-day"),
                .array(namespace: dcNamespace, name: "subject", values: ["drums"]),
            ],
            url: url
        )

        let after = try xmp.parse(url: url)
        #expect(after.contains("60000"), "xmpDM:startTimeScale should survive a batch write")
        #expect(
            after.contains("xmp.iid:c74f1ed7-7900-4a34-9586-c5f82754b692"),
            "xmpMM:InstanceID should survive a batch write"
        )
    }

    // MARK: - Phase 3: xmpDM simple-value fields (frame rate)

    /// Confirms frameRate — genuinely a simple top-level value, unlike timecode/trackInfo —
    /// round-trips through the existing Phase 1 setProperty API with no new capability needed.
    @Test func setPropertyWritesFrameRate() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setProperty(namespace: xmpDMNamespace, name: "videoFrameRate", value: "29.970000", url: url)

        let metadata = try XMPMetadata(url: url)
        #expect(metadata.nominalFrameRate == 29.97)
    }

    // MARK: - Struct-field compound path (timecode)

    /// Verifies a nested struct field (not a simple value) is writable through the existing
    /// setProperty API via a compound path, with no new C++/Swift API needed for this case.
    @Test func setPropertyWritesNestedStructField() async throws {
        deleteBinOnExit = true
        let url = try await seededFile() // sample1.xml already has a startTimecode struct

        try xmp.setProperty(
            namespace: xmpDMNamespace,
            name: "startTimecode/xmpDM:timeFormat",
            value: "24Timecode",
            url: url
        )

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("24Timecode"))
        // Sibling field within the same struct should be untouched.
        #expect(xml.contains("00;00;00;00"), "startTimecode's timeValue should survive a sibling field write")
    }

    // MARK: - Track info (array-of-struct)

    @Test func setTrackInfoCreatesTracksBagWhenNoneExists() async throws {
        deleteBinOnExit = true
        let url = try await seededFile() // sample1.xml has no xmpDM:Tracks at all

        try xmp.setTrackInfo(trackType: "Video", trackName: "Camera 1", url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("Video"))
        #expect(xml.contains("Camera 1"))
    }

    @Test func setTrackInfoPreservesUnrelatedContent() async throws {
        deleteBinOnExit = true
        let url = try await seededFile()

        try xmp.setTrackInfo(trackType: "Video", trackName: "Camera 1", url: url)

        let after = try xmp.parse(url: url)
        #expect(after.contains("60000"), "xmpDM:startTimeScale should survive a track-info write")
    }

    @Test func setTrackInfoUpdatesExistingTrack() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)
        let string = try sample(named: "sample3.xml") // sample3.xml already has a Tracks bag
        try xmp.write(string: string, to: url)

        try xmp.setTrackInfo(trackType: "Video", trackName: "Renamed Track", url: url)

        let xml = try xmp.parse(url: url)
        #expect(xml.contains("Renamed Track"))
    }

    /// A nil field should leave the existing value untouched, not clear it.
    @Test func setTrackInfoNilFieldLeavesExistingValueUnchanged() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)
        let string = try sample(named: "sample3.xml")
        try xmp.write(string: string, to: url)

        let originalTrackType = try XMPMetadata(xml: string).trackType

        try xmp.setTrackInfo(trackType: nil, trackName: "Renamed Track", url: url)

        let after = try XMPMetadata(url: url)
        #expect(after.trackName == "Renamed Track")
        #expect(after.trackType == originalTrackType, "trackType should be unchanged when nil is passed")
    }
}
