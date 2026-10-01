// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation
import SPFKAudioBase
import SPFKBase
import SPFKMetadata
import SPFKMetadataBase

/// An XMP property the toolkit reconciles with a native field `MetaAudioFileDescription` writes,
/// so an edit to it has to land in that field: on read the native value wins.
///
/// Limited to fields the description models. A mirrored property with no modeled target (WAV
/// `DISP`, `cart`, INFO `ISBJ`/`ISRF`) stays in the packet only.
struct XMPMirroredField: Sendable {
    let key: XMPPropertyKey
    let isArray: Bool
    let apply: @Sendable (inout MetaAudioFileDescription, String?) throws -> Void

    private init(
        _ namespace: String, _ path: String, isArray: Bool = false,
        apply: @escaping @Sendable (inout MetaAudioFileDescription, String?) throws -> Void
    ) {
        key = XMPPropertyKey(namespace: namespace, path: path)
        self.isArray = isArray
        self.apply = apply
    }

    static func fields(for fileType: AudioFileType?) -> [XMPMirroredField] {
        switch fileType {
        case .wav: wave
        case .mp3: mp3
        default: []
        }
    }

    // MARK: - Namespaces

    private static let dc = "http://purl.org/dc/elements/1.1/"
    private static let dm = "http://ns.adobe.com/xmp/1.0/DynamicMedia/"
    private static let xmp = "http://ns.adobe.com/xap/1.0/"
    private static let rights = "http://ns.adobe.com/xap/1.0/rights/"
    private static let bwf = "http://ns.adobe.com/bwf/bext/1.0/"
    private static let riffInfo = "http://ns.adobe.com/riff/info/"

    // MARK: - Targets

    private static func tag(_ key: TagKey) -> @Sendable (inout MetaAudioFileDescription, String?) throws -> Void {
        { $0.tagProperties.set(tag: key, value: $1) }
    }

    private static func bext(
        _ keyPath: WritableKeyPath<BEXTDescription, String?> & Sendable
    ) -> @Sendable (inout MetaAudioFileDescription, String?) throws -> Void {
        { description, value in
            var bext = description.bextDescription ?? BEXTDescription()
            bext[keyPath: keyPath] = value
            description.bextDescription = bext
        }
    }

    private static func iXML(
        _ keyPath: WritableKeyPath<IXMLMetadata, String?> & Sendable
    ) -> @Sendable (inout MetaAudioFileDescription, String?) throws -> Void {
        { description, value in
            var ixml = try description.iXMLMetadata.map { try IXMLMetadata(xml: $0) } ?? IXMLMetadata()
            ixml[keyPath: keyPath] = value
            description.iXMLMetadata = ixml.xml
        }
    }

    /// XMP booleans are `True`/`False`.
    private static func isTrue(_ value: String?) -> Bool? {
        value.map { $0.caseInsensitiveCompare("true") == .orderedSame }
    }

    // MARK: - Tables

    /// The WAVE handler's BEXT, iXML and INFO mappings. Tags reach INFO through `infoFrame`.
    private static let wave: [XMPMirroredField] = [
        .init(bwf, "bext:description", apply: bext(\.sequenceDescription)),
        .init(bwf, "bext:originator", apply: bext(\.originator)),
        .init(bwf, "bext:originatorReference", apply: bext(\.originatorReference)),
        .init(bwf, "bext:originationDate", apply: bext(\.originationDate)),
        .init(bwf, "bext:originationTime", apply: bext(\.originationTime)),
        .init(bwf, "bext:codingHistory", apply: bext(\.codingHistory)),
        .init(bwf, "bext:umid", apply: bext(\.umid)),
        .init(bwf, "bext:timeReference") { description, value in
            var bext = description.bextDescription ?? BEXTDescription()
            bext.timeReference = value.flatMap(UInt64.init)
            description.bextDescription = bext
        },

        .init(dm, "xmpDM:scene", apply: iXML(\.scene)),
        .init(dm, "xmpDM:tapeName", apply: iXML(\.tape)),
        .init(dm, "xmpDM:shotNumber", apply: iXML(\.take)),
        .init(dm, "xmpDM:projectName", apply: iXML(\.project)),
        .init(dm, "xmpDM:good") { description, value in
            try iXML(\.circled)(&description, isTrue(value).map { $0 ? "TRUE" : "FALSE" })
        },
        .init(dm, "xmpDM:logComment") { description, value in
            try tag(.comment)(&description, value)
            try iXML(\.note)(&description, value)
        },

        .init(dm, "xmpDM:artist", apply: tag(.artist)),
        .init(dm, "xmpDM:engineer", apply: tag(.arranger)),
        .init(dm, "xmpDM:genre", apply: tag(.genre)),
        .init(dc, "dc:rights", apply: tag(.copyright)),
        .init(dc, "dc:subject", isArray: true, apply: tag(.keywords)),
        .init(dc, "dc:source", apply: tag(.media)),
        .init(dc, "dc:title", apply: tag(.title)),
        .init(riffInfo, "riffinfo:name", apply: tag(.title)),
        .init(xmp, "xmp:CreateDate", apply: tag(.date)),
        .init(xmp, "xmp:CreatorTool", apply: tag(.encoding)),
    ]

    /// The MP3 handler's ID3v2 frame table.
    private static let mp3: [XMPMirroredField] = [
        .init(dc, "dc:title", apply: tag(.title)),
        .init(dc, "dc:rights", apply: tag(.copyright)),
        .init(dm, "xmpDM:artist", apply: tag(.artist)),
        .init(dm, "xmpDM:album", apply: tag(.album)),
        .init(dm, "xmpDM:trackNumber", apply: tag(.trackNumber)),
        .init(dm, "xmpDM:genre", apply: tag(.genre)),
        .init(dm, "xmpDM:composer", apply: tag(.composer)),
        .init(dm, "xmpDM:discNumber", apply: tag(.discNumber)),
        .init(dm, "xmpDM:engineer", apply: tag(.remixer)),
        .init(dm, "xmpDM:logComment", apply: tag(.comment)),
        .init(dm, "xmpDM:lyrics", apply: tag(.lyrics)),
        .init(dm, "xmpDM:partOfCompilation") { description, value in
            try tag(.compilation)(&description, isTrue(value).map { $0 ? "1" : "0" })
        },
        .init(xmp, "xmp:CreateDate", apply: tag(.date)),
        .init(rights, "xmpRights:WebStatement", apply: tag(.copyrightURL)),
    ]
}

extension MetaAudioFileDescription {
    /// Applies the edit's changes to mirrored properties onto the native fields they mirror.
    ///
    /// - Returns: whether any native field was written, which the save routes as `.metadata`.
    mutating func applyMirroredChanges(of edit: XMPEdit) throws -> Bool {
        guard let edited = edit.edited else { return false }

        let changed = Set(try XMP.changedProperties(from: edit.baseline, to: edited))
        let fields = XMPMirroredField.fields(for: fileType).filter { changed.contains($0.key) }
        guard fields.isNotEmpty else { return false }

        let values = try XMP.getProperties(
            fields.map { XMPPropertyRead(namespace: $0.key.namespace, name: $0.key.path, isArray: $0.isArray) },
            inPacket: edited
        )

        for (field, value) in zip(fields, values) {
            let joined = field.isArray ? value.joined(separator: "; ") : value.first
            try field.apply(&self, joined?.isEmpty == false ? joined : nil)
        }

        return true
    }
}
