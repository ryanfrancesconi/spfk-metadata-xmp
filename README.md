# SPFKMetadataXMP

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata-xmp)](https://github.com/ryanfrancesconi/spfk-metadata-xmp/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)

Reads and writes [Adobe XMP](https://developer.adobe.com/xmp/docs/) embedded in audio and video
files, and in DNG, through Adobe's XMP Toolkit, vendored here as prebuilt `XMPCore` and `XMPFiles`
binaries behind an Objective-C++ bridge. An app embeds it to read Dynamic Media data (timecode,
markers, frame rate) and to edit the descriptive XMP fields of a file in place.

Native tags, BEXT and iXML belong to
[spfk-metadata](https://github.com/ryanfrancesconi/spfk-metadata), which stores the WAV and MP3
packet on this package's behalf. Image XMP for the formats the toolkit cannot write, HEIC above all,
belongs to [spfk-metadata-image](https://github.com/ryanfrancesconi/spfk-metadata-image), whose
field set `VideoXMP` shares.

## Who owns a shared field

On most formats the toolkit reconciles the packet with the file's native metadata, importing native
values on read and exporting the packet back over them on write. `XMPContainerPolicy` says, per
container, whether TagLib owns the write, the toolkit does, or nothing can. A caller saves an
`XMPEdit` through `MetaAudioFileDescription.save(dirtyFlags:xmpEdit:)` and needs no per-format code.
An edit writes only the properties it changed, so another app's change in the meantime survives.

On DNG, XMP owns the IPTC-mapped fields: a write removes the IPTC-IIM and Photoshop resource tags,
per Adobe's DNG convention, and keeps their values in the packet.

## Constraints

- Every toolkit call in the process is serialized behind one lock. Writes to the same file from
  several tasks are not coordinated beyond that.
- Inside the bridge, never open a reconciled file for update with `kXMPFiles_OpenOnlyXMP`: the
  MPEG-4 handler then rewrites `moov` without the native items and deletes the QuickTime user data.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
