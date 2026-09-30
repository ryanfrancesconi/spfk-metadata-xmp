// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// The toolkit's parser accepts text that is not XMP and returns an empty tree without an error.
/// Written whole, that tree replaces the file's packet -- and on a WAV, the BEXT and INFO chunks
/// the packet mirrors.
@Suite
class WritePacketValidationTests: BinTestCase {
    @Test(arguments: ["", "not xml at all", "<a>unterminated", "<a>well-formed</a>"])
    func aPacketWithNoPropertiesIsRefusedAndTheFileIsUntouched(packet: String) async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.wav_bext_v2)
        let before = try Data(contentsOf: url)

        #expect(throws: (any Error).self) {
            try XMP.write(string: packet, to: url)
        }

        #expect(try Data(contentsOf: url) == before)
    }
}
