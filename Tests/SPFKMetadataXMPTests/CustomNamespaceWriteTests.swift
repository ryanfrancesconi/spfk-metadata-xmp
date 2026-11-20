import Foundation
import SPFKBase
import SPFKMetadataXMP
import SPFKTesting
import Testing

/// A property in a namespace the toolkit does not know, written after `XMP.registerNamespace`.
@Suite
class CustomNamespaceWriteTests: BinTestCase {
    let namespace = "http://ns.example.com/custom-namespace-write-tests/1.0/"
    let prefix = "cnwt"
    let xmpMMNamespace = "http://ns.adobe.com/xap/1.0/mm/"

    private func seededFile() throws -> URL {
        let url = try copyToBin(url: TestBundleResources.shared.cowbell_wav)
        try XMP.write(string: try sample(named: "sample1.xml"), to: url)
        return url
    }

    private func read(_ url: URL) throws -> (custom: [String], instanceID: [String]) {
        let values = try XMP.getProperties([
            XMPPropertyRead(namespace: namespace, name: "Value"),
            XMPPropertyRead(namespace: xmpMMNamespace, name: "InstanceID"),
        ], url: url)
        return (values[0], values[1])
    }

    @Test func writeReadAndRemove() throws {
        deleteBinOnExit = true
        let url = try seededFile()
        let value = #"{"version":1,"exposure":-1.5}"#

        try XMP.registerNamespace(namespace, suggestedPrefix: prefix)
        try XMP.setProperties([.simple(namespace: namespace, name: "Value", value: value)], url: url)

        let written = try read(url)
        #expect(written.custom == [value])
        #expect(written.instanceID == ["xmp.iid:c74f1ed7-7900-4a34-9586-c5f82754b692"])

        try XMP.setProperties([.removal(namespace: namespace, name: "Value")], url: url)

        let removed = try read(url)
        #expect(removed.custom.isEmpty)
        #expect(removed.instanceID == ["xmp.iid:c74f1ed7-7900-4a34-9586-c5f82754b692"])
    }

    @Test func registeringTwiceReturnsTheSamePrefix() throws {
        let first = try XMP.registerNamespace(namespace, suggestedPrefix: prefix)
        let second = try XMP.registerNamespace(namespace, suggestedPrefix: "other")
        #expect(first == prefix)
        #expect(second == prefix)
    }
}
