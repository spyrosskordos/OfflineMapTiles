import Foundation
import CoreLocation

public final class OfflineMapTiles: @unchecked Sendable {
    public weak var delegate: OfflineMapTilesDelegate?
    
    private let tileServerConfig: TileServerConfig
    private let storageManager: TileStorageManager
    private let downloadManager: TileDownloadManager
    private let tileCalculator: TileCalculator
    private let sizeEstimator: TileSizeEstimator
    
    private var currentDownloadTask: Task<DownloadResult, Error>?
    
    public init(tileServerConfig: TileServerConfig = .openStreetMap, 
                storageDirectory: URL? = nil) throws {
        self.tileServerConfig = tileServerConfig
        self.storageManager = try TileStorageManager(storageDirectory: storageDirectory, tileFormat: tileServerConfig.format)
        self.downloadManager = TileDownloadManager(retryPolicy: tileServerConfig.retryPolicy, customHeaders: tileServerConfig.customHeaders)
        self.tileCalculator = TileCalculator()
        self.sizeEstimator = TileSizeEstimator(tileCalculator: tileCalculator)
    }
    
    // Convenience initializer for backward compatibility
    public convenience init(tileServerURL: String, storageDirectory: URL? = nil) throws {
        let config = TileServerConfig(
            name: "Custom",
            baseURL: tileServerURL,
            format: tileServerURL.contains(".jpg") ? .jpg : (tileServerURL.contains(".jpeg") ? .jpeg : .png)
        )
        try self.init(tileServerConfig: config, storageDirectory: storageDirectory)
    }
    
    public func estimateDownloadSize(for bounds: MapBounds, zoomRange: ZoomRange) throws -> TileSizeEstimation {
        return try sizeEstimator.estimateDownloadSize(for: bounds, zoomRange: zoomRange, tileFormat: tileServerConfig.format)
    }
    
    public func downloadTiles(for bounds: MapBounds, zoomRange: ZoomRange, skipSizeValidation: Bool = false) async throws -> DownloadResult {
        guard bounds.northEast.latitude > bounds.southWest.latitude &&
              bounds.northEast.longitude > bounds.southWest.longitude else {
            throw OfflineMapTilesError.invalidBounds
        }
        
        // Estimate and validate download size unless explicitly skipped
        if !skipSizeValidation {
            let estimation = try estimateDownloadSize(for: bounds, zoomRange: zoomRange)
            do {
                try sizeEstimator.validateDownloadSize(estimation)
            } catch let error as SizeEstimationError {
                throw OfflineMapTilesError.downloadSizeExceedsLimit(error)
            }
        }
        
        currentDownloadTask?.cancel()
        
        let task = Task<DownloadResult, Error> { [self] in
            let tiles = tileCalculator.calculateTiles(for: bounds, zoomRange: zoomRange)
            return try await performDownload(tiles: tiles)
        }
        
        currentDownloadTask = task
        return try await task.value
    }
    
    public func cancelDownload() {
        currentDownloadTask?.cancel()
        downloadManager.cancelAll()
    }
    
    public func getTileData(for coordinate: TileCoordinate) async -> Data? {
        return await storageManager.getTile(coordinate: coordinate)
    }
    
    public func clearCache() async throws {
        try await storageManager.clearAll()
    }
    
    public func getCacheSize() async -> Int64 {
        return await storageManager.getCacheSize()
    }
    
    private func performDownload(tiles: [TileCoordinate]) async throws -> DownloadResult {
        let startTime = Date()
        var downloadedCount = 0
        var failedCount = 0
        
        let totalTiles = tiles.count
        
        try Task.checkCancellation()
        
        try await withThrowingTaskGroup(of: (TileCoordinate, Result<Data, Error>).self) { group in
            let semaphore = AsyncSemaphore(value: 8) // Limit concurrent downloads
            
            for tile in tiles {
                group.addTask { [self] in
                    await semaphore.wait()
                    defer { 
                        Task { await semaphore.signal() }
                    }
                    
                    let result = await self.downloadSingleTile(tile)
                    return (tile, result)
                }
            }
            
            for try await (tile, result) in group {
                switch result {
                case .success(let data):
                    do {
                        try await storageManager.saveTile(coordinate: tile, data: data)
                        downloadedCount += 1
                    } catch {
                        failedCount += 1
                    }
                case .failure:
                    failedCount += 1
                }
                
                let progress = DownloadProgress(
                    totalTiles: totalTiles,
                    downloadedTiles: downloadedCount,
                    failedTiles: failedCount,
                    currentTile: tile
                )
                
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.delegate?.offlineMapTiles(self, didUpdateProgress: progress)
                }
                
                try Task.checkCancellation()
            }
        }
        
        let downloadTime = Date().timeIntervalSince(startTime)
        let averageSpeed = downloadTime > 0 ? Double(downloadedCount) / downloadTime : 0.0
        
        return DownloadResult(
            totalTiles: totalTiles,
            successfulTiles: downloadedCount,
            failedTiles: failedCount,
            downloadTime: downloadTime,
            averageDownloadSpeed: averageSpeed
        )
    }
    
    private func downloadSingleTile(_ tile: TileCoordinate) async -> Result<Data, Error> {
        // Validate zoom level against server constraints
        guard tile.zoom >= tileServerConfig.minZoom && tile.zoom <= tileServerConfig.maxZoom else {
            return .failure(OfflineMapTilesError.invalidZoomLevel)
        }
        
        let urlString = tileServerConfig.tileURL(for: tile)
        
        guard let url = URL(string: urlString) else {
            return .failure(OfflineMapTilesError.invalidTileServer)
        }
        
        return await downloadManager.downloadTile(from: url)
    }
    
    public var serverInfo: TileServerConfig {
        return tileServerConfig
    }
    
    public func downloadTiles(for bounds: MapBounds, zoomRange: ZoomRange, maxDownloadSizeMB: Int) async throws -> DownloadResult {
        let estimation = try estimateDownloadSize(for: bounds, zoomRange: zoomRange)
        let customLimitBytes = Int64(maxDownloadSizeMB) * 1024 * 1024
        
        do {
            try sizeEstimator.validateDownloadSize(estimation, customLimit: customLimitBytes)
        } catch let error as SizeEstimationError {
            throw OfflineMapTilesError.downloadSizeExceedsLimit(error)
        }
        
        return try await downloadTiles(for: bounds, zoomRange: zoomRange, skipSizeValidation: true)
    }
}