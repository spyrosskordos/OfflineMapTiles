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
    private var currentDownloadTask: Task<Int, Never>?
    
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
    
    /// Get cached tile by coordinates and URL template
    /// - Parameters:
    ///   - x: Tile X coordinate
    ///   - y: Tile Y coordinate
    ///   - z: Zoom level
    ///   - urlTemplate: URL template used for the tile
    /// - Returns: Cached tile data if available, nil if not cached
    public func getTile(x: Int, y: Int, z: Int, urlTemplate: String) async -> Data? {
        let key = TileKey.generateKey(z: z, x: x, y: y, urlTemplate: urlTemplate)
        return await storage.getTile(key: key)
    }
    
    /// Download tiles for map bounds and zoom range
    /// - Parameters:
    ///   - bounds: Geographic boundaries to download
    ///   - zoomRange: Range of zoom levels to download
    ///   - urlTemplate: URL template for tiles (with {z}, {x}, {y} placeholders)
    ///   - progressHandler: Optional progress callback
    /// - Returns: Number of successful downloads
    @discardableResult
    public func download(
        bounds: MapBounds,
        zoomRange: ClosedRange<Int>,
        urlTemplate: String,
        progressHandler: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async -> Int {
        // Cancel any existing download
        currentDownloadTask?.cancel()
        
        let downloadTask = Task {
            // Calculate total tiles across all zoom levels
            var allCoordinates: [TileCoordinate] = []
            for zoom in zoomRange {
                let coordinates = calculator.calculateTilesForZoom(bounds: bounds, zoom: zoom)
                allCoordinates.append(contentsOf: coordinates)
            }
            
            let totalTiles = allCoordinates.count
            var totalCompleted = 0
            var totalSuccessful = 0
            
            logger.info("Starting download: \(totalTiles) tiles across zoom levels \(zoomRange.lowerBound)-\(zoomRange.upperBound)")
            
            // Download all tiles with total progress tracking
            await withTaskGroup(of: Bool.self) { group in
                let semaphore = AsyncSemaphore(value: 10) // Limit concurrent downloads
                
                for coordinate in allCoordinates {
                    if Task.isCancelled { break }
                    
                    group.addTask { [weak self] in
                        await semaphore.wait()
                        defer { Task { await semaphore.signal() } }
                        
                        guard let self = self else { return false }
                        guard !Task.isCancelled else { return false }
                        
                        let isTMSFormat = urlTemplate.contains("{-y}")
                        let y = isTMSFormat ? (1 << coordinate.zoom) - 1 - coordinate.y : coordinate.y
                        
                        let urlString = urlTemplate
                            .replacingOccurrences(of: "{z}", with: String(coordinate.zoom))
                            .replacingOccurrences(of: "{x}", with: String(coordinate.x))
                            .replacingOccurrences(of: "{-y}", with: String(y))
                            .replacingOccurrences(of: "{y}", with: String(y))
                        let success = await self.downloadTile(for: coordinate, from: urlString, urlTemplate: urlTemplate) != nil
                        return success
                    }
                }
                
                for await success in group {
                    totalCompleted += 1
                    if success {
                        totalSuccessful += 1
                    }
                    
                    // Report overall progress across all zoom levels
                    let progress = DownloadProgress(
                        totalTiles: totalTiles,
                        downloadedTiles: totalSuccessful,
                        failedTiles: totalCompleted - totalSuccessful
                    )
                    progressHandler?(progress)
                }
            }
            
            logger.info("Download completed: \(totalSuccessful)/\(totalTiles) tiles downloaded successfully")
            return totalSuccessful
        }
        
        currentDownloadTask = downloadTask
        let result = await downloadTask.value
        currentDownloadTask = nil
        
        return result
    }
    
    /// Download single tile from URL and cache
    /// - Parameters:
    ///   - coordinate: Tile coordinate
    ///   - url: Tile URL to download from
    ///   - urlTemplate: Original URL template for key generation
    /// - Returns: Tile data if successful, nil if failed
    private func downloadTile(for coordinate: TileCoordinate, from url: String, urlTemplate: String) async -> Data? {
        guard let tileURL = URL(string: url) else {
            logger.error("Invalid URL: \(url)")
            return nil
        }
        
        let result = await downloader.downloadTile(from: tileURL)
        
        switch result {
        case .success(let data):
            let tileKey = TileKey.generateKey(z: coordinate.zoom, x: coordinate.x, y: coordinate.y, urlTemplate: urlTemplate)
            
            do {
                try await storage.saveTile(data: data, key: tileKey)
                logger.debug("Downloaded and cached tile with key '\(tileKey)'")
                return data
            } catch {
                logger.error("Failed to cache tile: \(error.localizedDescription)")
                return data
            }
            
        case .failure(let error):
            logger.warning("Failed to download tile from '\(url)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check if tile exists in cache by coordinates and URL template
    /// - Parameters:
    ///   - x: Tile X coordinate
    ///   - y: Tile Y coordinate
    ///   - z: Zoom level
    ///   - urlTemplate: URL template used for the tile
    /// - Returns: True if tile exists in cache
    private func hasCachedTile(x: Int, y: Int, z: Int, urlTemplate: String) async -> Bool {
        let key = TileKey.generateKey(z: z, x: x, y: y, urlTemplate: urlTemplate)
        return await storage.hasTile(key: key)
    }
    
    /// Delete a specific tile by coordinates and URL template
    /// - Parameters:
    ///   - x: Tile X coordinate
    ///   - y: Tile Y coordinate
    ///   - z: Zoom level
    ///   - urlTemplate: URL template used for the tile
    private func deleteTile(x: Int, y: Int, z: Int, urlTemplate: String) async throws {
        let key = TileKey.generateKey(z: z, x: x, y: y, urlTemplate: urlTemplate)
        try await storage.deleteTile(key: key)
    }
    
    
    // MARK: - Cache Management
    
    /// Get total cache size
    /// - Returns: Cache size in bytes
    private func getCacheSize() async -> Int64 {
        return await storage.getCacheSize()
    }
    
    /// Get total tile count
    /// - Returns: Number of cached tiles
    private func getTileCount() async -> Int {
        return await storage.getTileCount()
    }
    
    /// Clear all cached tiles
    public func clearCache() async throws {
        try await storage.clearCache()
        logger.info("Cache cleared")
    }
    
    /// Cancel all ongoing downloads
    public func cancelDownloads() {
        if let downloadTask = currentDownloadTask {
            logger.info("Cancelling ongoing download")
            downloadTask.cancel()
            currentDownloadTask = nil
        }
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
