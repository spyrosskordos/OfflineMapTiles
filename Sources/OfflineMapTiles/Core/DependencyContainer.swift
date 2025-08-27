import Foundation

/// Dependency injection container for the unified offline map tiles SDK
/// Provides centralized dependency management and configuration
public final class DependencyContainer: @unchecked Sendable {
    
    // MARK: - Properties
    
    public let storage: TileStorageProtocol
    public let tileCalculator: TileCalculatorProtocol
    public let cachePolicy: CacheManagementProtocol
    public let httpConfig: HTTPConfigurationProtocol
    
    // MARK: - Initialization
    
    public init(
        storageDirectory: URL? = nil,
        cachePolicy: CacheManagementProtocol,
        httpConfig: HTTPConfigurationProtocol
    ) {
        self.cachePolicy = cachePolicy
        self.httpConfig = httpConfig
        self.tileCalculator = DefaultTileCalculator()
        
        // Initialize storage with fallback to default directory
        let storageDir = storageDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("OfflineMapTiles")
        self.storage = try! FileSystemTileStorage(baseURL: storageDir!, cachePolicy: cachePolicy, tileFormat: .png)
    }
    
    // MARK: - Factory Methods
    
    /// Create a tile downloader for a specific configuration
    /// - Parameter config: The tile server configuration
    /// - Returns: A configured tile downloader
    public func createDownloader(for config: TileServerConfigProtocol) -> TileDownloaderProtocol {
        return ImprovedTileDownloadManager(
            httpConfig: config.httpConfiguration,
            retryPolicy: config.retryPolicy
        )
    }
    
    /// Create a tile storage manager wrapper
    /// - Returns: A wrapper around the storage protocol
    public func createStorageWrapper() -> TileStorageWrapper {
        return TileStorageWrapper(storage: storage)
    }
    
    /// Create a size estimator
    /// - Returns: A configured tile size estimator
    public func createSizeEstimator() -> TileSizeEstimator {
        return TileSizeEstimator(tileCalculator: tileCalculator)
    }
    
    /// Create a progress reporter
    /// - Returns: A configured progress reporter
    public func createProgressReporter() -> DefaultProgressReporter {
        return DefaultProgressReporter()
    }
}

// MARK: - Supporting Storage Manager

/// Simple wrapper around TileStorageProtocol for compatibility
public final class TileStorageWrapper: @unchecked Sendable {
    private let storage: TileStorageProtocol
    
    public init(storage: TileStorageProtocol) {
        self.storage = storage
    }
    
    public func saveTile(coordinate: TileCoordinate, data: Data, configName: String? = nil) async throws {
        try await storage.saveTile(coordinate: coordinate, data: data, configName: configName)
    }
    
    public func getTile(coordinate: TileCoordinate, configName: String? = nil) async -> Data? {
        return await storage.getTile(coordinate: coordinate, configName: configName)
    }
    
    public func clearCache(for configName: String? = nil) async throws {
        if let configName = configName {
            try await storage.clearCache(for: configName)
        } else {
            try await storage.clearAll()
        }
    }
    
    public func getCacheSize() async -> Int64 {
        return await storage.getCacheSize()
    }
}