import Foundation
import CoreLocation

/// Simple tile service for downloading and caching tiles
/// Uses key-based storage for simplicity
public final class TileService: @unchecked Sendable {
    
    // MARK: - Private Properties
    
    private let storage: TileStorage
    private let downloader: TileDownloader
    private let calculator: TileCalculator
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create a simple tile service
    public init() throws {
        self.logger = Logger.shared
        self.calculator = TileCalculator()
        self.storage = try TileStorage()
        
        // Create downloader
        self.downloader = TileDownloader(
            httpConfig: BasicHTTPConfiguration(),
            logger: logger
        )
        
        logger.info("TileService initialized")
    }
    
    // MARK: - Core API
    
    /// Get cached tile using key
    /// - Parameter key: Tile key
    /// - Returns: Cached tile data if available, nil if not cached
    public func getTile(key: String) async -> Data? {
        return await storage.getTile(key: key)
    }
    
    /// Download tile from URL and cache using key
    /// - Parameters:
    ///   - coordinate: Tile coordinate
    ///   - url: Tile URL to download from
    ///   - key: Key to store tile under (optional, generates from coordinate if not provided)
    /// - Returns: Tile data if successful, nil if failed
    public func downloadTile(for coordinate: TileCoordinate, from url: String, key: String? = nil) async -> Data? {
        guard let tileURL = URL(string: url) else {
            logger.error("Invalid URL: \(url)")
            return nil
        }
        
        let result = await downloader.downloadTile(from: tileURL)
        
        switch result {
        case .success(let data):
            // Generate key if not provided
            let tileKey = key ?? TileKey.generateKey(z: coordinate.zoom, x: coordinate.x, y: coordinate.y, urlTemplate: url)
            
            do {
                try await storage.saveTile(data: data, key: tileKey)
                logger.debug("Downloaded and cached tile with key '\(tileKey)'")
                return data
            } catch {
                logger.error("Failed to cache tile: \(error.localizedDescription)")
                return data // Return the data even if caching failed
            }
            
        case .failure(let error):
            logger.warning("Failed to download tile from '\(url)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if tile exists in cache using key
    /// - Parameter key: Tile key
    /// - Returns: True if tile exists in cache
    public func hasCachedTile(key: String) async -> Bool {
        return await storage.hasTile(key: key)
    }
    
    /// Delete a specific tile using key
    /// - Parameter key: Tile key
    public func deleteTile(key: String) async throws {
        try await storage.deleteTile(key: key)
    }
    
    // MARK: - Batch Operations
    
    /// Download tiles for an area
    /// - Parameters:
    ///   - bounds: Geographic boundaries
    ///   - zoomLevel: Zoom level to download
    ///   - urlTemplate: URL template for tiles (with {z}, {x}, {y} placeholders)
    ///   - progressHandler: Optional progress callback
    /// - Returns: Number of successful downloads
    @discardableResult
    public func downloadTiles(
        in bounds: MapBounds,
        at zoomLevel: Int,
        from urlTemplate: String,
        progressHandler: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async -> Int {
        let coordinates = calculator.calculateTilesForZoom(bounds: bounds, zoom: zoomLevel)
        return await downloadTiles(coordinates: coordinates, from: urlTemplate, progressHandler: progressHandler)
    }
    
    /// Download specific tiles
    /// - Parameters:
    ///   - coordinates: Array of tile coordinates
    ///   - urlTemplate: URL template for tiles (with {z}, {x}, {y} placeholders)
    ///   - progressHandler: Optional progress callback
    /// - Returns: Number of successful downloads
    @discardableResult
    public func downloadTiles(
        coordinates: [TileCoordinate],
        from urlTemplate: String,
        progressHandler: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async -> Int {
        let total = coordinates.count
        var completed = 0
        var successful = 0
        
        logger.info("Starting download: \(coordinates.count) tiles from \(urlTemplate)")
        
        // Download with concurrency control
        await withTaskGroup(of: Bool.self) { group in
            let semaphore = AsyncSemaphore(value: 10) // Limit concurrent downloads
            
            for coordinate in coordinates {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    guard let self = self else { return false }
                    
                    let url = urlTemplate
                        .replacingOccurrences(of: "{z}", with: "\(coordinate.zoom)")
                        .replacingOccurrences(of: "{x}", with: "\(coordinate.x)")
                        .replacingOccurrences(of: "{y}", with: "\(coordinate.y)")
                    
                    let success = await self.downloadTile(for: coordinate, from: url) != nil
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
                    totalTiles: total,
                    downloadedTiles: successful,
                    failedTiles: completed - successful
                )
                progressHandler?(progress)
            }
        }
        
        logger.info("Download completed: \(successful)/\(total) tiles downloaded successfully")
        return successful
    }
    
    // MARK: - Cache Management
    
    /// Get total cache size
    /// - Returns: Cache size in bytes
    public func getCacheSize() async -> Int64 {
        return await storage.getCacheSize()
    }
    
    /// Get total tile count
    /// - Returns: Number of cached tiles
    public func getTileCount() async -> Int {
        return await storage.getTileCount()
    }
    
    /// Clear all cached tiles
    public func clearCache() async throws {
        try await storage.clearCache()
        logger.info("Cache cleared")
    }
    
}

// MARK: - Supporting Types

/// Errors specific to TileService
public enum TileServiceError: Error, LocalizedError {
    case invalidURL(String)
    case storageError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: '\(url)'"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        }
    }
}