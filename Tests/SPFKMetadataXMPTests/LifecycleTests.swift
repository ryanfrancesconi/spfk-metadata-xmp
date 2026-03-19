import SPFKMetadataXMP
import Testing

struct LifecycleTests {
    @Test func canInitialize() throws {
        let xmp = XMP.shared
        #expect(xmp.isInitialized)
        xmp.terminate()
    }
}
