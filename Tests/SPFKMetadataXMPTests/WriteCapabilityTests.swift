import Foundation
import SPFKMetadataXMP
import Testing

/// Which formats the toolkit is known to write, and the distinction ``XMPWriteSupport`` exists to
/// keep: a format nobody has tried is not a format with no handler, and a caller treats the two
/// differently.
@Suite
struct WriteCapabilityTests {
    /// The live bug this answers. ImageIO reads DNG and has no encoder for it, so routing on
    /// ImageIO's answer alone made every RAW file read-only.
    @Test func dngIsVerifiedWritable() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.dng")) == .verified)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.DNG")) == .verified)
    }

    @Test func quickTimeFamilyIsVerifiedWritable() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mov")) == .verified)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mp4")) == .verified)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.m4v")) == .verified)
    }

    /// The opposite direction, and the reason this is not derived from "is this a movie": the
    /// vendored XMPFiles binary carries no Matroska handler, so the file cannot be opened at all.
    @Test func matroskaIsUnsupported() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mkv")) == .unsupported)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.webm")) == .unsupported)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mka")) == .unsupported)
    }

    /// The third answer, and the one a `Bool` cannot express. A handler for these probably exists
    /// -- the binary ships RIFF and MPEG2 handlers -- but no round trip has been run, and calling
    /// that `false` alongside Matroska's `false` is what would make one caller wrong.
    @Test func anUntestedFormatIsUnknownRatherThanEither() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.avi")) == .unknown)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.bin")) == .unknown)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a")) == .unknown)
    }
}
