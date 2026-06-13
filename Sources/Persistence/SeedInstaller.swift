import Foundation

/// On first launch, decompresses the bundled LZFSE seed database into place so
/// the app is fully populated and usable offline before any network call.
/// Subsequent launches are a no-op (the DB already exists).
enum SeedInstaller {
    /// Name of the compressed seed bundled as an app resource.
    static let resourceName = "seed.sqlite"
    static let resourceExt = "lzfse"

    /// If no database exists at `destination`, expand the bundled seed into it.
    /// Returns true if a seed was installed.
    @discardableResult
    static func installIfNeeded(at destination: URL, bundle: Bundle = .main) -> Bool {
        guard !FileManager.default.fileExists(atPath: destination.path) else { return false }
        guard let seedURL = bundle.url(forResource: resourceName, withExtension: resourceExt) else {
            return false   // No seed bundled — app falls back to full download.
        }
        do {
            let compressed = try Data(contentsOf: seedURL) as NSData
            let data = try compressed.decompressed(using: .lzfse)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            // Corrupt/missing seed: leave no file so the app downloads instead.
            try? FileManager.default.removeItem(at: destination)
            return false
        }
    }
}
