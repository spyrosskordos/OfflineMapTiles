import Foundation

/// Simple tile storage that uses key-based file storage
public final class TileStorage: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create tile storage
    public init() throws {
        self.fileManager = FileManager.default
        self.logger = Logger.shared
        
        // Create base directory in Caches
        let cacheDir = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        self.baseDirectory = cacheDir.appendingPathComponent("OfflineMapTiles")
        
        // Create base directory
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        logger.info("TileStorage initialized at: \(baseDirectory.path)")
    }
    
    // MARK: - Core Storage Operations
    
    /// Save tile data using key
    /// - Parameters:
    ///   - data: Tile data to save
    ///   - key: Tile key
    public func saveTile(data: Data, key: String) async throws {
        let fileURL = tileURL(for: key)
        
        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Write file atomically
        try data.write(to: fileURL, options: .atomic)
        
        logger.debug("Saved tile with key '\(key)'")
    }
    
    /// Retrieve tile data using key
    /// - Parameter key: Tile key
    /// - Returns: Tile data if exists, nil otherwise
    public func getTile(key: String) async -> Data? {
        let fileURL = tileURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            logger.debug("Retrieved tile with key '\(key)'")
            return data
        } catch {
            logger.warning("Failed to read tile with key '\(key)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if tile exists using key
    /// - Parameter key: Tile key
    /// - Returns: True if tile exists
    public func hasTile(key: String) async -> Bool {
        let fileURL = tileURL(for: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Delete a specific tile using key
    /// - Parameter key: Tile key
    public func deleteTile(key: String) async throws {
        let fileURL = tileURL(for: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // Already deleted
        }
        
        try fileManager.removeItem(at: fileURL)
        logger.debug("Deleted tile with key '\(key)'")
    }
    
    // MARK: - Cache Management
    
    /// Get total cache size
    /// - Returns: Size in bytes
    public func getCacheSize() async -> Int64 {
        return calculateDirectorySize(at: baseDirectory)
    }
    
    /// Get tile count
    /// - Returns: Number of tiles
    public func getTileCount() async -> Int {
        return countFilesInDirectory(at: baseDirectory)
    }
    
    /// Clear all tiles
    public func clearCache() async throws {
        // Remove all contents but keep the base directory
        if fileManager.fileExists(atPath: baseDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
            }
        }
        
        logger.info("Cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// Generate file URL for tile key
    private func tileURL(for key: String) -> URL {
        // Create directory structure based on key to avoid too many files in one directory
        let firstTwo = String(key.prefix(2))
        let secondTwo = String(key.dropFirst(2).prefix(2))
        let directoryPath = "\(firstTwo)/\(secondTwo)"
        
        return baseDirectory
            .appendingPathComponent(directoryPath)
            .appendingPathComponent("\(key).png")
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in return true }
            )
            
            var totalSize: Int64 = 0
            
            if let enumerator = enumerator {
                for case let fileURL as URL in enumerator {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if let isDirectory = resourceValues.isDirectory, !isDirectory,
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
            
            return totalSize
        } catch {
            logger.error("Failed to calculate directory size: \(error.localizedDescription)")
            return 0
        }
    }
    
    private func countFilesInDirectory(at url: URL) -> Int {
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in return true }
            )
            
            var count = 0
            
            if let enumerator = enumerator {
                for case let fileURL as URL in enumerator {
                    let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    
                    if let isDirectory = resourceValues.isDirectory, !isDirectory {
                        count += 1
                    }
                }
            }
            
            return count
        } catch {
            logger.error("Failed to count files: \(error.localizedDescription)")
            return 0
        }
    }
}