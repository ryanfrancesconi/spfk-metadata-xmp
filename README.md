# SPFKMetadataXMP

A Swift package for reading and writing [Adobe XMP](https://www.adobe.com/devnet/xmp.html) metadata embedded in audio and video files on macOS. Built on top of the Adobe XMP SDK (via bundled `XMPCore` and `XMPFiles` binary frameworks) with a Swift-native API layer.

## Overview

SPFKMetadataXMP provides two main components:

- **`XMP`** — A thread-safe `actor` for reading and writing raw XMP XML strings to/from media files. Manages the Adobe XMP SDK lifecycle and supports concurrent file operations.
- **`XMPMetadata`** — A `Sendable` struct that parses XMP XML into strongly-typed properties focused on timecode, markers, and media metadata.

### Supported File Formats

The XMP SDK supports reading and writing metadata for common media containers including AIF, M4A, MP3, MP4, and WAV. Raw AAC containers are read-only (no XMP write support).

## Key Types

### XMP

Singleton actor that wraps the Adobe XMP C++ SDK. Handles SDK initialization and provides async-safe file I/O.

```swift
// Read XMP from a file
let xmlString = try await XMP.shared.parse(url: fileURL)

// Write XMP to a file
try await XMP.shared.write(string: xmlString, to: fileURL)
```

### XMPMetadata

Parses XMP XML into structured properties. Can be initialized from a file URL, an XML string, or an `AEXMLDocument`.

```swift
// From a file
let metadata = try await XMPMetadata(url: fileURL)

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

### XMPMetadata.FrameRate

Maps XMP timecode format strings (e.g. `"25Timecode"`, `"2997DropTimecode"`) to `TimecodeFrameRate` values. Supports 23.976, 24, 25, 29.97 (drop and non-drop), 30, 50, 59.94 (drop and non-drop), and 60 fps.

### XMPElement

A `String`-backed enum representing XMP namespace elements (`rdf:RDF`, `xmpDM:Tracks`, `dc:title`, etc.) with a type-safe `AEXMLElement` subscript for XML traversal.

## Architecture

```
SPFKMetadataXMP (Swift)
  ├── XMP.swift              — Actor wrapping XMP SDK lifecycle and file I/O
  ├── XMPMetadata.swift      — XMP XML parser → structured metadata
  ├── XMPMarker.swift        — Marker data type with time calculations
  ├── XMPElement.swift       — XMP namespace element enum + AEXML subscript
  └── FrameRate.swift        — XMP timecode format → TimecodeFrameRate mapping

SPFKMetadataXMPC (Objective-C++ / C++)
  ├── XMPFile.mm             — ObjC++ bridge to XMPUtil C++ functions
  ├── XMPLifecycle.mm        — ObjC++ bridge to SDK init/terminate
  ├── XMPLifecycleCXX.cpp    — C++ SDK lifecycle management
  └── XMPUtil.cpp            — C++ XMP read/write via Adobe SDK

Frameworks/
  ├── XMPCore.xcframework    — Adobe XMP Core SDK binary
  └── XMPFiles.xcframework   — Adobe XMP Files SDK binary
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Foundation extensions, logging, error utilities |
| [spfk-time](https://github.com/ryanfrancesconi/spfk-time) | CMTime utilities, SwiftTimecode re-export |
| [spfk-utils](https://github.com/ryanfrancesconi/spfk-utils) | AEXML XML parsing, string extensions |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test infrastructure (test target only) |

## Requirements

- **Platforms:** macOS 13+
- **Swift:** 6.2+
- C++20 (for the XMP SDK bridge layer)

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
