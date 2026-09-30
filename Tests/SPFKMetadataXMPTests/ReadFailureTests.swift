// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// A file with no XMP and a file that can't be read are different answers: a caller about to
/// write treats the first as empty and must not treat the second that way.
@Suite
class ReadFailureTests: BinTestCase {
    @Test func aFileWithoutXMPThrowsNoPacket() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.mp3_no_metadata)

        #expect(throws: XMPReadError.noPacket) {
            try XMP.parse(url: url)
        }
    }

    @Test func anUnreadableFileThrowsReadFailed() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.mp3_id3)

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }

        let error = #expect(throws: XMPReadError.self) {
            try XMP.parse(url: url)
        }

        guard case .readFailed = error else {
            Issue.record("Expected readFailed, got \(String(describing: error))")
            return
        }
    }
}
