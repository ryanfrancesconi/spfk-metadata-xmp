import SPFKMetadataXMP
import Testing

struct LifecycleTests {
    @Test func canInitialize() async throws {
        let xmp = XMP.shared
        #expect(await xmp.isInitialized)
        await xmp.terminate()
    }
}
