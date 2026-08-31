# SPFKMetadataXMP

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata-xmp)](https://github.com/ryanfrancesconi/spfk-metadata-xmp/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)

A Swift package for reading and writing [Adobe XMP](https://developer.adobe.com/xmp/docs/) metadata embedded in audio and video files on macOS. Built on top of the Adobe XMP SDK (via bundled `XMPCore` and `XMPFiles` binary frameworks) with a Swift-native API layer.

## Overview

Three main pieces:

- **`XMP`** — A thread-safe `actor` singleton for reading and writing raw XMP XML strings, and for reading and writing individual properties in a batch. Manages the Adobe XMP SDK lifecycle; its file I/O is `nonisolated`, so concurrent file operations do not serialize on the actor.
- **`XMPDynamicMedia`** — A `Sendable` struct parsing XMP XML into strongly-typed properties focused on timecode, markers and media metadata.
- **`VideoXMP`** — Reading, writing and clearing the descriptive fields of a QuickTime container.

### Supported File Formats

The XMP SDK supports reading and writing metadata for common media containers including AIF, M4A, MP3, MP4, and WAV. Raw AAC containers are read-only (no XMP write support).

## Key Types

### XMP

Singleton actor wrapping the Adobe XMP C++ SDK, handling SDK initialization through mutex-protected
C++ lifecycle management. `parse`, `write` and the batch property calls are `nonisolated` — they
bypass the actor's serial executor because the underlying C++ uses stack-local `SXMPFiles` /
`SXMPMeta` instances with no shared state, so several files can be read or written in parallel.

### XMPDynamicMedia

Parses XMP XML into structured properties — title, frame rate, resolved start timecode, markers,
duration, sample rate, channel and field configuration, creator tool and create date. Initializable
from a file URL, an XML string, or a parsed document.

### XMPMarker

One marker from the XMP `xmpDM:Tracks` data, carrying both frame-based and time-based positioning
and converting between them from its frame rate.

### VideoXMP

The video half: fourteen fields written into a QuickTime container through the toolkit, verified
against a real 4K iPhone `.mov` — all of them write, read back and clear, with the file's QuickTime
user data, duration and track count preserved, in single-digit milliseconds. The toolkit appends an
XMP atom rather than rewriting the container.

It lives here rather than in a product package so ShadowTag inherits it: video capability is the one
direction that flows TorchTag → ShadowTag. ShadowTag writes video metadata through TagLib today,
which reaches 4 of these 14 fields and cannot express keywords at all.

### XMPPropertyRead / XMPPropertyWrite

One property to read, or to write or remove, in a batch call — so a caller touching several fields
opens the file once instead of once per field.

### FrameRate

Maps XMP timecode format strings (e.g. `"25Timecode"`, `"2997DropTimecode"`) to `TimecodeFrameRate` values. Supports 23.976, 24, 25, 29.97 (drop and non-drop), 30, 50, 59.94 (drop and non-drop), and 60 fps.

### XMPElement

A `String`-backed enum representing XMP namespace elements (`rdf:RDF`, `xmpDM:Tracks`, `dc:title`, etc.) with a type-safe `AEXMLElement` subscript for XML traversal.

## Thread Safety

The package is designed for concurrent use across multiple files:

- **SDK initialization** (`SXMPMeta::Initialize`, `SXMPFiles::Initialize`) is protected by a `std::mutex` in the C++ layer, ensuring safe one-time setup even under concurrent access.
- **`parse()` and `write()` are `nonisolated`** on the `XMP` actor. Each call creates stack-local `SXMPFiles` and `SXMPMeta` C++ objects with no shared mutable state, so multiple files can be read or written in parallel.
- **`XMPDynamicMedia` is `Sendable`** — all properties are value types, immutable after initialization. Instances can be safely passed across concurrency domains.
- **Same-file writes** are not internally serialized. The caller is responsible for not writing to the same file from multiple threads concurrently.
- **`terminate()` and `isInitialized`** remain actor-isolated to prevent teardown during active operations.

## Architecture

Four tiers, because the Adobe SDK is C++ and none of it can be reached from Swift directly.

`SPFKMetadataXMP` is the Swift surface — the `XMP` actor plus the value types it returns
(`XMPDynamicMedia`, `VideoXMP`, `XMPMarker`, `XMPElement`, `FrameRate`).

`SPFKMetadataXMPC` is the ObjC++ bridge. It exists in two halves on purpose: `.mm` files that
Swift can see, and a `.cpp` layer that Swift cannot, holding the mutex-protected SDK lifecycle and
the stack-local `SXMPFiles`/`SXMPMeta` work. Keeping the C++ out of any Swift-visible header is
what lets consumers avoid `.interoperabilityMode(.Cxx)`.

`XMPCore.xcframework` and `XMPFiles.xcframework` are the vendored Adobe SDK binaries.

## Dependencies

| Package | Purpose |
|---------|---------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Foundation extensions, logging, error utilities |
| [spfk-metadata-image](https://github.com/ryanfrancesconi/spfk-metadata-image) | Image metadata types shared with the TagLib path |
| [spfk-time](https://github.com/ryanfrancesconi/spfk-time) | CMTime utilities, SwiftTimecode re-export |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | AEXML XML parsing, string extensions |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test infrastructure (test target only) |

## Future API Opportunities

The Adobe XMP SDK exposes ~300+ methods across `TXMPMeta`, `TXMPFiles`, `TXMPIterator`, and `TXMPUtils`. This package currently uses a small subset — open, read, write, serialize, and per-property get and set. Below are capabilities worth exploring.

### Typed and localized property access

The batch property calls cover string properties. The type-specific variants (`_Bool`, `_Int`,
`_Float`, `_Date`, `_Int64`) and `GetLocalizedText` / `SetLocalizedText` for locale-aware `dc:title`
handling are not wrapped yet.

### Property Iterator

`TXMPIterator` walks the XMP property tree node-by-node. Useful for discovery/inspection tools or memory-efficient traversal of large XMP packets without parsing the entire DOM.

### Structured Property Composition

`TXMPUtils::ComposeArrayItemPath`, `ComposeStructFieldPath`, `ComposeQualifierPath` — build canonical XMP paths for nested structures. Avoids manual string construction for complex property access.

### Template-Based Bulk Updates

`TXMPUtils::ApplyTemplate` merges XMP from one `SXMPMeta` into another with configurable merge modes (replace, add, clear). Could enable batch metadata stamping across files.

### File Format Detection

`TXMPFiles::CheckFileFormat` identifies format from file content (not extension). More robust than extension-based routing.

### Sidecar XMP Support

The SDK can read/write `.xmp` sidecar files for formats that don't support embedded XMP. Could extend support to formats like raw AAC.

### Progress Callbacks

`SetProgressCallback` on `TXMPFiles` for monitoring long read/write operations. Useful for batch processing UI feedback.

### Associated Resources

`GetAssociatedResources` finds related files (sidecars, thumbnails). `IsMetadataWritable` checks write support before attempting.

### Audio-Specific Namespaces

Built-in constants for `kXMP_NS_BWF` (Broadcast Wave), `kXMP_NS_iXML`, `kXMP_NS_DM` (Dynamic Media), plus `RegisterNamespace` for custom schemas.

### Serialization Options

Compact output, pretty-print, read-only packets, exact packet sizing, padding control — fine-grained control over XML output format.

## Requirements

- **Platforms:** macOS 13+
- **Swift:** 6.2+
- C++20 (for the XMP SDK bridge layer)

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
