// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import AVFoundation
import CoreMedia
import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import SPFKUtils
import Testing

/// Removing a property, as distinct from writing an empty value.
///
/// The distinction is not cosmetic. `SetProperty` with `""` stores a literal empty value, and on a
/// property the toolkit has reconciled into a language alternative -- `dc:title`, `dc:description`,
/// `dc:rights` -- it fails outright with "Composite nodes can't have values". Any editor that lets
/// a user empty a field needs real removal, so these cover the shapes that behave differently:
/// a lang-alt-reconciled scalar, a plain scalar, and an array.
@Suite
class PropertyRemovalTests: BinTestCase {
    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let photoshop = "http://ns.adobe.com/photoshop/1.0/"

    /// The case this API exists for, on a real video container -- `sample.mov` rather than the
    /// `tabla.mp4` fixture, which is audio-only and so does not exercise the same format handler.
    /// `dc:title` reconciles into an
    /// `rdf:Alt`, and clearing it by writing `""` throws "Composite nodes can't have values".
    /// Verified additionally against a 4K iPhone `.mov` (2026-08-02) -- all fourteen modeled
    /// fields wrote and cleared, with every `com.apple.quicktime.*` item preserved.
    @Test func removingALanguageAlternativeScalarClearsItOnVideo() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "RemoveMe", url: url)
        #expect(try XMP.parse(url: url).contains("RemoveMe"))

        try XMP.setProperties([.removal(namespace: Self.dc, name: "title")], url: url)
        #expect(try !XMP.parse(url: url).contains("RemoveMe"))
    }

    /// A removal must not damage the media it is attached to.
    @Test func removingAPropertyLeavesTheVideoPlayable() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.sample_mov)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "Temporary", url: url)
        try XMP.setProperties([.removal(namespace: Self.dc, name: "title")], url: url)

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.load(.tracks)
        let duration = try await asset.load(.duration)

        #expect(tracks.isNotEmpty)
        #expect(CMTimeGetSeconds(duration) > 0)
    }

    /// Same lang-alt case on an audio MP4, so the behavior is pinned for both handlers.
    @Test func removingALanguageAlternativeScalarClearsItOnAudio() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "RemoveMe", url: url)
        #expect(try XMP.parse(url: url).contains("RemoveMe"))

        try XMP.setProperties([.removal(namespace: Self.dc, name: "title")], url: url)
        #expect(try !XMP.parse(url: url).contains("RemoveMe"))
    }

    @Test func removingAPlainScalarClearsIt() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setProperty(namespace: Self.photoshop, name: "City", value: "Portland", url: url)
        #expect(try XMP.parse(url: url).contains("Portland"))

        try XMP.setProperties([.removal(namespace: Self.photoshop, name: "City")], url: url)
        #expect(try !XMP.parse(url: url).contains("Portland"))
    }

    @Test func removingAnArrayClearsEveryItem() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setArrayProperty(namespace: Self.dc, name: "subject", values: ["beach", "sunset"], url: url)
        let written = try XMP.parse(url: url)
        #expect(written.contains("beach") && written.contains("sunset"))

        try XMP.setProperties([.removal(namespace: Self.dc, name: "subject")], url: url)
        let cleared = try XMP.parse(url: url)
        #expect(!cleared.contains("beach") && !cleared.contains("sunset"))
    }

    /// Clearing an already-empty field is the ordinary case in an editor -- committing a field the
    /// user never filled in. It must not throw.
    @Test func removingAPropertyThatIsNotPresentIsNotAnError() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "Anchor", url: url)
        try XMP.setProperties([.removal(namespace: Self.photoshop, name: "City")], url: url)

        // The unrelated property is untouched, and nothing threw.
        #expect(try XMP.parse(url: url).contains("Anchor"))
    }

    /// A removal must not disturb anything else -- the reason this is a per-property operation
    /// rather than clearing the packet.
    @Test func removingOnePropertyLeavesTheOthersIntact() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setProperties([
            .simple(namespace: Self.dc, name: "title", value: "GoesAway"),
            .simple(namespace: Self.photoshop, name: "City", value: "StaysPut"),
            .array(namespace: Self.dc, name: "subject", values: ["kept"]),
        ], url: url)

        try XMP.setProperties([.removal(namespace: Self.dc, name: "title")], url: url)

        let result = try XMP.parse(url: url)
        #expect(!result.contains("GoesAway"))
        #expect(result.contains("StaysPut"))
        #expect(result.contains("kept"))
    }

    /// Writes and removals in one batch, which is the shape a save actually takes: populated
    /// fields written, emptied fields removed, in a single open/write cycle.
    @Test func writesAndRemovalsCanShareOneBatch() async throws {
        deleteBinOnExit = true
        let url = try copyToBin(url: TestBundleResources.shared.tabla_mp4)

        try XMP.setProperty(namespace: Self.dc, name: "title", value: "OldTitle", url: url)

        try XMP.setProperties([
            .removal(namespace: Self.dc, name: "title"),
            .simple(namespace: Self.photoshop, name: "City", value: "NewCity"),
        ], url: url)

        let result = try XMP.parse(url: url)
        #expect(!result.contains("OldTitle"))
        #expect(result.contains("NewCity"))
    }
}
