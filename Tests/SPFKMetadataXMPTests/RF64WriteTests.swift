// Copyright Ryan Francesconi. All Rights Reserved.

import AudioToolbox
import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKMetadataXMP

/// RF64 is a `.wav` whose 32-bit RIFF size fields are `0xFFFFFFFF` sentinels, with the real 64-bit
/// sizes in a `ds64` chunk — what a wave file becomes past 4 GB, and what field recorders write for
/// long takes. A writer that recomputes a RIFF size into the sentinel makes readers fall back to
/// the 32-bit figure, which past 4 GB cannot describe the file.
///
/// The Adobe SDK handles this correctly and these tests exist to keep it that way across SDK
/// upgrades. Verified 2026-08-13 against a real 4.5 GB RF64 as well — same result, so the small
/// fixture here is sufficient.
@Suite(.tags(.file), .serialized)
final class RF64WriteTests: BinTestCase {
    private let packet = """
    <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
    <x:xmpmeta xmlns:x="adobe:ns:meta/">
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
    <xmp:CreatorTool>probe</xmp:CreatorTool>
    </rdf:Description>
    </rdf:RDF>
    </x:xmpmeta>
    <?xpacket end="w"?>
    """

    /// Bytes of audio Core Audio reports for the file, or nil if it cannot be opened. This is the
    /// assertion that matters: a damaged size field shows up here as a file that still opens
    /// cleanly and decodes to almost nothing.
    private func audioByteCount(of url: URL) -> Int64? {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file else {
            return nil
        }
        defer { AudioFileClose(file) }

        var bytes: Int64 = 0
        var size = UInt32(MemoryLayout<Int64>.size)

        guard AudioFileGetProperty(file, kAudioFilePropertyAudioDataByteCount, &size, &bytes) == noErr else {
            return nil
        }

        return bytes
    }

    private func fileTypeID(of url: URL) -> AudioFileTypeID? {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file else {
            return nil
        }
        defer { AudioFileClose(file) }

        var type: AudioFileTypeID = 0
        var size = UInt32(MemoryLayout<AudioFileTypeID>.size)

        guard AudioFileGetProperty(file, kAudioFilePropertyFileFormat, &size, &type) == noErr else {
            return nil
        }

        return type
    }

    /// Writes a one-second RF64 file.
    ///
    /// Core Audio's RF64 writer emits a plain `RIFF`/`WAVE` file with a 28-byte `JUNK` placeholder
    /// until the data actually crosses 4 GB, so the sentinels are filled in by hand here — the
    /// alternative is a 4 GB fixture per run. `JUNK` is exactly the size of `ds64` and sits at
    /// exactly its offset, so this is a substitution and every chunk offset is unchanged.
    private func makeRF64File(named name: String) throws -> URL {
        let url = bin.appendingPathComponent(name)

        var asbd = AudioStreamBasicDescription(
            mSampleRate: 48000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var file: ExtAudioFileRef?
        let status = ExtAudioFileCreateWithURL(
            url as CFURL,
            kAudioFileRF64Type,
            &asbd,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &file
        )

        try #require(status == noErr)
        let strongFile = try #require(file)

        let frames = 48000
        var samples = [Int16](repeating: 0, count: frames * 2)

        samples.withUnsafeMutableBytes { raw in
            var list = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 2,
                    mDataByteSize: UInt32(frames * 4),
                    mData: raw.baseAddress
                )
            )
            _ = ExtAudioFileWrite(strongFile, UInt32(frames), &list)
        }

        ExtAudioFileDispose(strongFile)

        var bytes = try [UInt8](Data(contentsOf: url))

        func u32(at offset: Int) -> UInt32 {
            var value: UInt32 = 0
            for i in stride(from: 3, through: 0, by: -1) {
                value = value << 8 | UInt32(bytes[offset + i])
            }
            return value
        }

        func write(_ value: UInt32, at offset: Int) {
            for i in 0 ..< 4 { bytes[offset + i] = UInt8((value >> (8 * UInt32(i))) & 0xFF) }
        }

        func write(_ value: UInt64, at offset: Int) {
            for i in 0 ..< 8 { bytes[offset + i] = UInt8((value >> (8 * UInt64(i))) & 0xFF) }
        }

        func chunkName(at offset: Int) -> String {
            String(bytes: bytes[offset ..< offset + 4], encoding: .ascii) ?? ""
        }

        var offset = 12
        var dataOffset: Int?

        while offset + 8 <= bytes.count {
            let size = Int(u32(at: offset + 4))

            if chunkName(at: offset) == "data" {
                dataOffset = offset
                break
            }

            offset += 8 + size + (size % 2)
        }

        let data = try #require(dataOffset)
        let dataSize = UInt64(u32(at: data + 4))

        try #require(chunkName(at: 12) == "JUNK")

        bytes.replaceSubrange(0 ..< 4, with: Array("RF64".utf8))
        write(UInt32(0xFFFF_FFFF), at: 4)
        bytes.replaceSubrange(12 ..< 16, with: Array("ds64".utf8))
        write(UInt32(28), at: 16)                    // ds64 chunk size
        write(UInt64(bytes.count - 8), at: 20)       // riffSize
        write(dataSize, at: 28)                      // dataSize
        write(dataSize / 4, at: 36)                  // sampleCount, in frames
        write(UInt32(0), at: 44)                     // table length
        write(UInt32(0xFFFF_FFFF), at: data + 4)     // data chunk sentinel

        try Data(bytes).write(to: url)

        return url
    }

    /// The fixture has to be a file Core Audio reads as RF64, or everything built on it proves
    /// nothing.
    @Test func syntheticFixtureIsRF64() throws {
        let url = try makeRF64File(named: "fixture.wav")

        #expect(fileTypeID(of: url) == kAudioFileRF64Type)
        #expect(audioByteCount(of: url) == 192_000)
    }

    @Test func writeKeepsTheAudioAndReadsBack() throws {
        let url = try makeRF64File(named: "write.wav")

        try XMP.write(string: packet, to: url)

        #expect(audioByteCount(of: url) == 192_000)
        #expect(try XMP.parse(url: url).contains("probe"))
    }

    @Test func setPropertyKeepsTheAudioAndReadsBack() throws {
        let url = try makeRF64File(named: "property.wav")

        try XMP.setProperty(
            namespace: "http://ns.adobe.com/xap/1.0/",
            name: "CreatorTool",
            value: "probe",
            url: url
        )

        #expect(audioByteCount(of: url) == 192_000)
        #expect(try XMP.parse(url: url).contains("probe"))
    }

    /// Reconciliation syncs XMP back into native RIFF chunks, so it is the write most likely to
    /// rewrite the container's size fields.
    @Test func writeReconciledKeepsTheAudioAndReadsBack() throws {
        let url = try makeRF64File(named: "reconciled.wav")

        try XMP.writeReconciled(string: packet, to: url)

        #expect(audioByteCount(of: url) == 192_000)
        #expect(try XMP.parse(url: url).contains("probe"))
    }
}
