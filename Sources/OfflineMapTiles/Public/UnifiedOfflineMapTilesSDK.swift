import Foundation
import CoreLocation

/// Unified SDK that seamlessly handles both single and multiple tile server configurations
/// This is the main entry point for the unified offline map tiles solution
public final class UnifiedOfflineMapTilesSDK: @unchecked Sendable {
    
    // MARK: - Public Properties
    
    /// Shared instance for convenience
    public static let shared = UnifiedOfflineMapTilesSDK()
    
    /// Current SDK version
    public static let version = "2.0.0-unified"
    
    // MARK: - Private Properties
    
    private let dependencyContainer: DependencyContainer
    private let logger = Logger.shared
    
    // MARK: - Initialization
    
    public init(
        storageDirectory: URL? = nil,
        cachePolicy: CacheManagementProtocol = DefaultCacheManagementPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration(),
        logLevel: LogLevel = .info
    ) {
        self.dependencyContainer = DependencyContainer(
            storageDirectory: storageDirectory,
            cachePolicy: cachePolicy,
            httpConfig: httpConfig
        )
        
        logger.setMinimumLogLevel(logLevel)
        logger.info("UnifiedOfflineMapTilesSDK v\(Self.version) initialized")
    }
    
    // MARK: - Unified Manager Creation
    
    /// Create a unified manager with a single configuration
    /// - Parameters:
    ///   - config: The tile server configuration
    ///   - storageStrategy: How to store tiles (default: single namespace)
    ///   - progressStrategy: How to report progress (default: unified)
    /// - Returns: A unified tile manager
    public func createManager(
        with config: TileServerConfigProtocol,
        storageStrategy: UnifiedTileManager.StorageStrategy = .single,
        progressStrategy: UnifiedTileManager.ProgressStrategy = .unified
    ) async throws -> UnifiedTileManager {
        logger.info("Creating unified manager for single config: '\(config.name)'")
        
        let configuration = UnifiedTileManager.Configuration(
            config: config,
            storageStrategy: storageStrategy,
            progressStrategy: progressStrategy
        )
        
        return try UnifiedTileManager(
            configuration: configuration,
            dependencies: dependencyContainer
        )
    }
    
    /// Create a unified manager with multiple configurations
    /// - Parameters:
    ///   - configs: Array of tile server configurations
    ///   - downloadStrategy: How to download multiple configs (default: concurrent)
    ///   - storageStrategy: How to store tiles from multiple configs (default: separate)
    ///   - progressStrategy: How to report progress (default: unified)
    /// - Returns: A unified tile manager
    public func createManager(
        with configs: [TileServerConfigProtocol],
        downloadStrategy: UnifiedTileManager.DownloadStrategy = .concurrent,
        storageStrategy: UnifiedTileManager.StorageStrategy = .separate,
        progressStrategy: UnifiedTileManager.ProgressStrategy = .unified
    ) async throws -> UnifiedTileManager {
        guard !configs.isEmpty else {
            throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
        }
        
        logger.info("Creating unified manager for \(configs.count) configs")
        
        let configuration = UnifiedTileManager.Configuration(
            configs: configs,
            downloadStrategy: downloadStrategy,
            storageStrategy: storageStrategy,
            progressStrategy: progressStrategy
        )
        
        return try UnifiedTileManager(
            configuration: configuration,
            dependencies: dependencyContainer
        )
    }
    
    // MARK: - Smart Manager Creation (Auto-detects Single vs Multi)
    
    /// Create a manager that automatically handles single or multiple configurations
    /// - Parameters:
    ///   - configs: One or more tile server configurations
    ///   - options: Configuration options (uses smart defaults based on config count)
    /// - Returns: A unified tile manager optimized for the number of configurations
    public func createSmartManager(
        with configs: [TileServerConfigProtocol],
        options: SmartManagerOptions? = nil
    ) async throws -> UnifiedTileManager {
        guard !configs.isEmpty else {
            throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
        }
        
        let resolvedOptions = options ?? SmartManagerOptions.smartDefaults(for: configs.count)
        
        logger.info("Creating smart manager for \(configs.count) config(s) with strategy: \(resolvedOptions.downloadStrategy)")
        
        let configuration = UnifiedTileManager.Configuration(
            configs: configs,
            downloadStrategy: resolvedOptions.downloadStrategy,
            storageStrategy: resolvedOptions.storageStrategy,
            progressStrategy: resolvedOptions.progressStrategy
        )
        
        return try UnifiedTileManager(
            configuration: configuration,
            dependencies: dependencyContainer
        )
    }
    
    /// Smart manager options that provide intelligent defaults
    public struct SmartManagerOptions: Sendable {
        public let downloadStrategy: UnifiedTileManager.DownloadStrategy
        public let storageStrategy: UnifiedTileManager.StorageStrategy
        public let progressStrategy: UnifiedTileManager.ProgressStrategy
        
        public init(
            downloadStrategy: UnifiedTileManager.DownloadStrategy,
            storageStrategy: UnifiedTileManager.StorageStrategy,
            progressStrategy: UnifiedTileManager.ProgressStrategy
        ) {
            self.downloadStrategy = downloadStrategy
            self.storageStrategy = storageStrategy
            self.progressStrategy = progressStrategy
        }
        
        /// Provides smart defaults based on the number of configurations
        public static func smartDefaults(for configCount: Int) -> SmartManagerOptions {
            switch configCount {
            case 1:
                // Single config - simple unified approach
                return SmartManagerOptions(
                    downloadStrategy: .concurrent,
                    storageStrategy: .single,
                    progressStrategy: .unified
                )
                
            case 2...3:
                // Small multi-config - concurrent with separate storage
                return SmartManagerOptions(
                    downloadStrategy: .concurrent,
                    storageStrategy: .separate,
                    progressStrategy: .detailed
                )
                
            case 4...6:
                // Medium multi-config - may benefit from sequential to avoid overwhelming servers
                return SmartManagerOptions(
                    downloadStrategy: .sequential,
                    storageStrategy: .separate,
                    progressStrategy: .detailed
                )
                
            default:
                // Large multi-config - definitely sequential with detailed progress
                return SmartManagerOptions(
                    downloadStrategy: .sequential,
                    storageStrategy: .separate,
                    progressStrategy: .individual
                )
            }
        }
        
        /// Configuration optimized for speed (concurrent everything)
        public static let speed = SmartManagerOptions(
            downloadStrategy: .concurrent,
            storageStrategy: .merged,
            progressStrategy: .unified
        )
        
        /// Configuration optimized for reliability (sequential with detailed tracking)
        public static let reliability = SmartManagerOptions(
            downloadStrategy: .sequential,
            storageStrategy: .separate,
            progressStrategy: .detailed
        )
        
        /// Configuration optimized for monitoring (detailed everything)
        public static let monitoring = SmartManagerOptions(
            downloadStrategy: .concurrent,
            storageStrategy: .separate,
            progressStrategy: .individual
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Quick download with a single configuration
    /// - Parameters:
    ///   - config: The tile server configuration
    ///   - bounds: Geographic bounds to download
    ///   - zoomRange: Range of zoom levels to download
    ///   - observer: Optional progress observer
    /// - Returns: Unified download result
    public func quickDownload(
        config: TileServerConfigProtocol,
        bounds: MapBounds,
        zoomRange: ZoomRange,
        observer: UnifiedProgressObserver? = nil
    ) async throws -> UnifiedDownloadResult {
        let manager = try await createManager(with: config)
        
        if let observer = observer {
            manager.addProgressObserver(observer)
        }
        
        return try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
    }
    
    /// Quick download with multiple configurations
    /// - Parameters:
    ///   - configs: Array of tile server configurations
    ///   - bounds: Geographic bounds to download
    ///   - zoomRange: Range of zoom levels to download
    ///   - strategy: Download strategy (default: smart)
    ///   - observer: Optional progress observer
    /// - Returns: Unified download result
    public func quickDownload(
        configs: [TileServerConfigProtocol],
        bounds: MapBounds,
        zoomRange: ZoomRange,
        strategy: UnifiedTileManager.DownloadStrategy = .concurrent,
        observer: UnifiedProgressObserver? = nil
    ) async throws -> UnifiedDownloadResult {
        let manager = try await createManager(
            with: configs,
            downloadStrategy: strategy
        )
        
        if let observer = observer {
            manager.addProgressObserver(observer)
        }
        
        return try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
    }
    
    /// Smart quick download that automatically optimizes based on configurations
    /// - Parameters:
    ///   - configs: One or more tile server configurations
    ///   - bounds: Geographic bounds to download
    ///   - zoomRange: Range of zoom levels to download
    ///   - observer: Optional progress observer
    /// - Returns: Unified download result
    public func smartQuickDownload(
        configs: [TileServerConfigProtocol],
        bounds: MapBounds,
        zoomRange: ZoomRange,
        observer: UnifiedProgressObserver? = nil
    ) async throws -> UnifiedDownloadResult {
        let manager = try await createSmartManager(with: configs)
        
        if let observer = observer {
            manager.addProgressObserver(observer)
        }
        
        return try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
    }
    
    // MARK: - Estimation and Validation
    
    /// Estimate download size for configurations
    /// - Parameters:
    ///   - configs: One or more tile server configurations
    ///   - bounds: Geographic bounds
    ///   - zoomRange: Range of zoom levels
    /// - Returns: Unified size estimation
    public func estimateDownloadSize(
        for configs: [TileServerConfigProtocol],
        bounds: MapBounds,
        zoomRange: ZoomRange
    ) async throws -> UnifiedSizeEstimation {
        let manager = try await createSmartManager(with: configs)
        return try manager.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    }
    
    /// Validate if download is feasible with current settings
    /// - Parameters:
    ///   - configs: One or more tile server configurations
    ///   - bounds: Geographic bounds
    ///   - zoomRange: Range of zoom levels
    ///   - maxSizeMB: Maximum allowed download size in MB (default: 600MB)
    /// - Returns: Validation result with recommendations
    public func validateDownload(
        for configs: [TileServerConfigProtocol],
        bounds: MapBounds,
        zoomRange: ZoomRange,
        maxSizeMB: Int = 600
    ) async throws -> DownloadValidation {
        let estimation = try await estimateDownloadSize(
            for: configs,
            bounds: bounds,
            zoomRange: zoomRange
        )
        
        let maxBytes = Int64(maxSizeMB) * 1024 * 1024
        let isValid = estimation.totalEstimatedSize <= maxBytes
        
        return DownloadValidation(
            isValid: isValid,
            estimation: estimation,
            limitBytes: maxBytes,
            recommendations: generateRecommendations(
                estimation: estimation,
                configs: configs,
                zoomRange: zoomRange,
                isValid: isValid
            )
        )
    }
    
    public struct DownloadValidation {
        public let isValid: Bool
        public let estimation: UnifiedSizeEstimation
        public let limitBytes: Int64
        public let recommendations: [String]
        
        /// Formatted validation summary
        public var summary: String {
            let status = isValid ? "✅ Valid" : "❌ Too Large"
            let size = ByteCountFormatter().string(fromByteCount: estimation.totalEstimatedSize)
            let limit = ByteCountFormatter().string(fromByteCount: limitBytes)
            
            return "\(status): \(size) (\(estimation.totalTiles) tiles) vs \(limit) limit"
        }
    }
    
    // MARK: - Cache Management
    
    /// Get total cache size across all configurations
    public func getCacheSize() async -> Int64 {
        return await dependencyContainer.storage.getCacheSize()
    }
    
    /// Clear all cached tiles
    public func clearAllCache() async throws {
        logger.info("Clearing all cache from unified SDK")
        try await dependencyContainer.storage.clearAll()
    }
    
    // MARK: - System Information
    
    /// Get comprehensive system information
    public func getSystemInfo() -> [String: Any] {
        return [
            "sdk_version": Self.version,
            "sdk_type": "unified",
            "platform": "iOS/macOS",
            "cache_policy_max_size": dependencyContainer.cachePolicy.maxCacheSize,
            "http_timeout": dependencyContainer.httpConfig.timeout,
            "http_max_concurrent": dependencyContainer.httpConfig.maxConcurrentOperations,
            "supported_strategies": [
                "download": ["concurrent", "sequential", "priority"],
                "storage": ["single", "separate", "merged"],
                "progress": ["unified", "individual", "detailed"]
            ]
        ]
    }
    
    // MARK: - Configuration Management
    
    /// Create a priority download strategy for specific configurations
    /// - Parameter priorityNames: Configuration names in priority order
    /// - Returns: Priority download strategy
    public func createPriorityStrategy(priorityNames: [String]) -> UnifiedTileManager.DownloadStrategy {
        return .priority(priorityNames)
    }
    
    // MARK: - Private Helpers
    
    private func generateRecommendations(
        estimation: UnifiedSizeEstimation,
        configs: [TileServerConfigProtocol],
        zoomRange: ZoomRange,
        isValid: Bool
    ) -> [String] {
        var recommendations: [String] = []
        
        if !isValid {
            recommendations.append("Reduce the download area or zoom range")
            
            if configs.count > 1 {
                recommendations.append("Download configurations separately")
                
                if let largest = estimation.largestConfiguration {
                    recommendations.append("Consider excluding '\(largest.name)' which has the largest size")
                }
            }
            
            if zoomRange.maxZoom > 16 {
                recommendations.append("Reduce maximum zoom level from \(zoomRange.maxZoom) to 16 or lower")
            }
            
            let zoomLevels = Array(zoomRange.minZoom...zoomRange.maxZoom)
            if zoomLevels.count > 4 {
                recommendations.append("Split into smaller zoom ranges (currently \(zoomLevels.count) levels)")
            }
        }
        
        if configs.count > 3 {
            recommendations.append("Use sequential download strategy to avoid overwhelming servers")
        }
        
        if estimation.totalTiles > 10000 {
            recommendations.append("Consider using detailed progress monitoring for large downloads")
        }
        
        return recommendations
    }
}

// MARK: - Logging Configuration

extension UnifiedOfflineMapTilesSDK {
    
    /// Configure logging for the unified SDK
    /// - Parameters:
    ///   - level: Minimum log level
    ///   - destinations: Custom log destinations
    public func configureLogging(
        level: LogLevel = .info,
        destinations: [LogDestination] = []
    ) {
        logger.setMinimumLogLevel(level)
        logger.removeAllDestinations()
        
        if destinations.isEmpty {
            #if DEBUG
            logger.addDestination(ConsoleLogDestination())
            #endif
        } else {
            for destination in destinations {
                logger.addDestination(destination)
            }
        }
        
        logger.info("Unified SDK logging configured with level: \(level.name)")
    }
    
    /// Enable file logging
    /// - Parameter fileURL: URL for log files
    public func enableFileLogging(at fileURL: URL) throws {
        let fileDestination = try FileLogDestination(fileURL: fileURL)
        logger.addDestination(fileDestination)
        logger.info("File logging enabled at: \(fileURL.path)")
    }
    
    /// Enable OS logging (iOS 14+/macOS 11+)
    @available(iOS 14.0, macOS 11.0, *)
    public func enableOSLogging(subsystem: String = "com.offlinemaptiles.unified", category: String = "default") {
        let osDestination = OSLogDestination(subsystem: subsystem, category: category)
        logger.addDestination(osDestination)
        logger.info("OS logging enabled for subsystem: \(subsystem)")
    }
}