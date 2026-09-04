// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation

/// What is known about writing XMP into a format with the toolkit.
///
/// Three-valued rather than a `Bool` because the two negatives are different answers and callers
/// act on them differently: a format with no handler cannot be attempted, while one nobody has
/// tried may well work.
public enum XMPWriteSupport: Sendable, Hashable {
    /// A write and read-back has been run against a real file of this format.
    case verified

    /// The toolkit ships no handler covering this format, so it cannot open the file at all.
    case unsupported

    /// Neither established.
    case unknown
}

public extension XMP {
    /// Extensions whose in-place XMP write has been verified by a round trip against a real file.
    ///
    /// Add one only once that round trip has been run. Unlike ImageIO's
    /// `CGImageDestinationCopyTypeIdentifiers()` the SDK exposes no queryable handler list, so
    /// there is nothing to ask at runtime -- and recognizing a format is not writing it: the
    /// binary's extension table lists `heic`/`heif`, which the toolkit cannot write.
    static let verifiedWritablePathExtensions: Set<String> = [
        // TIFF handler. Verified 2026-09-03 against a 4032x3024 iPhone DNG original: the file
        // stays a valid DNG and ImageIO reads the written `dc:subject` straight back. The other
        // TIFF-family raw formats (`cr2`, `nef`, `arw`) are deliberately absent -- untested.
        "dng",

        // MPEG-4 handler. Verified 2026-08-02 against a real iPhone .mov, all fourteen fields.
        "mov", "mp4", "m4v",
    ]

    /// Extensions no shipped handler covers, so `OpenFile` fails outright.
    ///
    /// Read from the symbol table of the vendored `XMPFiles` binary, which carries TIFF, JPEG,
    /// PNG, GIF, PSD, MPEG4, MPEG2, RIFF, WAVE, AIFF, MP3, ASF, SVG, FLV, SWF, PostScript,
    /// InDesign and the folder-based camera handlers -- and nothing for Matroska.
    static let unsupportedPathExtensions: Set<String> = ["mkv", "mka", "webm"]

    /// What is known about writing XMP into this file's format, from the path extension.
    ///
    /// Answered without opening the file, since it is asked per row and per field. It says which
    /// writer to try, not that the attempt will succeed -- a corrupt file still fails the write.
    static func writeSupport(for url: URL) -> XMPWriteSupport {
        let pathExtension = url.pathExtension.lowercased()

        if verifiedWritablePathExtensions.contains(pathExtension) { return .verified }
        if unsupportedPathExtensions.contains(pathExtension) { return .unsupported }

        return .unknown
    }
}
