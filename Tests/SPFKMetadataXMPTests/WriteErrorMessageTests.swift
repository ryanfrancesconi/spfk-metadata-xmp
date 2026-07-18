import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// Verifies write failures surface a real, failure-specific reason in the thrown error's
/// description — not the fixed generic string every write function used to produce
/// regardless of cause. A nonexistent file path is used as a deterministic failure
/// trigger (reliably hits the "failed to open" branch in every write function, without
/// depending on any Adobe XMP SDK-internal error semantics).
@Suite(.serialized)
class WriteErrorMessageTests: BinTestCase {
    let xmp = XMP.shared

    private func nonexistentURL() -> URL {
        bin.appendingPathComponent("does-not-exist-\(UUID().uuidString).wav")
    }

    /// Covers the blind-overwrite path (`writeXMP` in `XMPUtil.cpp`).
    @Test func writeToNonexistentFileIncludesRealFailureReason() async throws {
        deleteBinOnExit = true
        let url = nonexistentURL()
        let string = try sample(named: "sample1.xml")

        do {
            try xmp.write(string: string, to: url)
            Issue.record("Expected write(string:to:) to throw for a nonexistent file")
        } catch {
            let description = (error as NSError).localizedDescription
            #expect(description.contains(url.path), "Error should mention the target path: \(description)")
            #expect(
                description.contains("Failed to open file"),
                "Error should include the specific failure reason, not just the generic wrapper: \(description)"
            )
        }
    }

    /// Covers the load-then-mutate-then-put path (`setXMPProperty` in `XMPUtil.cpp`) —
    /// a structurally distinct function from `writeXMP`, so this confirms the fix was
    /// applied uniformly, not just to the blind-overwrite functions.
    @Test func setPropertyOnNonexistentFileIncludesRealFailureReason() async throws {
        deleteBinOnExit = true
        let url = nonexistentURL()

        do {
            try xmp.setProperty(
                namespace: "http://ns.adobe.com/xmp/1.0/DynamicMedia/",
                name: "scene",
                value: "interior-day",
                url: url
            )
            Issue.record("Expected setProperty(...) to throw for a nonexistent file")
        } catch {
            let description = (error as NSError).localizedDescription
            #expect(description.contains(url.path), "Error should mention the target path: \(description)")
            #expect(
                description.contains("Failed to open file"),
                "Error should include the specific failure reason, not just the generic wrapper: \(description)"
            )
        }
    }
}
