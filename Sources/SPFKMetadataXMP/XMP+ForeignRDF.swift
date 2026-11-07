// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-metadata-xmp

import Foundation

public extension XMP {
    /// Whether the file holds RDF metadata outside any XMP packet, which a toolkit write would
    /// discard: the SVG handler replaces such a block -- the Creative Commons description Inkscape
    /// and Openclipart write into `<metadata>` -- with a packet holding only the modeled fields.
    ///
    /// Counts RDF start tags against XMP wrappers, since every packet holds exactly one RDF root.
    /// Reads the whole file; `false` for any format other than SVG.
    static func holdsNonXMPRDF(at url: URL) throws -> Bool {
        guard url.pathExtension.lowercased() == "svg" else { return false }

        let data = try Data(contentsOf: url, options: .alwaysMapped)

        // A byte search first: decoding and matching cost 15x as much, and almost no SVG has RDF.
        guard data.range(of: Data("RDF".utf8)) != nil else { return false }

        let text = String(decoding: data, as: UTF8.self)

        let rdfRoots = text.matches(of: #/<(?:[A-Za-z_][\w.-]*:)?RDF[\s>\/]/#).count
        guard rdfRoots > 0 else { return false }

        let packets = text.matches(of: #/<(?:[A-Za-z_][\w.-]*:)?x[am]pmeta[\s>\/]/#).count
        return rdfRoots > packets
    }
}
