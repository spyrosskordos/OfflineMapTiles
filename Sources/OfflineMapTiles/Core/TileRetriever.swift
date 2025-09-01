import Foundation
import CoreLocation

/// Responsible for retrieving stored tiles from cache/storage
/// Follows Single Responsibility Principle - only handles tile retrieval
public final class TileRetriever: @unchecked Sendable {
    
    private let storage: TileStorageProtocol
    private let configs: [TileServerConfig]
    
    public init(storage: TileStorageProtocol, configs: [TileServerConfig]) {
        self.storage = storage
        self.configs = configs
    }
    
    /// Retrieve a tile for a specific coordinate and configuration
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Tile data if found
    public func getTile(coordinate: TileCoordinate, configName: String? = nil) async -> Data? {
        let targetConfigName: String?
        
        if let configName = configName {
            // Validate that the requested configuration exists
            guard configs.contains(where: { $0.name == configName }) else {
                print("Warning: Requested config '\(configName)' not found in TileRetriever. Available configs: \(configs.map { $0.name }.joined(separator: ", "))")
                return nil
            }
            targetConfigName = configName
        } else {
            // For single config, use the config name; for multiple, warn and use first
            if configs.count > 1 {
                print("Warning: Multiple configs available but none specified. Using '\(configs.first?.name ?? "unknown")'. Available: \(configs.map { $0.name }.joined(separator: ", "))")
            }
            targetConfigName = configs.first?.name
        }
        
        return await storage.getTile(coordinate: coordinate, configName: targetConfigName)
    }
    
    /// Retrieve tiles for multiple coordinates
    /// - Parameters:
    ///   - coordinates: Array of tile coordinates
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Dictionary mapping coordinates to tile data
    public func getTiles(coordinates: [TileCoordinate], configName: String? = nil) async -> [TileCoordinate: Data] {
        var results: [TileCoordinate: Data] = [:]
        
        await withTaskGroup(of: (TileCoordinate, Data?).self) { group in
            for coordinate in coordinates {
                group.addTask { [weak self] in
                    let data = await self?.getTile(coordinate: coordinate, configName: configName)
                    return (coordinate, data)
                }
            }
            
            for await (coordinate, data) in group {
                if let data = data {
                    results[coordinate] = data
                }
            }
        }
        
        return results
    }
    
    /// Check if a tile exists in storage
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: True if tile exists
    public func hasTile(coordinate: TileCoordinate, configName: String? = nil) async -> Bool {
        let data = await getTile(coordinate: coordinate, configName: configName)
        return data != nil
    }
    
    /// Get tile metadata (size, modification date, etc.)
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Tile metadata if available
    public func getTileMetadata(coordinate: TileCoordinate, configName: String? = nil) async -> TileMetadata? {
        // This would be implemented based on storage capabilities
        // For now, basic metadata from existence check
        let data = await getTile(coordinate: coordinate, configName: configName)
        guard let data = data else { return nil }
        
        return TileMetadata(
            coordinate: coordinate,
            configName: configName ?? configs.first?.name ?? "unknown",
            size: data.count,
            modificationDate: Date() // Would come from storage in real implementation
        )
    }
    
    /// Get all available tiles for a configuration
    /// - Parameter configName: Name of the configuration
    /// - Returns: Array of available tile coordinates
    public func getAvailableTiles(configName: String? = nil) async -> [TileCoordinate] {
        // This would require storage-level support to list tiles
        // Implementation would depend on the storage backend
        return []
    }
    
    /// Get storage statistics for configurations
    /// - Returns: Storage statistics per configuration
    public func getStorageStats() async -> [String: TileStorageStats] {
        var stats: [String: TileStorageStats] = [:]
        
        for config in configs {
            // This would be implemented with actual storage queries
            stats[config.name] = TileStorageStats(
                configName: config.name,
                tileCount: 0, // Would query storage
                totalSize: 0,  // Would query storage
                lastAccessed: Date()
            )
        }
        
        return stats
    }
}

// MARK: - Supporting Types

/// Metadata about a stored tile
public struct TileMetadata: Sendable {
    public let coordinate: TileCoordinate
    public let configName: String
    public let size: Int
    public let modificationDate: Date
}

/// Storage statistics for a configuration
public struct TileStorageStats: Sendable {
    public let configName: String
    public let tileCount: Int
    public let totalSize: Int64
    public let lastAccessed: Date
    
    public var formattedSize: String {
        return ByteCountFormatter().string(fromByteCount: totalSize)
    }
}