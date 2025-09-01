import Foundation
import CoreLocation

/// Unified tile manager that seamlessly handles both single and multiple configurations
/// This class provides a consistent API regardless of the number of configurations
public final class UnifiedTileManager: @unchecked Sendable {
    
    // MARK: - Public Types
    
    /// Configuration for the unified manager
    public struct Configuration {
        public let configs: [TileServerConfigProtocol]
        public let downloadStrategy: DownloadStrategy
        public let storageStrategy: StorageStrategy
        public let progressStrategy: ProgressStrategy
        
        public init(
            configs: [TileServerConfigProtocol],
            downloadStrategy: DownloadStrategy = .concurrent,
            storageStrategy: StorageStrategy = .separate,
            progressStrategy: ProgressStrategy = .unified
        ) {
            self.configs = configs
            self.downloadStrategy = downloadStrategy
            self.storageStrategy = storageStrategy
            self.progressStrategy = progressStrategy
        }
        
        /// Convenience initializer for single configuration
        public init(
            config: TileServerConfigProtocol,
            storageStrategy: StorageStrategy = .single,
            progressStrategy: ProgressStrategy = .unified
        ) {
            self.configs = [config]
            self.downloadStrategy = .concurrent
            self.storageStrategy = storageStrategy
            self.progressStrategy = progressStrategy
        }
    }
    
    /// Strategy for downloading multiple configurations
    public enum DownloadStrategy: Sendable {
        case concurrent    // Download all configs simultaneously
        case sequential    // Download configs one after another
        case priority([String]) // Download in priority order, then concurrent
    }
    
    /// Strategy for storing tiles from multiple configurations
    public enum StorageStrategy: Sendable {
        case separate      // Store each config in separate namespace
        case merged        // Merge all configs into single namespace (first config wins)
        case single        // Single config mode (ignore namespace)
    }
    
    /// Strategy for reporting progress
    public enum ProgressStrategy: Sendable {
        case unified       // Report combined progress across all configs
        case individual    // Report progress for each config separately
        case detailed      // Report both unified and individual progress
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let storage: TileStorageProtocol
    private let tileCalculator: TileCalculatorProtocol
    private let sizeEstimator: TileSizeEstimator
    private let progressCoordinator: UnifiedProgressCoordinator
    private let tileRetriever: TileRetriever
    private let logger = Logger.shared
    
    private var downloaders: [String: TileDownloaderProtocol] = [:]
    private var currentTask: Task<UnifiedDownloadResult, Error>?
    
    // MARK: - Public Properties
    
    /// Whether this manager is handling multiple configurations
    public var isMultiConfig: Bool {
        return configuration.configs.count > 1
    }
    
    /// Number of configurations being managed
    public var configurationCount: Int {
        return configuration.configs.count
    }
    
    /// Names of all configurations
    public var configurationNames: [String] {
        return configuration.configs.map { $0.name }
    }
    
    /// Primary configuration (first one for multi-config, the only one for single-config)
    public var primaryConfiguration: TileServerConfigProtocol {
        return configuration.configs.first!
    }
    
    // MARK: - Initialization
    
    internal init(
        configuration: Configuration,
        dependencies: DependencyContainer
    ) throws {
        guard !configuration.configs.isEmpty else {
            throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
        }
        
        self.configuration = configuration
        self.storage = dependencies.storage
        self.tileCalculator = dependencies.tileCalculator
        self.sizeEstimator = TileSizeEstimator(tileCalculator: tileCalculator)
        self.progressCoordinator = UnifiedProgressCoordinator(
            configNames: configuration.configs.map { $0.name },
            strategy: configuration.progressStrategy
        )
        
        // Create tile retriever for accessing stored tiles (SRP: separate download from retrieval)
        self.tileRetriever = TileRetriever(
            storage: dependencies.storage,
            configs: configuration.configs.compactMap { $0 as? TileServerConfig }
        )
        
        // Create downloaders for each configuration
        for config in configuration.configs {
            downloaders[config.name] = dependencies.createDownloader(for: config)
        }
        
        let configType = configuration.configs.count == 1 ? "single" : "multi(\(configuration.configs.count))"
        logger.info("UnifiedTileManager initialized with \(configType) configuration(s)")
    }
    
    // MARK: - Progress Observation
    
    /// Add a progress observer that receives unified progress updates
    public func addProgressObserver(_ observer: UnifiedProgressObserver) {
        progressCoordinator.addObserver(observer)
    }
    
    /// Remove a progress observer
    public func removeProgressObserver(_ observer: UnifiedProgressObserver) {
        progressCoordinator.removeObserver(observer)
    }
    
    // MARK: - Size Estimation
    
    /// Estimate download size for all configurations
    public func estimateDownloadSize(
        for bounds: MapBounds,
        zoomRange: ZoomRange
    ) throws -> UnifiedSizeEstimation {
        guard validateBounds(bounds) else {
            throw TileDownloadError.tileOutOfBounds(
                coordinate: TileCoordinate(x: 0, y: 0, zoom: 0),
                bounds: bounds
            )
        }
        
        var configEstimations: [String: TileSizeEstimation] = [:]
        var totalTiles = 0
        var totalSize: Int64 = 0
        var zoomLevels: [Int: Int] = [:]
        
        for config in configuration.configs {
            let estimation = try sizeEstimator.estimateDownloadSize(
                for: bounds,
                zoomRange: zoomRange,
                tileFormat: config.format
            )
            
            configEstimations[config.name] = estimation
            totalTiles += estimation.totalTiles
            totalSize += estimation.estimatedSizeBytes
            
            // Merge zoom levels
            for (zoom, count) in estimation.zoomLevels {
                zoomLevels[zoom, default: 0] += count
            }
        }
        
        return UnifiedSizeEstimation(
            configEstimations: configEstimations,
            totalTiles: totalTiles,
            totalEstimatedSize: totalSize,
            averageTileSize: totalTiles > 0 ? totalSize / Int64(totalTiles) : 0,
            zoomLevels: zoomLevels,
            isWithinRecommendedLimit: totalSize <= 600 * 1024 * 1024
        )
    }
    
    // MARK: - Download Operations
    
    /// Download tiles for all configurations using the configured strategy
    public func downloadTiles(
        for bounds: MapBounds,
        zoomRange: ZoomRange,
        skipSizeValidation: Bool = false
    ) async throws -> UnifiedDownloadResult {
        guard validateBounds(bounds) else {
            throw TileDownloadError.tileOutOfBounds(
                coordinate: TileCoordinate(x: 0, y: 0, zoom: 0),
                bounds: bounds
            )
        }
        
        // Size validation
        if !skipSizeValidation {
            let estimation = try estimateDownloadSize(for: bounds, zoomRange: zoomRange)
            if !estimation.isWithinRecommendedLimit {
                throw TileDownloadError.dataTooLarge(
                    size: estimation.totalEstimatedSize,
                    limit: 600 * 1024 * 1024
                )
            }
        }
        
        // Cancel any existing download
        currentTask?.cancel()
        
        let task = Task<UnifiedDownloadResult, Error> { [weak self] in
            guard let self = self else {
                throw TileDownloadError.operationCancelled
            }
            
            let tiles = self.tileCalculator.calculateTiles(for: bounds, zoomRange: zoomRange)
            
            self.logger.info("Starting unified download: \(self.configuration.configs.count) config(s), \(tiles.count) tiles total")
            
            return try await self.performUnifiedDownload(tiles: tiles)
        }
        
        currentTask = task
        
        do {
            let result = try await task.value
            logger.info("Unified download completed successfully")
            await progressCoordinator.notifyCompletion(with: result)
            return result
        } catch {
            logger.error("Unified download failed: \(error.localizedDescription)")
            await progressCoordinator.notifyFailure(with: error)
            throw error
        }
    }
    
    /// Download with custom size limit
    public func downloadTiles(
        for bounds: MapBounds,
        zoomRange: ZoomRange,
        maxDownloadSizeMB: Int
    ) async throws -> UnifiedDownloadResult {
        let estimation = try estimateDownloadSize(for: bounds, zoomRange: zoomRange)
        let customLimitBytes = Int64(maxDownloadSizeMB) * 1024 * 1024
        
        if estimation.totalEstimatedSize > customLimitBytes {
            throw TileDownloadError.dataTooLarge(
                size: estimation.totalEstimatedSize,
                limit: customLimitBytes
            )
        }
        
        return try await downloadTiles(for: bounds, zoomRange: zoomRange, skipSizeValidation: true)
    }
    
    /// Cancel all active downloads
    public func cancelDownload() {
        logger.info("Cancelling unified download")
        currentTask?.cancel()
        
        for downloader in downloaders.values {
            downloader.cancelAll()
        }
        
        Task { await progressCoordinator.notifyFailure(with: TileDownloadError.operationCancelled) }
    }
    
    // MARK: - Tile Retrieval
    
    /// Get tile data from the primary configuration
    /// WARNING: When using multiple configurations, specify the config explicitly to avoid ambiguity
    public func getTileData(for coordinate: TileCoordinate) async -> Data? {
        // Log warning if multiple configs exist but user doesn't specify which one
        if configuration.configs.count > 1 {
            logger.debug("getTileData called without specifying config - using primary config '\(primaryConfiguration.name)'. Consider using getTileData(for:from:) to be explicit.")
        }
        
        let configName = getStorageConfigName(primaryConfiguration.name)
        return await storage.getTile(coordinate: coordinate, configName: configName)
    }
    
    /// Get tile data from a specific configuration
    public func getTileData(for coordinate: TileCoordinate, from configName: String) async -> Data? {
        // Validate that the requested configuration exists
        guard configuration.configs.contains(where: { $0.name == configName }) else {
            logger.warning("Requested config '\(configName)' not found. Available configs: \(configurationNames.joined(separator: ", "))")
            return nil
        }
        
        let storageConfigName = getStorageConfigName(configName)
        return await storage.getTile(coordinate: coordinate, configName: storageConfigName)
    }
    
    /// Get tile data with fallback strategy (tries configs in priority order)
    public func getTileDataWithFallback(for coordinate: TileCoordinate) async -> (data: Data?, source: String?) {
        // Try configs in priority order based on storage strategy
        let searchOrder = getConfigSearchOrder()
        
        for config in searchOrder {
            let storageConfigName = getStorageConfigName(config.name)
            if let data = await storage.getTile(coordinate: coordinate, configName: storageConfigName) {
                return (data, config.name)
            }
        }
        return (nil, nil)
    }
    
    /// Get the order in which configs should be searched based on storage strategy
    private func getConfigSearchOrder() -> [TileServerConfigProtocol] {
        switch configuration.storageStrategy {
        case .separate:
            // For separate storage, search in original order
            return configuration.configs
        case .merged:
            // For merged storage, prioritize primary config first for consistency
            var ordered = [primaryConfiguration]
            ordered.append(contentsOf: configuration.configs.filter { $0.name != primaryConfiguration.name })
            return ordered
        case .single:
            // For single config, use natural order
            return configuration.configs
        }
    }
    
    /// Check if tile exists in primary configuration
    public func tileExists(for coordinate: TileCoordinate) async -> Bool {
        let configName = getStorageConfigName(primaryConfiguration.name)
        return await storage.tileExists(coordinate: coordinate, configName: configName)
    }
    
    /// Get all configurations that have the specified tile
    public func getAvailableConfigurations(for coordinate: TileCoordinate) async -> [String] {
        var available: [String] = []
        
        for config in configuration.configs {
            let storageConfigName = getStorageConfigName(config.name)
            if await storage.tileExists(coordinate: coordinate, configName: storageConfigName) {
                available.append(config.name)
            }
        }
        
        return available
    }
    
    /// Get tile data with source information to help debug conflicts
    public func getTileDataWithSource(for coordinate: TileCoordinate, from configName: String? = nil) async -> (data: Data?, source: String?, allAvailable: [String]) {
        let allAvailable = await getAvailableConfigurations(for: coordinate)
        
        if let configName = configName {
            // Get from specific configuration
            let data = await getTileData(for: coordinate, from: configName)
            return (data, configName, allAvailable)
        } else {
            // Get from primary configuration
            let data = await getTileData(for: coordinate)
            return (data, primaryConfiguration.name, allAvailable)
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cache
    public func clearAllCache() async throws {
        logger.info("Clearing all cache for unified manager")
        try await storage.clearAll()
    }
    
    /// Clear cache for specific configuration
    public func clearCache(for configName: String) async throws {
        let storageConfigName = getStorageConfigName(configName)
        logger.info("Clearing cache for configuration: \(configName)")
        if let storageConfigName = storageConfigName {
            try await storage.clearCache(for: storageConfigName)
        } else {
            try await storage.clearAll()
        }
    }
    
    /// Get total cache size
    public func getCacheSize() async -> Int64 {
        return await storage.getCacheSize()
    }
    
    /// Get cache sizes per configuration (if storage strategy supports it)
    public func getCacheSizes() async -> [String: Int64] {
        switch configuration.storageStrategy {
        case .separate:
            var sizes: [String: Int64] = [:]
            // This would require enhanced storage implementation to track per-config sizes
            let totalSize = await storage.getCacheSize()
            let sizePerConfig = totalSize / Int64(configuration.configs.count)
            
            for config in configuration.configs {
                sizes[config.name] = sizePerConfig
            }
            return sizes
            
        case .merged, .single:
            let totalSize = await storage.getCacheSize()
            return [primaryConfiguration.name: totalSize]
        }
    }
    
    // MARK: - Tile Retrieval (SRP: Separated from downloading)
    
    /// Retrieve a stored tile for a specific coordinate
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Tile data if found in storage
    public func getTile(coordinate: TileCoordinate, configName: String? = nil) async -> Data? {
        return await tileRetriever.getTile(coordinate: coordinate, configName: configName)
    }
    
    /// Retrieve multiple stored tiles
    /// - Parameters:
    ///   - coordinates: Array of tile coordinates
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Dictionary mapping coordinates to tile data
    public func getTiles(coordinates: [TileCoordinate], configName: String? = nil) async -> [TileCoordinate: Data] {
        return await tileRetriever.getTiles(coordinates: coordinates, configName: configName)
    }
    
    /// Check if a tile exists in storage
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: True if tile exists
    public func hasTile(coordinate: TileCoordinate, configName: String? = nil) async -> Bool {
        return await tileRetriever.hasTile(coordinate: coordinate, configName: configName)
    }
    
    /// Get tile metadata
    /// - Parameters:
    ///   - coordinate: The tile coordinate
    ///   - configName: Name of the configuration (optional for single config)
    /// - Returns: Tile metadata if available
    public func getTileMetadata(coordinate: TileCoordinate, configName: String? = nil) async -> TileMetadata? {
        return await tileRetriever.getTileMetadata(coordinate: coordinate, configName: configName)
    }
    
    /// Get storage statistics for all configurations
    /// - Returns: Storage statistics per configuration
    public func getStorageStats() async -> [String: TileStorageStats] {
        return await tileRetriever.getStorageStats()
    }
    
    // MARK: - Configuration Management
    
    /// Get configuration by name
    public func getConfiguration(named name: String) -> TileServerConfigProtocol? {
        return configuration.configs.first { $0.name == name }
    }
    
    /// Get all configurations
    public func getConfigurations() -> [TileServerConfigProtocol] {
        return configuration.configs
    }
    
    /// Update configuration (creates new manager instance)
    public func withUpdatedConfiguration(_ newConfig: Configuration) throws -> UnifiedTileManager {
        // This would require access to dependencies - would need to be implemented at SDK level
        fatalError("Configuration updates should be handled at SDK level")
    }
    
    /// Get diagnostic information about storage configuration to help debug conflicts
    public func getStorageDiagnostics() -> StorageDiagnostics {
        var configMappings: [String: String] = [:]
        
        for config in configuration.configs {
            let storageConfigName = getStorageConfigName(config.name)
            configMappings[config.name] = storageConfigName ?? "default_namespace"
        }
        
        return StorageDiagnostics(
            storageStrategy: configuration.storageStrategy,
            configCount: configuration.configs.count,
            primaryConfig: primaryConfiguration.name,
            configStorageMappings: configMappings,
            potentialConflicts: identifyPotentialConflicts(configMappings)
        )
    }
    
    private func identifyPotentialConflicts(_ mappings: [String: String]) -> [String] {
        var conflicts: [String] = []
        let storageNamespaces = Array(mappings.values)
        let uniqueNamespaces = Set(storageNamespaces)
        
        if storageNamespaces.count > uniqueNamespaces.count {
            // Find which configs share storage namespaces
            for namespace in uniqueNamespaces {
                let configsInNamespace = mappings.filter { $0.value == namespace }.keys
                if configsInNamespace.count > 1 {
                    conflicts.append("Configs sharing '\(namespace)' namespace: \(Array(configsInNamespace).joined(separator: ", "))")
                }
            }
        }
        
        return conflicts
    }
    
    /// Diagnostic information about storage configuration
    public struct StorageDiagnostics {
        public let storageStrategy: StorageStrategy
        public let configCount: Int
        public let primaryConfig: String
        public let configStorageMappings: [String: String]
        public let potentialConflicts: [String]
        
        public var hasPotentialConflicts: Bool {
            return !potentialConflicts.isEmpty
        }
        
        public var summary: String {
            var summary = """
                Storage Strategy: \(storageStrategy)
                Primary Config: \(primaryConfig)
                Total Configs: \(configCount)
                Storage Mappings:
                """
            
            for (config, storage) in configStorageMappings {
                summary += "\n  \(config) → \(storage)"
            }
            
            if hasPotentialConflicts {
                summary += "\n⚠️ Potential Conflicts:"
                for conflict in potentialConflicts {
                    summary += "\n  - \(conflict)"
                }
            } else {
                summary += "\n✅ No conflicts detected"
            }
            
            return summary
        }
    }
    
    // MARK: - Private Methods
    
    private func performUnifiedDownload(tiles: [TileCoordinate]) async throws -> UnifiedDownloadResult {
        let startTime = Date()
        
        switch configuration.downloadStrategy {
        case .concurrent:
            return try await performConcurrentDownload(tiles: tiles, startTime: startTime)
        case .sequential:
            return try await performSequentialDownload(tiles: tiles, startTime: startTime)
        case .priority(let priorityOrder):
            return try await performPriorityDownload(tiles: tiles, priorityOrder: priorityOrder, startTime: startTime)
        }
    }
    
    private func performConcurrentDownload(
        tiles: [TileCoordinate],
        startTime: Date
    ) async throws -> UnifiedDownloadResult {
        var results: [String: DownloadResult] = [:]
        
        try await withThrowingTaskGroup(of: (String, DownloadResult).self) { group in
            for config in configuration.configs {
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw TileDownloadError.operationCancelled
                    }
                    
                    let result = try await self.performConfigDownload(
                        tiles: tiles,
                        config: config
                    )
                    
                    return (config.name, result)
                }
            }
            
            for try await (configName, result) in group {
                results[configName] = result
                await progressCoordinator.notifyConfigCompletion(configName: configName, result: result)
                try Task.checkCancellation()
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        return UnifiedDownloadResult(
            configResults: results,
            totalDownloadTime: totalTime,
            downloadStrategy: configuration.downloadStrategy
        )
    }
    
    private func performSequentialDownload(
        tiles: [TileCoordinate],
        startTime: Date
    ) async throws -> UnifiedDownloadResult {
        var results: [String: DownloadResult] = [:]
        
        for config in configuration.configs {
            let result = try await performConfigDownload(tiles: tiles, config: config)
            results[config.name] = result
            await progressCoordinator.notifyConfigCompletion(configName: config.name, result: result)
            try Task.checkCancellation()
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        return UnifiedDownloadResult(
            configResults: results,
            totalDownloadTime: totalTime,
            downloadStrategy: configuration.downloadStrategy
        )
    }
    
    private func performPriorityDownload(
        tiles: [TileCoordinate],
        priorityOrder: [String],
        startTime: Date
    ) async throws -> UnifiedDownloadResult {
        var results: [String: DownloadResult] = [:]
        
        // Download priority configs first (sequential)
        let priorityConfigs = configuration.configs.filter { priorityOrder.contains($0.name) }
            .sorted { priorityOrder.firstIndex(of: $0.name) ?? Int.max < priorityOrder.firstIndex(of: $1.name) ?? Int.max }
        
        for config in priorityConfigs {
            let result = try await performConfigDownload(tiles: tiles, config: config)
            results[config.name] = result
            await progressCoordinator.notifyConfigCompletion(configName: config.name, result: result)
            try Task.checkCancellation()
        }
        
        // Download remaining configs concurrently
        let remainingConfigs = configuration.configs.filter { !priorityOrder.contains($0.name) }
        
        if !remainingConfigs.isEmpty {
            try await withThrowingTaskGroup(of: (String, DownloadResult).self) { group in
                for config in remainingConfigs {
                    group.addTask { [weak self] in
                        guard let self = self else {
                            throw TileDownloadError.operationCancelled
                        }
                        
                        let result = try await self.performConfigDownload(tiles: tiles, config: config)
                        return (config.name, result)
                    }
                }
                
                for try await (configName, result) in group {
                    results[configName] = result
                    await progressCoordinator.notifyConfigCompletion(configName: configName, result: result)
                    try Task.checkCancellation()
                }
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        return UnifiedDownloadResult(
            configResults: results,
            totalDownloadTime: totalTime,
            downloadStrategy: configuration.downloadStrategy
        )
    }
    
    private func performConfigDownload(
        tiles: [TileCoordinate],
        config: TileServerConfigProtocol
    ) async throws -> DownloadResult {
        let startTime = Date()
        var downloadedCount = 0
        var failedCount = 0
        
        guard let downloader = downloaders[config.name] else {
            throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
        }
        
        let validTiles = filterValidTiles(tiles, for: config)
        let totalTiles = validTiles.count
        
        logger.debug("Starting download for '\(config.name)': \(totalTiles) valid tiles")
        
        try Task.checkCancellation()
        
        try await withThrowingTaskGroup(of: (TileCoordinate, Result<Data, Error>).self) { group in
            let semaphore = AsyncSemaphore(value: config.httpConfiguration.maxConcurrentOperations)
            
            for tile in validTiles {
                group.addTask { [weak self] in
                    guard let self = self else {
                        throw TileDownloadError.operationCancelled
                    }
                    
                    await semaphore.wait()
                    defer {
                        Task { await semaphore.signal() }
                    }
                    
                    let result = await self.downloadSingleTile(tile, config: config, downloader: downloader)
                    return (tile, result)
                }
            }
            
            for try await (tile, result) in group {
                switch result {
                case .success(let data):
                    do {
                        let storageConfigName = getStorageConfigName(config.name)
                        try await storage.saveTile(
                            coordinate: tile,
                            data: data,
                            configName: storageConfigName
                        )
                        downloadedCount += 1
                        
                        logger.verbose("Downloaded tile (\(tile.x), \(tile.y), \(tile.zoom)) for '\(config.name)'")
                    } catch {
                        failedCount += 1
                        logger.warning("Failed to save tile for '\(config.name)': \(error)")
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
                
                await progressCoordinator.notifyProgress(configName: config.name, progress: progress)
                
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
    
    private func downloadSingleTile(
        _ tile: TileCoordinate,
        config: TileServerConfigProtocol,
        downloader: TileDownloaderProtocol
    ) async -> Result<Data, Error> {
        // Check if tile already exists based on storage strategy
        let storageConfigName = getStorageConfigName(config.name)
        if await storage.tileExists(coordinate: tile, configName: storageConfigName) {
            if let data = await storage.getTile(coordinate: tile, configName: storageConfigName) {
                return .success(data)
            }
        }
        
        // Generate URL and download
        let urlString = config.tileURL(for: tile)
        
        guard let url = URL(string: urlString) else {
            return .failure(TileDownloadError.invalidURL(urlString))
        }
        
        return await downloader.downloadTile(from: url)
    }
    
    private func filterValidTiles(_ tiles: [TileCoordinate], for config: TileServerConfigProtocol) -> [TileCoordinate] {
        return tiles.filter { tile in
            guard config.isZoomLevelSupported(tile.zoom) else { return false }
            guard config.isCoordinateInBounds(tile) else { return false }
            return true
        }
    }
    
    private func validateBounds(_ bounds: MapBounds) -> Bool {
        return bounds.northEast.latitude > bounds.southWest.latitude &&
               bounds.northEast.longitude > bounds.southWest.longitude &&
               bounds.northEast.latitude <= 85.0 &&
               bounds.southWest.latitude >= -85.0 &&
               bounds.northEast.longitude <= 180.0 &&
               bounds.southWest.longitude >= -180.0
    }
    
    private func getStorageConfigName(_ configName: String) -> String? {
        switch configuration.storageStrategy {
        case .separate:
            // Each config gets its own storage namespace - no conflicts possible
            return configName
        case .merged:
            // CRITICAL FIX: For merged strategy, we still need to separate by config to avoid conflicts
            // The "merged" behavior should be handled at the retrieval level, not storage level
            // This prevents tiles from different URLs overwriting each other
            return configName
        case .single:
            // Single config mode - use config name if multiple configs exist to prevent conflicts
            return configuration.configs.count == 1 ? nil : configName
        }
    }
}