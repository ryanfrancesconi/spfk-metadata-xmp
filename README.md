# SPFKMetadataXMP

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-metadata-xmp)](https://github.com/ryanfrancesconi/spfk-metadata-xmp/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-metadata-xmp%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-metadata-xmp)

Reads and writes [Adobe XMP](https://developer.adobe.com/xmp/docs/) in audio, video and DNG files,
using Adobe's XMP Toolkit, vendored as prebuilt `XMPCore` and `XMPFiles` binaries.

## Features

- Read Dynamic Media data: timecode, markers and frame rate
- Edit descriptive XMP fields in place with `XMPEdit`; only the properties an edit changed are
  written
- `XMPContainerPolicy` decides per container whether TagLib or the toolkit writes a shared field
- `VideoXMP` uses the same field set as
  [spfk-metadata-image](https://github.com/ryanfrancesconi/spfk-metadata-image)
- All toolkit calls in the process are serialized behind one lock

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
