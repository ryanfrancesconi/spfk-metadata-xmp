# SPFKMetadataXMP

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata-xmp)](https://github.com/ryanfrancesconi/spfk-metadata-xmp/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)

A Swift package for reading and writing [Adobe XMP](https://developer.adobe.com/xmp/docs/) metadata embedded in audio and video files on macOS. Built on top of the Adobe XMP SDK (via bundled `XMPCore` and `XMPFiles` binary frameworks) with a Swift-native API layer.

## Overview

The main pieces:

- **`XMP`** — Reading and writing raw XMP XML strings, and individual properties in a batch. Manages the Adobe XMP SDK lifecycle; every SDK call in the process is serialized behind one lock.
- **`XMPDynamicMedia`** — A `Sendable` struct parsing XMP XML into strongly-typed properties focused on timecode, markers and media metadata.
- **`XMPEdit`** — A pending edit, saved through `MetaAudioFileDescription.save(dirtyFlags:xmpEdit:)` by the container's policy.
- **`VideoXMP`** — Reading, writing and clearing the descriptive fields of a QuickTime container. Not QuickTime-only in practice: it addresses the same fourteen fields on any format a handler covers, and TorchTag routes DNG here because ImageIO cannot encode it.
- **`XMP.writeSupport(for:)`** — Which formats the toolkit is known to write, three-valued.

### Supported File Formats

The SDK reads and writes XMP in AIF, M4A, MP3, MP4, MOV, M4V, WAV, DNG, AVI and WMV. Raw AAC
containers are read-only. `XMPContainerPolicy` says, per container, which store owns the fields the
packet shares with the file's native metadata, and `XMP.writeSupport(for:)` what is known about
writing it at all.

### Native metadata

On every format except ISO MPEG-4 the toolkit reconciles the packet with the file's native metadata:
a read imports native values over the packet's, and a write exports the packet back into them,
creating and deleting chunks to match. The policy follows from that:

| Policy | Containers | Who writes |
|---|---|---|
| `.nativeOwned` | WAV, MP3 | TagLib stores the packet (`_PMX`, ID3v2 `PRIV`) in the same save as the native chunks. The toolkit only reads these files. An edit to a mirrored property (Scene, Log Comment, title, artist, `bext:*`) is applied to the native field it mirrors. |
| `.reconciled` | AIFF, MPEG-4, QuickTime, DNG, AVI, WMV | The toolkit, in one open without `kXMPFiles_OpenOnlyXMP`, so its export runs against the native state it just imported. |
| `.unsupported` | Matroska, MXF, MPEG-2, AVCHD | Nothing: no handler, a sidecar written beside the file, or packet scanning that cannot place a packet. |

`MetaAudioFileDescription.save(dirtyFlags:xmpEdit:)` dispatches on the policy, so a caller hands it
an `XMPEdit` (the packet the edit began from and the edited one) and needs no per-format code.
On a reconciled file the toolkit write runs even when part of the native save failed, and both
results arrive in one `MetadataError.incompleteSave(written:failures:)`, with `.xmp` among the
written components when the packet was saved.

**Never open a reconciled file for update with `kXMPFiles_OpenOnlyXMP`.** The MPEG-4 handler still
exports, against a `moov` it parsed without native items, and deletes every QuickTime `udta` text
item (`©nam`, `©ART`, `©cpy`) when it rewrites `moov`.

**On DNG, XMP owns the IPTC-mapped fields.** Every write deletes the IPTC-IIM (33723) and Photoshop
resources (34377) tags, per Adobe's DNG convention, and rewrites EXIF 270/315/33432 from the packet.
Their values survive in the packet; only a reader of IIM alone loses them.

Clearing (`XMPEdit.canClear(url:)`) removes the packet on WAV and MP3, and on MPEG-4 every property
except those the handler mirrors from native metadata (dates, duration, `cprt`, timecode). It is
refused on AIFF and DNG, where any packet property can be native-backed.

`XMP.writeSupport(for:)` answers what is actually known about a given file, and is three-valued
rather than a `Bool` because the two negatives are different answers. `.verified` means a write and
read-back has been run against a real file of that format; `.unsupported` means the toolkit cannot
write into the file itself; `.unknown` means nobody has established either.

The list is static because there is nothing to ask. Unlike ImageIO's
`CGImageDestinationCopyTypeIdentifiers()`, the SDK exposes no queryable handler list. Recognizing a
format is also not writing it: the binary's extension table lists `heic`/`heif`, and that handler
can neither write XMP into a HEIC nor read back what ImageIO wrote there.

## Installation

```swift
.package(url: "https://github.com/ryanfrancesconi/spfk-metadata-xmp", from: "2.0.0")
```

```swift
import SPFKMetadataXMP
```

## Key Types

### XMP

Wraps the Adobe XMP C++ SDK and its one-time initialization. Calls are serialized: every SDK
operation holds one process-wide mutex.

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
user data, duration and track count preserved. The first write, and any that outgrows the packet's
padding, rewrites `moov`.

### XMPEdit

A pending edit: the packet it began from and the packet it ends at. Only the top-level properties
that differ are written, so a property another app changed in the meantime is kept unless the edit
changed it too. `XMP.merging(changesFrom:to:onto:)` is the same merge without a file.

### XMPPropertyRead / XMPPropertyWrite

One property to read, or to write or remove, in a batch call — so a caller touching several fields
opens the file once instead of once per field.

### FrameRate

Maps XMP timecode format strings (e.g. `"25Timecode"`, `"2997DropTimecode"`) to `TimecodeFrameRate` values. Supports 23.976, 24, 25, 29.97 (drop and non-drop), 30, 50, 59.94 (drop and non-drop), and 60 fps.

### XMPElement

A `String`-backed enum representing XMP namespace elements (`rdf:RDF`, `xmpDM:Tracks`, `dc:title`, etc.) with a type-safe `AEXMLElement` subscript for XML traversal.

## Thread Safety

- **SDK initialization** (`SXMPMeta::Initialize`, `SXMPFiles::Initialize`) is protected by a `std::mutex` in the C++ layer, ensuring safe one-time setup even under concurrent access.
- **Every read and write holds the same mutex** (`XMPLifecycleCXX::operationMutex`), so XMP file I/O is serialized process-wide.
- **`XMPDynamicMedia` is `Sendable`** — all properties are value types, immutable after initialization. Instances can be safely passed across concurrency domains.
- **Same-file writes** are not internally serialized. The caller is responsible for not writing to the same file from multiple threads concurrently.

## Architecture

Four tiers, because the Adobe SDK is C++ and none of it can be reached from Swift directly.

`SPFKMetadataXMP` is the Swift surface — the `XMP` namespace plus the value types it returns
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
| [spfk-metadata](https://github.com/ryanfrancesconi/spfk-metadata) | TagLib storage of the WAV and MP3 packet, and the native fields an edit is redirected to |
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
