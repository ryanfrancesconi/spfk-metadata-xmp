// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

@preconcurrency import AEXML
import Foundation
import SPFKBase

// MARK: - Editable xmpDM fields

extension XMPMetadata {
    /// Scene identifier, e.g. "INT. KITCHEN - DAY".
    public var scene: String? {
        get { value(for: .scene) }
        set { setValue(newValue, for: .scene) }
    }

    /// Camera angle, e.g. "Wide Shot", "Close-Up".
    public var cameraAngle: String? {
        get { value(for: .cameraAngle) }
        set { setValue(newValue, for: .cameraAngle) }
    }

    /// Free-form log/continuity comment.
    public var logComment: String? {
        get { value(for: .logComment) }
        set { setValue(newValue, for: .logComment) }
    }

    /// Camera model used to shoot the footage.
    public var cameraModel: String? {
        get { value(for: .cameraModel) }
        set { setValue(newValue, for: .cameraModel) }
    }

    /// User-correctable shot date, distinct from the file's native QuickTime creation date.
    public var shotDate: String? {
        get { value(for: .shotDate) }
        set { setValue(newValue, for: .shotDate) }
    }

    /// User-correctable shot location, distinct from the file's native QuickTime GPS location.
    public var shotLocation: String? {
        get { value(for: .shotLocation) }
        set { setValue(newValue, for: .shotLocation) }
    }

    /// Regenerates the full XMP packet string, reflecting any edits made through the
    /// properties above alongside everything else `document` already holds (markers,
    /// tracks, timecode, and any other namespace this type doesn't model) — since
    /// mutation happens directly on `document` rather than a separate property bag,
    /// nothing else needs to be rebuilt.
    public var xml: String { document.xml }

    /// Direct children of `rdf:Description`, read live off `document` rather than
    /// cached at parse time — these are the only fields on this type that are
    /// user-editable, so backing them by the live document (instead of the
    /// stored-property + full-rebuild pattern `IXMLMetadata` uses) means edits
    /// can't drift out of sync with round-trip content this type doesn't model.
    private var descriptionElement: AEXMLElement? {
        document.root[.rdf]?[.description]
    }

    private func value(for element: XMPElement) -> String? {
        descriptionElement?[element]?.value
    }

    private func setValue(_ value: String?, for element: XMPElement) {
        guard let desc = descriptionElement else {
            Log.error("Failed to find RDF description; cannot set \(element.rawValue)")
            return
        }

        guard let value, value.isNotEmpty else {
            desc[element]?.removeFromParent()
            return
        }

        if let existing = desc[element] {
            existing.value = value
        } else {
            desc.addChild(name: element.rawValue, value: value)
        }
    }
}
