import Foundation

// MARK: - Unified Progress Reporting

/// Protocol for observing unified progress across single or multiple configurations
public protocol UnifiedProgressObserver: AnyObject, Sendable {
    /// Called when overall progress is updated
    /// - Parameter progress: Unified progress across all configurations
    func didUpdateUnifiedProgress(_ progress: UnifiedProgress)
    
    /// Called when progress for a specific configuration is updated (multi-config mode)
    /// - Parameters:
    ///   - configName: Name of the configuration
    ///   - progress: Progress for the specific configuration
    func didUpdateConfigProgress(configName: String, progress: DownloadProgress)
    
    /// Called when download completes successfully
    /// - Parameter result: Unified download result
    func didCompleteDownload(with result: UnifiedDownloadResult)
    
    /// Called when download fails
    /// - Parameter error: The error that caused the failure
    func didFailDownload(with error: Error)
}

/// Default implementations to make methods optional
public extension UnifiedProgressObserver {
    func didUpdateConfigProgress(configName: String, progress: DownloadProgress) {}
}

/// Unified progress information that works for both single and multi-config scenarios
public struct UnifiedProgress: Sendable {
    /// Overall progress percentage (0.0 to 100.0)
    public let overallPercentage: Double
    
    /// Total tiles across all configurations
    public let totalTiles: Int
    
    /// Total downloaded tiles across all configurations
    public let totalDownloaded: Int
    
    /// Total failed tiles across all configurations
    public let totalFailed: Int
    
    /// Progress per configuration (empty for single config)
    public let configProgress: [String: DownloadProgress]
    
    /// Number of configurations being processed
    public let configurationCount: Int
    
    /// Number of configurations completed
    public let completedConfigurations: Int
    
    /// Current tile being processed (if available)
    public let currentTile: TileCoordinate?
    
    /// Estimated time remaining in seconds
    public let estimatedTimeRemaining: TimeInterval?
    
    /// Current download speed in tiles per second
    public let currentSpeed: Double?
    
    public init(
        overallPercentage: Double,
        totalTiles: Int,
        totalDownloaded: Int,
        totalFailed: Int,
        configProgress: [String: DownloadProgress] = [:],
        configurationCount: Int = 1,
        completedConfigurations: Int = 0,
        currentTile: TileCoordinate? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentSpeed: Double? = nil
    ) {
        self.overallPercentage = overallPercentage
        self.totalTiles = totalTiles
        self.totalDownloaded = totalDownloaded
        self.totalFailed = totalFailed
        self.configProgress = configProgress
        self.configurationCount = configurationCount
        self.completedConfigurations = completedConfigurations
        self.currentTile = currentTile
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentSpeed = currentSpeed
    }
    
    /// Whether all configurations have completed
    public var isComplete: Bool {
        return completedConfigurations == configurationCount
    }
    
    /// Success rate across all configurations
    public var successRate: Double {
        let totalProcessed = totalDownloaded + totalFailed
        return totalProcessed > 0 ? Double(totalDownloaded) / Double(totalProcessed) : 0.0
    }
}

// MARK: - Unified Download Result

/// Result of a unified download operation
public struct UnifiedDownloadResult: Sendable {
    /// Results per configuration
    public let configResults: [String: DownloadResult]
    
    /// Total download time for all configurations
    public let totalDownloadTime: TimeInterval
    
    /// Strategy used for downloading
    public let downloadStrategy: UnifiedTileManager.DownloadStrategy
    
    /// Overall statistics computed from all configurations
    public let overallStats: OverallStats
    
    public init(
        configResults: [String: DownloadResult],
        totalDownloadTime: TimeInterval,
        downloadStrategy: UnifiedTileManager.DownloadStrategy
    ) {
        self.configResults = configResults
        self.totalDownloadTime = totalDownloadTime
        self.downloadStrategy = downloadStrategy
        self.overallStats = OverallStats(configResults: configResults, totalTime: totalDownloadTime)
    }
    
    /// Overall statistics across all configurations
    public struct OverallStats: Sendable {
        public let totalTiles: Int
        public let totalSuccessful: Int
        public let totalFailed: Int
        public let overallSuccessRate: Double
        public let averageDownloadSpeed: Double
        public let configurationsCount: Int
        public let completedConfigurations: Int
        
        internal init(configResults: [String: DownloadResult], totalTime: TimeInterval) {
            self.configurationsCount = configResults.count
            self.completedConfigurations = configResults.count // All completed if result exists
            
            self.totalTiles = configResults.values.reduce(0) { $0 + $1.totalTiles }
            self.totalSuccessful = configResults.values.reduce(0) { $0 + $1.successfulTiles }
            self.totalFailed = configResults.values.reduce(0) { $0 + $1.failedTiles }
            
            let totalProcessed = self.totalSuccessful + self.totalFailed
            self.overallSuccessRate = totalProcessed > 0 ? Double(self.totalSuccessful) / Double(totalProcessed) : 0.0
            
            self.averageDownloadSpeed = totalTime > 0 ? Double(self.totalSuccessful) / totalTime : 0.0
        }
    }
    
    /// Get result for a specific configuration
    public func result(for configName: String) -> DownloadResult? {
        return configResults[configName]
    }
    
    /// Whether all configurations completed successfully
    public var allConfigurationsSucceeded: Bool {
        return configResults.allSatisfy { $0.value.successfulTiles > 0 || $0.value.totalTiles == 0 }
    }
    
    /// Configuration with the best success rate
    public var bestConfiguration: (name: String, result: DownloadResult)? {
        guard let maxPair = configResults.max(by: { $0.value.successRate < $1.value.successRate }) else {
            return nil
        }
        return (name: maxPair.key, result: maxPair.value)
    }
    
    /// Configuration with the worst success rate
    public var worstConfiguration: (name: String, result: DownloadResult)? {
        guard let minPair = configResults.min(by: { $0.value.successRate < $1.value.successRate }) else {
            return nil
        }
        return (name: minPair.key, result: minPair.value)
    }
}

// MARK: - Unified Size Estimation

/// Size estimation for unified downloads
public struct UnifiedSizeEstimation: Sendable {
    /// Estimations per configuration
    public let configEstimations: [String: TileSizeEstimation]
    
    /// Total tiles across all configurations
    public let totalTiles: Int
    
    /// Total estimated size in bytes
    public let totalEstimatedSize: Int64
    
    /// Average tile size across all configurations
    public let averageTileSize: Int64
    
    /// Zoom levels distribution across all configurations
    public let zoomLevels: [Int: Int]
    
    /// Whether the total size is within recommended limits
    public let isWithinRecommendedLimit: Bool
    
    public init(
        configEstimations: [String: TileSizeEstimation],
        totalTiles: Int,
        totalEstimatedSize: Int64,
        averageTileSize: Int64,
        zoomLevels: [Int: Int],
        isWithinRecommendedLimit: Bool
    ) {
        self.configEstimations = configEstimations
        self.totalTiles = totalTiles
        self.totalEstimatedSize = totalEstimatedSize
        self.averageTileSize = averageTileSize
        self.zoomLevels = zoomLevels
        self.isWithinRecommendedLimit = isWithinRecommendedLimit
    }
    
    /// Formatted total size string
    public var formattedTotalSize: String {
        return ByteCountFormatter().string(fromByteCount: totalEstimatedSize)
    }
    
    /// Total size in megabytes
    public var totalSizeMB: Double {
        return Double(totalEstimatedSize) / (1024 * 1024)
    }
    
    /// Get estimation for a specific configuration
    public func estimation(for configName: String) -> TileSizeEstimation? {
        return configEstimations[configName]
    }
    
    /// Configuration with the largest estimated size
    public var largestConfiguration: (name: String, estimation: TileSizeEstimation)? {
        guard let maxPair = configEstimations.max(by: { $0.value.estimatedSizeBytes < $1.value.estimatedSizeBytes }) else {
            return nil
        }
        return (name: maxPair.key, estimation: maxPair.value)
    }
    
    /// Configuration with the smallest estimated size
    public var smallestConfiguration: (name: String, estimation: TileSizeEstimation)? {
        guard let minPair = configEstimations.min(by: { $0.value.estimatedSizeBytes < $1.value.estimatedSizeBytes }) else {
            return nil
        }
        return (name: minPair.key, estimation: minPair.value)
    }
}

// MARK: - Unified Progress Coordinator

/// Internal coordinator for managing unified progress reporting
internal final class UnifiedProgressCoordinator: @unchecked Sendable {
    private let configNames: [String]
    private let strategy: UnifiedTileManager.ProgressStrategy
    private var observers: [WeakUnifiedProgressObserver] = []
    private var configProgress: [String: DownloadProgress] = [:]
    private var configResults: [String: DownloadResult] = [:]
    private var startTime = Date()
    
    private let queue = DispatchQueue(label: "unified.progress.coordinator", attributes: .concurrent)
    
    init(configNames: [String], strategy: UnifiedTileManager.ProgressStrategy) {
        self.configNames = configNames
        self.strategy = strategy
        
        // Initialize progress for all configs
        for name in configNames {
            configProgress[name] = DownloadProgress(totalTiles: 0, downloadedTiles: 0, failedTiles: 0)
        }
    }
    
    func addObserver(_ observer: UnifiedProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cleanupObservers()
            self?.observers.append(WeakUnifiedProgressObserver(observer))
        }
    }
    
    func removeObserver(_ observer: UnifiedProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.observers.removeAll { $0.observer === observer }
        }
    }
    
    func notifyProgress(configName: String, progress: DownloadProgress) async {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.configProgress[configName] = progress
            let unifiedProgress = self.calculateUnifiedProgress()
            
            let validObservers = self.observers.compactMap { $0.observer }
            for observer in validObservers {
                DispatchQueue.main.async {
                    if self.strategy == .individual || self.strategy == .detailed {
                        observer.didUpdateConfigProgress(configName: configName, progress: progress)
                    }
                    
                    if self.strategy == .unified || self.strategy == .detailed {
                        observer.didUpdateUnifiedProgress(unifiedProgress)
                    }
                }
            }
        }
    }
    
    func notifyConfigCompletion(configName: String, result: DownloadResult) async {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.configResults[configName] = result
        }
    }
    
    func notifyCompletion(with result: UnifiedDownloadResult) async {
        let validObservers = queue.sync { self.observers.compactMap { $0.observer } }
        
        for observer in validObservers {
            DispatchQueue.main.async {
                observer.didCompleteDownload(with: result)
            }
        }
    }
    
    func notifyFailure(with error: Error) async {
        let validObservers = queue.sync { self.observers.compactMap { $0.observer } }
        
        for observer in validObservers {
            DispatchQueue.main.async {
                observer.didFailDownload(with: error)
            }
        }
    }
    
    private func calculateUnifiedProgress() -> UnifiedProgress {
        let totalTiles = configProgress.values.reduce(0) { $0 + $1.totalTiles }
        let totalDownloaded = configProgress.values.reduce(0) { $0 + $1.downloadedTiles }
        let totalFailed = configProgress.values.reduce(0) { $0 + $1.failedTiles }
        
        let overallPercentage = totalTiles > 0 ? Double(totalDownloaded + totalFailed) / Double(totalTiles) * 100.0 : 0.0
        
        let currentTime = Date()
        let elapsed = currentTime.timeIntervalSince(startTime)
        let speed = elapsed > 0 ? Double(totalDownloaded) / elapsed : 0.0
        
        let remaining = totalTiles - (totalDownloaded + totalFailed)
        let eta = speed > 0 && remaining > 0 ? TimeInterval(remaining) / speed : nil
        
        return UnifiedProgress(
            overallPercentage: overallPercentage,
            totalTiles: totalTiles,
            totalDownloaded: totalDownloaded,
            totalFailed: totalFailed,
            configProgress: configProgress,
            configurationCount: configNames.count,
            completedConfigurations: configResults.count,
            currentTile: configProgress.values.compactMap { $0.currentTile }.last,
            estimatedTimeRemaining: eta,
            currentSpeed: speed
        )
    }
    
    private func cleanupObservers() {
        observers.removeAll { $0.observer == nil }
    }
}

/// Weak reference wrapper for unified progress observers
private struct WeakUnifiedProgressObserver {
    weak var observer: UnifiedProgressObserver?
    
    init(_ observer: UnifiedProgressObserver) {
        self.observer = observer
    }
}

// MARK: - Convenience Progress Observers

/// Simple unified progress observer for logging
public final class UnifiedConsoleProgressObserver: UnifiedProgressObserver {
    private let prefix: String
    
    public init(prefix: String = "Unified Download") {
        self.prefix = prefix
    }
    
    public func didUpdateUnifiedProgress(_ progress: UnifiedProgress) {
        if progress.configurationCount > 1 {
            print("\(prefix): \(String(format: "%.1f", progress.overallPercentage))% (\(progress.totalDownloaded)/\(progress.totalTiles)) - \(progress.completedConfigurations)/\(progress.configurationCount) configs done")
        } else {
            print("\(prefix): \(String(format: "%.1f", progress.overallPercentage))% (\(progress.totalDownloaded)/\(progress.totalTiles))")
        }
    }
    
    public func didUpdateConfigProgress(configName: String, progress: DownloadProgress) {
        print("  \(configName): \(String(format: "%.1f", progress.percentage))%")
    }
    
    public func didCompleteDownload(with result: UnifiedDownloadResult) {
        print("\(prefix): Completed! \(result.overallStats.totalSuccessful) tiles downloaded from \(result.configResults.count) config(s)")
        
        for (configName, configResult) in result.configResults {
            print("  \(configName): \(configResult.successfulTiles)/\(configResult.totalTiles) tiles")
        }
    }
    
    public func didFailDownload(with error: Error) {
        print("\(prefix): Failed - \(error.localizedDescription)")
    }
}

/// Detailed unified progress observer with statistics
public final class DetailedUnifiedProgressObserver: UnifiedProgressObserver {
    private let startTime = Date()
    
    public init() {}
    
    public func didUpdateUnifiedProgress(_ progress: UnifiedProgress) {
        let elapsed = Date().timeIntervalSince(startTime)
        
        print("""
            Unified Progress Update:
            - Overall: \(String(format: "%.1f", progress.overallPercentage))%
            - Tiles: \(progress.totalDownloaded)/\(progress.totalTiles) (failed: \(progress.totalFailed))
            - Configs: \(progress.completedConfigurations)/\(progress.configurationCount) completed
            - Speed: \(String(format: "%.1f", progress.currentSpeed ?? 0)) tiles/sec
            - Elapsed: \(String(format: "%.1f", elapsed))s
            - ETA: \(progress.estimatedTimeRemaining != nil ? String(format: "%.1f", progress.estimatedTimeRemaining!) + "s" : "N/A")
            """)
        
        if progress.configurationCount > 1 && !progress.configProgress.isEmpty {
            print("  Per-config progress:")
            for (configName, configProgress) in progress.configProgress.sorted(by: { $0.key < $1.key }) {
                print("    \(configName): \(String(format: "%.1f", configProgress.percentage))%")
            }
        }
    }
    
    public func didCompleteDownload(with result: UnifiedDownloadResult) {
        print("""
            Unified Download Complete:
            - Total Success Rate: \(String(format: "%.1f", result.overallStats.overallSuccessRate * 100))%
            - Total Time: \(String(format: "%.2f", result.totalDownloadTime))s
            - Overall Speed: \(String(format: "%.2f", result.overallStats.averageDownloadSpeed)) tiles/sec
            - Strategy: \(result.downloadStrategy)
            """)
        
        if let best = result.bestConfiguration {
            print("  Best config: \(best.name) (\(String(format: "%.1f", best.result.successRate * 100))%)")
        }
        
        if let worst = result.worstConfiguration, result.configResults.count > 1 {
            print("  Worst config: \(worst.name) (\(String(format: "%.1f", worst.result.successRate * 100))%)")
        }
    }
    
    public func didFailDownload(with error: Error) {
        print("Unified download failed: \(error.localizedDescription)")
    }
}