import Foundation

#if canImport(Testing)
    import Testing

    // https://github.com/swift-embedded-linux/armhf-debian/issues/10:
    // Test that large file system sizes can be read without crashing from FileManager.attributesOfFileSystem.
    // This assumes that the host filesystem will be larger than 4GB, which is typical for modern systems.
    @Test func fileManagerAttributesOfFileSystem() throws {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
        let systemSize = try #require(attributes[.systemSize] as? UInt64)
        print("Root '/' drive size: \(systemSize) bytes (\(systemSize / 1024 / 1024 / 1024) GB)")
    }
#endif
