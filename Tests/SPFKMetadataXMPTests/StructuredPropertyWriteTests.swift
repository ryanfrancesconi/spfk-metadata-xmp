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
}
