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

    /// Round-tripped by `FileTests.concurrentWrite`, which writes and reads back a title on each.
    @Test func audioFormatsThisPackageRoundTripsAreVerifiedWritable() {
        for pathExtension in ["aif", "m4a", "mp3", "wav"] {
            #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.\(pathExtension)")) == .verified, "\(pathExtension)")
        }
    }

    /// The opposite direction, and the reason this is not derived from "is this a movie": the
    /// vendored XMPFiles binary carries no Matroska handler, so the file cannot be opened at all.
    @Test func matroskaIsUnsupported() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mkv")) == .unsupported)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.webm")) == .unsupported)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.mka")) == .unsupported)
    }

    @Test func aviAndWindowsMediaAreVerifiedWritable() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.avi")) == .verified)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.wmv")) == .verified)
    }

    /// The MPEG-2 handler writes a sidecar rather than into the file, and AVCHD streams have no
    /// handler registered, so the write fails after the edit was offered.
    @Test func mpeg2AndAVCHDAreUnsupported() {
        for pathExtension in ["mpg", "mpeg", "vob", "m2v", "mts", "m2ts"] {
            #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.\(pathExtension)")) == .unsupported, "\(pathExtension)")
        }
    }

    /// The third answer, and the one a `Bool` cannot express. The binary ships an FLV handler, but
    /// no round trip has been run, and calling that `false` alongside Matroska's `false` is what
    /// would make one caller wrong.
    @Test func anUntestedFormatIsUnknownRatherThanEither() {
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.flv")) == .unknown)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a.bin")) == .unknown)
        #expect(XMP.writeSupport(for: URL(fileURLWithPath: "/tmp/a")) == .unknown)
    }
}

/// Which store owns a container's mirrored fields.
@Suite
struct ContainerPolicyTests {
    @Test func waveAndMP3AreNativeOwned() {
        #expect(XMPContainerPolicy(url: URL(fileURLWithPath: "/tmp/a.wav")) == .nativeOwned)
        #expect(XMPContainerPolicy(url: URL(fileURLWithPath: "/tmp/a.MP3")) == .nativeOwned)
    }

    @Test func toolkitWrittenFormatsAreReconciled() {
        for pathExtension in ["aif", "aifc", "m4a", "mov", "mp4", "dng", "avi", "wmv"] {
            #expect(XMPContainerPolicy(url: URL(fileURLWithPath: "/tmp/a.\(pathExtension)")) == .reconciled, "\(pathExtension)")
        }
    }

    @Test func aFormatWithNoPolicyIsNil() {
        #expect(XMPContainerPolicy(url: URL(fileURLWithPath: "/tmp/a.flv")) == nil)
        #expect(XMPContainerPolicy(url: URL(fileURLWithPath: "/tmp/a")) == nil)
    }
}
