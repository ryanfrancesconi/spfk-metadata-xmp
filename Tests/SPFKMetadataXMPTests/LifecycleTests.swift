import SPFKMetadataXMP
import Testing

struct LifecycleTests {
    @Test func canInitialize() throws {
        let xmp = XMP.shared
        #expect(xmp.isInitialized)
        // Do NOT call terminate() here — it races with any concurrent XMP test.
        // SXMPFiles::Terminate() zeroes the format handler table while another
        // thread may be inside OpenFile(), causing a null-pointer crash.
    }
}
