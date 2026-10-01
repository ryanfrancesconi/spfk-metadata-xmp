// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation

/// Which store owns the fields a container's XMP packet shares with its native metadata.
///
/// The toolkit reconciles the packet with native metadata on every format except ISO MPEG-4: a
/// read imports native values over the packet's, and a write exports the packet back, creating
/// and deleting chunks to match.
public enum XMPContainerPolicy: Sendable, Hashable {
    /// The native chunks own every mirrored field. The packet has to be stored without the
    /// toolkit, whose write re-encodes chunks it does not model (BEXT v2, iXML, ID3 frames).
    case nativeOwned

    /// The toolkit writes the packet, reconciling it with the native metadata in the same open.
    case reconciled

    /// No in-place writer: no handler, a sidecar written beside the file, or packet scanning that
    /// cannot place a new packet.
    case unsupported

    static let nativeOwnedPathExtensions: Set<String> = ["wav", "mp3"]

    static let reconciledPathExtensions: Set<String> = [
        "aif", "aiff", "aifc",
        "mp4", "m4a", "m4b", "m4v", "mov",
        "dng",
        "avi", "wmv",
    ]

    /// `mxf` despite the toolkit's P2, AVCHD and XDCAM handlers: those read a camera card's folder
    /// layout, not a standalone file. The MPEG-2 handler writes a `.xmp` sidecar, and AVCHD
    /// `.mts`/`.m2ts` fall through to packet scanning, which fails the write.
    static let unsupportedPathExtensions: Set<String> = [
        "mkv", "mka", "webm", "mxf",
        "mpg", "mpeg", "mp2", "m2v", "m2p", "m2t", "mod", "vob", "mpe",
        "mts", "m2ts",
    ]

    /// From the path extension; `nil` for a format with no established policy.
    public init?(url: URL) {
        let pathExtension = url.pathExtension.lowercased()

        if Self.nativeOwnedPathExtensions.contains(pathExtension) {
            self = .nativeOwned
        } else if Self.reconciledPathExtensions.contains(pathExtension) {
            self = .reconciled
        } else if Self.unsupportedPathExtensions.contains(pathExtension) {
            self = .unsupported
        } else {
            return nil
        }
    }
}
