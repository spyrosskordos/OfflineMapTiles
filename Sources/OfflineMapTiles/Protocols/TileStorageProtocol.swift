import Foundation

/// Protocol defining tile storage operations
public protocol TileStorageProtocol: Sendable {
    /// Saves tile data for the given coordinate
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - data: The tile data to save
    ///   - configName: Optional config name for multi-config storage
    func saveTile(coordinate: TileCoordinate, data: Data, configName: String?) async throws
    
    /// Retrieves tile data for the given coordinate
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Optional config name for multi-config storage
    /// - Returns: The tile data if found, nil otherwise
    func getTile(coordinate: TileCoordinate, configName: String?) async -> Data?
    
    /// Checks if a tile exists for the given coordinate
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Optional config name for multi-config storage
    /// - Returns: True if the tile exists, false otherwise
    func tileExists(coordinate: TileCoordinate, configName: String?) async -> Bool
    
    /// Clears all cached tiles
    func clearAll() async throws
    
    /// Gets the total cache size in bytes
    /// - Returns: The cache size in bytes
    func getCacheSize() async -> Int64
    
    /// Clears cache for a specific configuration
    /// - Parameter configName: The configuration name to clear
    func clearCache(for configName: String) async throws
}

/// Protocol for cache management policies
public protocol CacheManagementProtocol: Sendable {
    var maxCacheSize: Int64 { get }
    var cleanupThreshold: Double { get }
    
    /// Determines if cache cleanup is needed
    /// - Parameter currentSize: Current cache size
    /// - Returns: True if cleanup is needed
    func shouldCleanup(currentSize: Int64) -> Bool
    
    /// Gets the target size after cleanup
    /// - Returns: Target size in bytes
    func getTargetSize() -> Int64
}