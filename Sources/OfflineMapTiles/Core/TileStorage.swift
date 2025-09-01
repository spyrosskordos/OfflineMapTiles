import Foundation

/// Simple, focused tile storage implementation
/// Follows Single Responsibility Principle: only handles tile persistence
public final class TileStorage: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let namespace: String
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create tile storage with a specific namespace to prevent conflicts
    /// - Parameter namespace: Unique namespace for this storage instance
    public init(namespace: String) throws {
        self.namespace = namespace
        self.fileManager = FileManager.default
        self.logger = Logger.shared
        
        // Create base directory in Caches
        let cacheDir = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        self.baseDirectory = cacheDir
            .appendingPathComponent("OfflineMapTiles")
            .appendingPathComponent(namespace)
        
        // Ensure directory exists
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        logger.debug("TileStorage initialized with namespace '\(namespace)' at: \(baseDirectory.path)")
    }
    
    // MARK: - Core Storage Operations
    
    /// Save tile data to storage
    /// - Parameters:
    ///   - data: Tile data to save
    ///   - coordinate: Tile coordinate
    public func saveTile(data: Data, coordinate: TileCoordinate) async throws {
        let fileURL = tileURL(for: coordinate)
        
        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Write file
        try data.write(to: fileURL)
    }
    
    /// Retrieve tile data from storage
    /// - Parameter coordinate: Tile coordinate
    /// - Returns: Tile data if exists, nil otherwise
    public func getTile(coordinate: TileCoordinate) async -> Data? {
        let fileURL = tileURL(for: coordinate)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            logger.warning("Failed to read tile file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if tile exists in storage
    /// - Parameter coordinate: Tile coordinate
    /// - Returns: True if tile exists
    public func hasTile(coordinate: TileCoordinate) async -> Bool {
        let fileURL = tileURL(for: coordinate)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Delete a specific tile
    /// - Parameter coordinate: Tile coordinate
    public func deleteTile(coordinate: TileCoordinate) async throws {
        let fileURL = tileURL(for: coordinate)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // Already deleted
        }
        
        try fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Management
    
    /// Get total cache size for this namespace
    /// - Returns: Size in bytes
    public func getCacheSize() async -> Int64 {
        do {
            let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: baseDirectory,
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
            logger.error("Failed to calculate cache size: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Get number of cached tiles
    /// - Returns: Number of tiles
    public func getTileCount() async -> Int {
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: baseDirectory,
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
            logger.error("Failed to count tiles: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Clear all cached tiles for this namespace
    public func clearAll() async throws {
        guard fileManager.fileExists(atPath: baseDirectory.path) else {
            return // Nothing to clear
        }
        
        try fileManager.removeItem(at: baseDirectory)
        
        // Recreate the directory
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        logger.info("Cleared all tiles for namespace '\(namespace)'")
    }
    
    // MARK: - Private Methods
    
    private func tileURL(for coordinate: TileCoordinate) -> URL {
        // Create hierarchical structure: zoom/x/y.png
        return baseDirectory
            .appendingPathComponent("\(coordinate.zoom)")
            .appendingPathComponent("\(coordinate.x)")
            .appendingPathComponent("\(coordinate.y).png")
    }
}