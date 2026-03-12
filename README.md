# SPFKMetadataXMP

A Swift package for reading and writing [Adobe XMP](https://www.adobe.com/devnet/xmp.html) metadata embedded in audio and video files on macOS. Built on top of the Adobe XMP SDK (via bundled `XMPCore` and `XMPFiles` binary frameworks) with a Swift-native API layer.

## Overview

SPFKMetadataXMP provides two main components:

- **`XMP`** — A thread-safe `actor` singleton for reading and writing raw XMP XML strings to/from media files. Manages the Adobe XMP SDK lifecycle. The `parse` and `write` methods are `nonisolated`, enabling true concurrent file operations without actor serialization.
- **`XMPMetadata`** — A `Sendable` struct that parses XMP XML into strongly-typed properties focused on timecode, markers, and media metadata.

### Supported File Formats

The XMP SDK supports reading and writing metadata for common media containers including AIF, M4A, MP3, MP4, and WAV. Raw AAC containers are read-only (no XMP write support).

## Key Types

### XMP

Singleton actor that wraps the Adobe XMP C++ SDK. Handles SDK initialization via mutex-protected C++ lifecycle management. File I/O methods are `nonisolated` — they bypass the actor's serial executor because the underlying C++ calls use stack-local `SXMPFiles` / `SXMPMeta` instances with no shared state.

```swift
// Read XMP from a file (synchronous, nonisolated)
let xmlString = try XMP.shared.parse(url: fileURL)

// Write XMP to a file (synchronous, nonisolated)
try XMP.shared.write(string: xmlString, to: fileURL)

// Concurrent reads are safe — each call gets its own C++ objects
try await withThrowingTaskGroup(of: XMPMetadata.self) { group in
    for url in urls {
        group.addTask { try XMPMetadata(url: url) }
    }
    // ...
}
```

### XMPMetadata

Parses XMP XML into structured properties. Can be initialized from a file URL, an XML string, or an `AEXMLDocument`.

```swift
// From a file (synchronous, thread-safe)
let metadata = try XMPMetadata(url: fileURL)

// From an XML string
let metadata = try XMPMetadata(xml: xmlString)

// Access parsed properties
metadata.title              // dc:title
metadata.frameRate          // TimecodeFrameRate (from timecode or nominal rate)
metadata.startTimecodeResolved  // Timecode (prefers altTimecode over startTimecode)
metadata.markers            // [XMPMarker]
metadata.duration           // TimeInterval
metadata.audioSampleRate    // Double
metadata.audioChannelType   // String (e.g. "Stereo")
metadata.videoFieldOrder    // String (e.g. "Progressive")
metadata.nominalFrameRate   // Float (e.g. 25.0)
metadata.creatorTool        // String (e.g. "Adobe Premiere Pro 2022.0")
metadata.createDate         // String
metadata.startTimeScale     // CMTimeScale
metadata.startTimeSampleSize // CMTimeValue
```

### XMPMarker

Represents a single marker from the XMP `xmpDM:Tracks` data, with frame-based and time-based positioning.

```swift
let marker = XMPMarker(
    name: "Hit",
    comment: "impact sound",
    startFrame: 48,
    durationInFrames: 5,
    frameRate: .fps25
)

marker.time           // 1.92 (seconds)
marker.duration       // 0.2 (seconds)
marker.startTimecode  // Timecode value
```

### FrameRate

Maps XMP timecode format strings (e.g. `"25Timecode"`, `"2997DropTimecode"`) to `TimecodeFrameRate` values. Supports 23.976, 24, 25, 29.97 (drop and non-drop), 30, 50, 59.94 (drop and non-drop), and 60 fps.

### XMPElement

A `String`-backed enum representing XMP namespace elements (`rdf:RDF`, `xmpDM:Tracks`, `dc:title`, etc.) with a type-safe `AEXMLElement` subscript for XML traversal.

## Thread Safety

The package is designed for concurrent use across multiple files:

- **SDK initialization** (`SXMPMeta::Initialize`, `SXMPFiles::Initialize`) is protected by a `std::mutex` in the C++ layer, ensuring safe one-time setup even under concurrent access.
- **`parse()` and `write()` are `nonisolated`** on the `XMP` actor. Each call creates stack-local `SXMPFiles` and `SXMPMeta` C++ objects with no shared mutable state, so multiple files can be read or written in parallel.
- **`XMPMetadata` is `Sendable`** — all properties are value types, immutable after initialization. Instances can be safely passed across concurrency domains.
- **Same-file writes** are not internally serialized. The caller is responsible for not writing to the same file from multiple threads concurrently.
- **`terminate()` and `isInitialized`** remain actor-isolated to prevent teardown during active operations.

## Architecture

```
SPFKMetadataXMP (Swift)
  |-- XMP.swift              Actor: SDK lifecycle + nonisolated file I/O
  |-- XMPMetadata.swift      XMP XML parser -> structured metadata
  |-- XMPMarker.swift        Marker data type with time calculations
  |-- XMPElement.swift       XMP namespace element enum + AEXML subscript
  |-- FrameRate.swift        XMP timecode format -> TimecodeFrameRate mapping

SPFKMetadataXMPC (Objective-C++ / C++)
  |-- XMPFile.mm             ObjC++ bridge to XMPUtil C++ functions
  |-- XMPLifecycle.mm        ObjC++ bridge to SDK init/terminate
  |-- XMPLifecycleCXX.cpp    Mutex-protected C++ SDK lifecycle
  |-- XMPUtil.cpp            C++ XMP read/write (stack-local SXMPFiles/SXMPMeta)

Frameworks/
  |-- XMPCore.xcframework    Adobe XMP Core SDK binary
  |-- XMPFiles.xcframework   Adobe XMP Files SDK binary
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Foundation extensions, logging, error utilities |
| [spfk-time](https://github.com/ryanfrancesconi/spfk-time) | CMTime utilities, SwiftTimecode re-export |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | AEXML XML parsing, string extensions |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test infrastructure (test target only) |

## Future API Opportunities

The Adobe XMP SDK exposes ~300+ methods across `TXMPMeta`, `TXMPFiles`, `TXMPIterator`, and `TXMPUtils`. This package currently uses a small subset (open/read/write/serialize). Below are capabilities worth exploring.

### Direct Property Access

`GetProperty` / `SetProperty` with type-specific variants (`_Bool`, `_Int`, `_Float`, `_Date`, `_Int64`). Would allow reading or modifying individual XMP fields without full XML round-tripping. Also `GetLocalizedText` / `SetLocalizedText` for locale-aware `dc:title` handling.

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

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
