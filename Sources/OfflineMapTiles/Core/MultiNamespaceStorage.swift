import Foundation

/// Storage system that manages multiple isolated namespaces within one instance
/// Prevents tile conflicts by using separate directories for each server
public final class MultiNamespaceStorage: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let namespaces: Set<String>
    private let fileManager: FileManager
    private let baseDirectory: URL
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create multi-namespace storage
    /// - Parameter namespaces: List of namespace identifiers (server names)
    public init(namespaces: [String]) throws {
        guard !namespaces.isEmpty else {
            throw MultiNamespaceStorageError.noNamespaces
        }
        
        // Validate namespace names (must be valid directory names)
        for namespace in namespaces {
            guard isValidNamespace(namespace) else {
                throw MultiNamespaceStorageError.invalidNamespace(namespace)
            }
        }
        
        self.namespaces = Set(namespaces)
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
            .appendingPathComponent("MultiTileService")
        
        // Create base directory and namespace subdirectories
        try fileManager.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create namespace directories
        for namespace in namespaces {
            let namespaceDir = baseDirectory.appendingPathComponent(namespace)
            try fileManager.createDirectory(
                at: namespaceDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        logger.info("MultiNamespaceStorage initialized with \(namespaces.count) namespaces at: \(baseDirectory.path)")
    }
    
    // MARK: - Core Storage Operations
    
    /// Save tile data to a specific namespace
    /// - Parameters:
    ///   - data: Tile data to save
    ///   - coordinate: Tile coordinate
    ///   - namespace: Namespace (server name)
    public func saveTile(data: Data, coordinate: TileCoordinate, namespace: String) async throws {
        try validateNamespace(namespace)
        
        let fileURL = tileURL(for: coordinate, namespace: namespace)
        
        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Write file atomically
        try data.write(to: fileURL, options: .atomic)
        
        logger.debug("Saved tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) to namespace '\(namespace)'")
    }
    
    /// Retrieve tile data from a specific namespace
    /// - Parameters:
    ///   - coordinate: Tile coordinate
    ///   - namespace: Namespace (server name)
    /// - Returns: Tile data if exists, nil otherwise
    public func getTile(coordinate: TileCoordinate, namespace: String) async -> Data? {
        guard namespaces.contains(namespace) else {
            logger.warning("Namespace '\(namespace)' not found")
            return nil
        }
        
        let fileURL = tileURL(for: coordinate, namespace: namespace)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            logger.debug("Retrieved tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) from namespace '\(namespace)'")
            return data
        } catch {
            logger.warning("Failed to read tile from namespace '\(namespace)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if tile exists in a specific namespace
    /// - Parameters:
    ///   - coordinate: Tile coordinate
    ///   - namespace: Namespace (server name)
    /// - Returns: True if tile exists
    public func hasTile(coordinate: TileCoordinate, namespace: String) async -> Bool {
        guard namespaces.contains(namespace) else { return false }
        
        let fileURL = tileURL(for: coordinate, namespace: namespace)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Delete a specific tile from a namespace
    /// - Parameters:
    ///   - coordinate: Tile coordinate
    ///   - namespace: Namespace (server name)
    public func deleteTile(coordinate: TileCoordinate, namespace: String) async throws {
        try validateNamespace(namespace)
        
        let fileURL = tileURL(for: coordinate, namespace: namespace)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // Already deleted
        }
        
        try fileManager.removeItem(at: fileURL)
        logger.debug("Deleted tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) from namespace '\(namespace)'")
    }
    
    // MARK: - Cache Management
    
    /// Get cache size for a specific namespace
    /// - Parameter namespace: Namespace (server name)
    /// - Returns: Size in bytes
    public func getCacheSize(namespace: String) async -> Int64 {
        guard namespaces.contains(namespace) else { return 0 }
        
        let namespaceDir = baseDirectory.appendingPathComponent(namespace)
        return calculateDirectorySize(at: namespaceDir)
    }
    
    /// Get tile count for a specific namespace
    /// - Parameter namespace: Namespace (server name)
    /// - Returns: Number of tiles
    public func getTileCount(namespace: String) async -> Int {
        guard namespaces.contains(namespace) else { return 0 }
        
        let namespaceDir = baseDirectory.appendingPathComponent(namespace)
        return countFilesInDirectory(at: namespaceDir)
    }
    
    /// Clear all tiles in a specific namespace
    /// - Parameter namespace: Namespace (server name)
    public func clearCache(namespace: String) async throws {
        try validateNamespace(namespace)
        
        let namespaceDir = baseDirectory.appendingPathComponent(namespace)
        
        // Remove all contents but keep the namespace directory
        if fileManager.fileExists(atPath: namespaceDir.path) {
            let contents = try fileManager.contentsOfDirectory(at: namespaceDir, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
            }
        }
        
        logger.info("Cleared cache for namespace '\(namespace)'")
    }
    
    /// Clear all tiles in multiple namespaces
    /// - Parameter namespaces: Array of namespace names (defaults to all)
    public func clearCache(namespaces namespacesToClear: [String]? = nil) async throws {
        let targetNamespaces = namespacesToClear ?? Array(namespaces)
        
        for namespace in targetNamespaces {
            try await clearCache(namespace: namespace)
        }
    }
    
    /// Get cache sizes for all namespaces
    /// - Returns: Dictionary of namespace to cache size
    public func getAllCacheSizes() async -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        
        for namespace in namespaces {
            sizes[namespace] = await getCacheSize(namespace: namespace)
        }
        
        return sizes
    }
    
    /// Get total cache size across all namespaces
    /// - Returns: Total size in bytes
    public func getTotalCacheSize() async -> Int64 {
        let sizes = await getAllCacheSizes()
        return sizes.values.reduce(0, +)
    }
    
    // MARK: - Namespace Management
    
    /// Get all available namespaces
    /// - Returns: Set of namespace names
    public var availableNamespaces: Set<String> {
        return namespaces
    }
    
    /// Check if a namespace is available
    /// - Parameter namespace: Namespace to check
    /// - Returns: True if namespace exists
    public func hasNamespace(_ namespace: String) -> Bool {
        return namespaces.contains(namespace)
    }
    
    /// Get diagnostic information about storage usage
    /// - Returns: Storage diagnostics
    public func getDiagnostics() async -> StorageDiagnostics {
        let cacheSizes = await getAllCacheSizes()
        let totalSize = cacheSizes.values.reduce(0, +)
        
        var tileCounts: [String: Int] = [:]
        for namespace in namespaces {
            tileCounts[namespace] = await getTileCount(namespace: namespace)
        }
        
        return StorageDiagnostics(
            namespaceCount: namespaces.count,
            namespaces: Array(namespaces).sorted(),
            cacheSizes: cacheSizes,
            tileCounts: tileCounts,
            totalCacheSize: totalSize,
            totalTileCount: tileCounts.values.reduce(0, +),
            baseDirectory: baseDirectory.path
        )
    }
    
    // MARK: - Private Methods
    
    private func tileURL(for coordinate: TileCoordinate, namespace: String) -> URL {
        // Structure: baseDir/namespace/zoom/x/y.png
        return baseDirectory
            .appendingPathComponent(namespace)
            .appendingPathComponent("\(coordinate.zoom)")
            .appendingPathComponent("\(coordinate.x)")
            .appendingPathComponent("\(coordinate.y).png")
    }
    
    private func validateNamespace(_ namespace: String) throws {
        guard namespaces.contains(namespace) else {
            throw MultiNamespaceStorageError.namespaceNotFound(namespace)
        }
    }
    
    private func isValidNamespace(_ namespace: String) -> Bool {
        // Check for valid directory name
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return !namespace.isEmpty &&
               namespace.rangeOfCharacter(from: invalidChars) == nil &&
               !namespace.hasPrefix(".") &&
               namespace.count <= 255
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

// MARK: - Supporting Types

/// Errors specific to MultiNamespaceStorage
public enum MultiNamespaceStorageError: Error, LocalizedError {
    case noNamespaces
    case invalidNamespace(String)
    case namespaceNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .noNamespaces:
            return "No namespaces provided"
        case .invalidNamespace(let namespace):
            return "Invalid namespace: '\(namespace)'"
        case .namespaceNotFound(let namespace):
            return "Namespace not found: '\(namespace)'"
        }
    }
}

/// Diagnostic information about storage usage
public struct StorageDiagnostics {
    public let namespaceCount: Int
    public let namespaces: [String]
    public let cacheSizes: [String: Int64]
    public let tileCounts: [String: Int]
    public let totalCacheSize: Int64
    public let totalTileCount: Int
    public let baseDirectory: String
    
    public var formattedTotalSize: String {
        return ByteCountFormatter().string(fromByteCount: totalCacheSize)
    }
    
    public var summary: String {
        var summary = """
            Storage Diagnostics:
            - Namespaces: \(namespaceCount)
            - Total Cache Size: \(formattedTotalSize)
            - Total Tiles: \(totalTileCount)
            - Base Directory: \(baseDirectory)
            
            Per-Namespace Details:
            """
        
        for namespace in namespaces.sorted() {
            let size = ByteCountFormatter().string(fromByteCount: cacheSizes[namespace] ?? 0)
            let count = tileCounts[namespace] ?? 0
            summary += "\n  \(namespace): \(size) (\(count) tiles)"
        }
        
        return summary
    }
}