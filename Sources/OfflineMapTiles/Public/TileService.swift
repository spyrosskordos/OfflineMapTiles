import Foundation
import CoreLocation

/// Unified tile service that handles multiple tile server URLs with proper isolation
/// The single, straightforward API for all offline map tile operations
public final class TileService: @unchecked Sendable {
    
    // MARK: - Private Properties
    
    private let serverConfigs: [String: TileServerConfig]
    private let storage: MultiNamespaceStorage
    private let downloader: TileDownloader
    private let calculator: TileCalculator
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create a tile service with multiple server configurations
    /// - Parameter serverConfigs: Dictionary of server configurations (name -> config)
    public init(serverConfigs: [String: TileServerConfig]) throws {
        guard !serverConfigs.isEmpty else {
            throw TileServiceError.noConfigurations
        }
        
        self.serverConfigs = serverConfigs
        self.logger = Logger.shared
        self.calculator = TileCalculator()
        
        // Create multi-namespace storage that isolates each server's tiles
        self.storage = try MultiNamespaceStorage(namespaces: Array(serverConfigs.keys))
        
        // Create downloader
        self.downloader = TileDownloader(
            httpConfig: BasicHTTPConfiguration(),
            logger: logger
        )
        
        logger.info("TileService initialized with \(serverConfigs.count) server configurations")
    }
    
    /// Convenience initializer with server config array
    /// - Parameter configs: Array of server configurations
    public convenience init(configs: [TileServerConfig]) throws {
        let configDict = Dictionary(uniqueKeysWithValues: configs.map { ($0.name, $0) })
        try self.init(serverConfigs: configDict)
    }
    
    // MARK: - Core Multi-Server API
    
    /// Get a tile from a specific server configuration
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - serverName: The server configuration name
    /// - Returns: Tile data if successful, nil if failed
    public func getTile(for coordinate: TileCoordinate, from serverName: String) async -> Data? {
        guard let serverConfig = serverConfigs[serverName] else {
            logger.warning("Server '\(serverName)' not found. Available: \(availableServers)")
            return nil
        }
        
        // Check cache first
        if let cachedTile = await storage.getTile(coordinate: coordinate, namespace: serverName) {
            logger.debug("Retrieved cached tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) from '\(serverName)'")
            return cachedTile
        }
        
        // Download if not cached
        return await downloadAndCacheTile(coordinate: coordinate, serverConfig: serverConfig)
    }
    
    /// Get a tile with fallback - tries servers in order until one succeeds
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - serverPriority: Order of servers to try (defaults to all servers)
    /// - Returns: Tuple with tile data and the server name that provided it
    public func getTileWithFallback(
        for coordinate: TileCoordinate,
        serverPriority: [String]? = nil
    ) async -> (data: Data?, serverName: String?) {
        let serversToTry = serverPriority ?? Array(serverConfigs.keys)
        
        for serverName in serversToTry {
            if let tileData = await getTile(for: coordinate, from: serverName) {
                return (tileData, serverName)
            }
        }
        
        return (nil, nil)
    }
    
    /// Download a tile from a specific server (bypassing cache check)
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - serverName: The server configuration name
    /// - Returns: Tile data if successful, nil if failed
    public func downloadTile(for coordinate: TileCoordinate, from serverName: String) async -> Data? {
        guard let serverConfig = serverConfigs[serverName] else {
            logger.warning("Server '\(serverName)' not found")
            return nil
        }
        
        return await downloadAndCacheTile(coordinate: coordinate, serverConfig: serverConfig)
    }
    
    /// Get cached tile without downloading
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - serverName: The server configuration name
    /// - Returns: Cached tile data if available, nil if not cached
    public func getCachedTile(for coordinate: TileCoordinate, from serverName: String) async -> Data? {
        return await storage.getTile(coordinate: coordinate, namespace: serverName)
    }
    
    /// Check if a tile exists in cache for a specific server
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - serverName: The server configuration name
    /// - Returns: True if tile exists in cache
    public func hasCachedTile(for coordinate: TileCoordinate, from serverName: String) async -> Bool {
        return await storage.hasTile(coordinate: coordinate, namespace: serverName)
    }
    
    /// Get all servers that have the specified tile cached
    /// - Parameter coordinate: The tile coordinate
    /// - Returns: Array of server names that have this tile
    public func getServersWithTile(for coordinate: TileCoordinate) async -> [String] {
        var serversWithTile: [String] = []
        
        for serverName in serverConfigs.keys {
            if await hasCachedTile(for: coordinate, from: serverName) {
                serversWithTile.append(serverName)
            }
        }
        
        return serversWithTile
    }
    
    // MARK: - Batch Operations
    
    /// Download tiles for multiple servers simultaneously
    /// - Parameters:
    ///   - bounds: Geographic boundaries
    ///   - zoomLevel: Zoom level to download
    ///   - serverNames: Servers to download from (defaults to all)
    ///   - progressHandler: Optional progress callback per server
    /// - Returns: Download results per server
    @discardableResult
    public func downloadTiles(
        in bounds: MapBounds,
        at zoomLevel: Int,
        from serverNames: [String]? = nil,
        progressHandler: (@Sendable (String, DownloadProgress) -> Void)? = nil
    ) async -> [String: Int] {
        let serversToUse = serverNames ?? Array(serverConfigs.keys)
        let coordinates = calculator.calculateTilesForZoom(bounds: bounds, zoom: zoomLevel)
        
        return await downloadTiles(
            coordinates: coordinates,
            from: serversToUse,
            progressHandler: progressHandler
        )
    }
    
    /// Download specific tiles from multiple servers
    /// - Parameters:
    ///   - coordinates: Array of tile coordinates
    ///   - serverNames: Servers to download from (defaults to all)
    ///   - progressHandler: Optional progress callback per server
    /// - Returns: Download results per server (successful tile count)
    @discardableResult
    public func downloadTiles(
        coordinates: [TileCoordinate],
        from serverNames: [String]? = nil,
        progressHandler: (@Sendable (String, DownloadProgress) -> Void)? = nil
    ) async -> [String: Int] {
        let serversToUse = serverNames ?? Array(serverConfigs.keys)
        var results: [String: Int] = [:]
        
        logger.info("Starting batch download: \(coordinates.count) tiles from \(serversToUse.count) servers")
        
        // Download from each server concurrently
        await withTaskGroup(of: (String, Int).self) { group in
            for serverName in serversToUse {
                guard let serverConfig = serverConfigs[serverName] else { continue }
                
                // Capture the progress handler safely
                let capturedProgressHandler = progressHandler
                
                group.addTask { [weak self, serverName, capturedProgressHandler] in
                    guard let self = self else { return (serverName, 0) }
                    
                    return await (serverName, self.downloadTilesForServer(
                        coordinates: coordinates,
                        serverName: serverName,
                        serverConfig: serverConfig,
                        progressHandler: { @Sendable progress in
                            capturedProgressHandler?(serverName, progress)
                        }
                    ))
                }
            }
            
            for await (serverName, successCount) in group {
                results[serverName] = successCount
            }
        }
        
        let totalSuccessful = results.values.reduce(0, +)
        logger.info("Batch download completed: \(totalSuccessful) total tiles across \(results.count) servers")
        
        return results
    }
    
    // MARK: - Cache Management
    
    /// Get cache size for a specific server
    /// - Parameter serverName: The server name
    /// - Returns: Cache size in bytes
    public func getCacheSize(for serverName: String) async -> Int64 {
        return await storage.getCacheSize(namespace: serverName)
    }
    
    /// Get cache sizes for all servers
    /// - Returns: Dictionary of server names to cache sizes
    public func getCacheSizes() async -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        
        for serverName in serverConfigs.keys {
            sizes[serverName] = await getCacheSize(for: serverName)
        }
        
        return sizes
    }
    
    /// Get total cache size across all servers
    /// - Returns: Total cache size in bytes
    public func getTotalCacheSize() async -> Int64 {
        let sizes = await getCacheSizes()
        return sizes.values.reduce(0, +)
    }
    
    /// Clear cache for a specific server
    /// - Parameter serverName: The server name
    public func clearCache(for serverName: String) async throws {
        try await storage.clearCache(namespace: serverName)
        logger.info("Cache cleared for server '\(serverName)'")
    }
    
    /// Clear cache for multiple servers
    /// - Parameter serverNames: Server names to clear (defaults to all)
    public func clearCache(for serverNames: [String]? = nil) async throws {
        let serversToClear = serverNames ?? Array(serverConfigs.keys)
        
        for serverName in serversToClear {
            try await clearCache(for: serverName)
        }
    }
    
    /// Get detailed cache statistics
    /// - Returns: Cache statistics per server
    public func getCacheStats() async -> [String: CacheStats] {
        var stats: [String: CacheStats] = [:]
        
        for (serverName, _) in serverConfigs {
            let size = await getCacheSize(for: serverName)
            let tileCount = await storage.getTileCount(namespace: serverName)
            
            stats[serverName] = CacheStats(
                serverName: serverName,
                totalSizeBytes: size,
                tileCount: tileCount,
                averageTileSize: tileCount > 0 ? Int64(size) / Int64(tileCount) : 0
            )
        }
        
        return stats
    }
    
    // MARK: - Server Information
    
    /// Get all available server names
    public var availableServers: [String] {
        return Array(serverConfigs.keys).sorted()
    }
    
    /// Get server configuration by name
    /// - Parameter serverName: The server name
    /// - Returns: Server configuration if found
    public func getServerConfig(_ serverName: String) -> TileServerConfig? {
        return serverConfigs[serverName]
    }
    
    /// Get all server configurations
    /// - Returns: Dictionary of all server configurations
    public func getAllServerConfigs() -> [String: TileServerConfig] {
        return serverConfigs
    }
    
    // MARK: - Diagnostics
    
    /// Get diagnostic information about tile storage and potential conflicts
    /// - Returns: Diagnostic information
    public func getDiagnostics() async -> TileServiceDiagnostics {
        let cacheSizes = await getCacheSizes()
        let totalSize = cacheSizes.values.reduce(0, +)
        
        return TileServiceDiagnostics(
            serverCount: serverConfigs.count,
            serverNames: availableServers,
            cacheSizes: cacheSizes,
            totalCacheSize: totalSize,
            hasIsolatedNamespaces: true, // Always true with this architecture
            conflictsPossible: false // Conflicts are prevented by design
        )
    }
    
    // MARK: - Private Methods
    
    private func downloadAndCacheTile(coordinate: TileCoordinate, serverConfig: TileServerConfig) async -> Data? {
        // Validate coordinate
        guard serverConfig.isCoordinateValid(coordinate) else {
            logger.warning("Coordinate (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) is invalid for '\(serverConfig.name)'")
            return nil
        }
        
        // Generate URL
        let urlString = serverConfig.tileURL(for: coordinate)
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL generated: \(urlString)")
            return nil
        }
        
        // Download
        let result = await downloader.downloadTile(from: url)
        
        switch result {
        case .success(let data):
            // Cache the downloaded tile in the server's namespace
            do {
                try await storage.saveTile(data: data, coordinate: coordinate, namespace: serverConfig.name)
                logger.debug("Downloaded and cached tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) from '\(serverConfig.name)'")
                return data
            } catch {
                logger.error("Failed to cache tile: \(error.localizedDescription)")
                return data // Return the data even if caching failed
            }
            
        case .failure(let error):
            logger.warning("Failed to download tile (\(coordinate.x), \(coordinate.y), \(coordinate.zoom)) from '\(serverConfig.name)': \(error.localizedDescription)")
            return nil
        }
    }
    
    private func downloadTilesForServer(
        coordinates: [TileCoordinate],
        serverName: String,
        serverConfig: TileServerConfig,
        progressHandler: (@Sendable (DownloadProgress) -> Void)?
    ) async -> Int {
        let total = coordinates.count
        var completed = 0
        var successful = 0
        
        // Filter valid coordinates for this server
        let validCoordinates = coordinates.filter { serverConfig.isCoordinateValid($0) }
        let validTotal = validCoordinates.count
        
        if validTotal != total {
            logger.info("Server '\(serverName)': \(validTotal)/\(total) coordinates are valid")
        }
        
        // Download with concurrency control
        await withTaskGroup(of: Bool.self) { group in
            let semaphore = AsyncSemaphore(value: serverConfig.httpConfiguration.maxConcurrentOperations)
            
            for coordinate in validCoordinates {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    guard let self = self else { return false }
                    
                    let success = await self.downloadAndCacheTile(coordinate: coordinate, serverConfig: serverConfig) != nil
                    return success
                }
            }
            
            for await success in group {
                completed += 1
                if success {
                    successful += 1
                }
                
                // Report progress
                let progress = DownloadProgress(
                    totalTiles: validTotal,
                    downloadedTiles: successful,
                    failedTiles: completed - successful
                )
                progressHandler?(progress)
            }
        }
        
        logger.info("Server '\(serverName)': \(successful)/\(validTotal) tiles downloaded successfully")
        return successful
    }
}

// MARK: - Supporting Types

/// Errors specific to TileService
public enum TileServiceError: Error, LocalizedError {
    case noConfigurations
    case serverNotFound(String)
    case invalidCoordinate(TileCoordinate, String)
    
    public var errorDescription: String? {
        switch self {
        case .noConfigurations:
            return "No server configurations provided"
        case .serverNotFound(let name):
            return "Server '\(name)' not found"
        case .invalidCoordinate(let coord, let server):
            return "Coordinate (\(coord.x), \(coord.y), \(coord.zoom)) is invalid for server '\(server)'"
        }
    }
}

/// Diagnostic information for the tile service
public struct TileServiceDiagnostics {
    public let serverCount: Int
    public let serverNames: [String]
    public let cacheSizes: [String: Int64]
    public let totalCacheSize: Int64
    public let hasIsolatedNamespaces: Bool
    public let conflictsPossible: Bool
    
    public var formattedTotalSize: String {
        return ByteCountFormatter().string(fromByteCount: totalCacheSize)
    }
    
    public var summary: String {
        var summary = """
            Tile Service Diagnostics:
            - Server Count: \(serverCount)
            - Total Cache Size: \(formattedTotalSize)
            - Isolated Namespaces: \(hasIsolatedNamespaces ? "✅ Yes" : "❌ No")
            - Conflicts Possible: \(conflictsPossible ? "⚠️ Yes" : "✅ No")
            
            Per-Server Cache Sizes:
            """
        
        for (server, size) in cacheSizes.sorted(by: { $0.key < $1.key }) {
            let formattedSize = ByteCountFormatter().string(fromByteCount: size)
            summary += "\n  \(server): \(formattedSize)"
        }
        
        return summary
    }
}