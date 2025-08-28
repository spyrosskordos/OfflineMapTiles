import Foundation
import CoreLocation

/// Comprehensive examples demonstrating the unified SDK that handles both single and multiple configurations seamlessly
public final class UnifiedExamples {
    
    // MARK: - Basic Examples
    
    /// Example 1: Simple single configuration download (same API works for multi-config)
    public static func simpleSingleConfig() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // Create a single configuration
            let config = TileServerConfigFactory.openStreetMap()
            
            // The unified manager handles single configs elegantly
            let manager = try await sdk.createManager(with: config)
            
            // Add observer
            let observer = UnifiedConsoleProgressObserver(prefix: "Single Config")
            manager.addProgressObserver(observer)
            
            // Define download area
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 15)
            
            // Download - same API for single or multiple configs!
            let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            print("Single config result: \(result.overallStats.totalSuccessful) tiles downloaded")
            
        } catch {
            print("Single config error: \(error.localizedDescription)")
        }
    }
    
    /// Example 2: Multiple configurations using the same API
    public static func simpleMultiConfig() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // Create multiple configurations
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB(style: .positron),
                TileServerConfigFactory.cartoDB(style: .darkMatter)
            ]
            
            // Same API call - just pass multiple configs!
            let manager = try await sdk.createManager(with: configs)
            
            // Same observer interface
            let observer = UnifiedConsoleProgressObserver(prefix: "Multi Config")
            manager.addProgressObserver(observer)
            
            // Same download call
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 15)
            
            let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            print("Multi config result: \(result.overallStats.totalSuccessful) tiles from \(result.configResults.count) configs")
            
        } catch {
            print("Multi config error: \(error.localizedDescription)")
        }
    }
    
    /// Example 3: Smart manager that automatically optimizes based on configuration count
    public static func smartManager() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // Test with different numbers of configurations
            let testCases = [
                ("Single Config", [TileServerConfigFactory.openStreetMap()]),
                ("Two Configs", [TileServerConfigFactory.openStreetMap(), TileServerConfigFactory.cartoDB()]),
                ("Five Configs", [
                    TileServerConfigFactory.openStreetMap(),
                    TileServerConfigFactory.cartoDB(),
                    TileServerConfigFactory.cartoDB(style: .darkMatter),
                    TileServerConfigFactory.cartoDB(style: .voyager),
                    TileServerConfigFactory.custom()
                        .name("Custom OSM")
                        .baseURL("https://tile.openstreetmap.de/{z}/{x}/{y}.png")
                        .build()
                ])
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 14)
            
            for (testName, configs) in testCases {
                print("\n--- Testing \(testName) ---")
                
                // Smart manager automatically chooses optimal strategies
                let manager = try await sdk.createSmartManager(with: configs)
                
                print("Configuration count: \(manager.configurationCount)")
                print("Is multi-config: \(manager.isMultiConfig)")
                
                let observer = DetailedUnifiedProgressObserver()
                manager.addProgressObserver(observer)
                
                let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
                
                print("✅ \(testName) completed: \(result.overallStats.totalSuccessful) total tiles")
                print("   Success rate: \(String(format: "%.1f", result.overallStats.overallSuccessRate * 100))%")
            }
            
        } catch {
            print("Smart manager error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Advanced Strategy Examples
    
    /// Example 4: Different download strategies
    public static func downloadStrategies() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB(),
                TileServerConfigFactory.cartoDB(style: .darkMatter)
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 13)
            
            let strategies: [(String, UnifiedTileManager.DownloadStrategy)] = [
                ("Concurrent", .concurrent),
                ("Sequential", .sequential),
                ("Priority (OSM first)", .priority(["OpenStreetMap"]))
            ]
            
            for (strategyName, strategy) in strategies {
                print("\n--- Testing \(strategyName) Strategy ---")
                
                let manager = try await sdk.createManager(
                    with: configs,
                    downloadStrategy: strategy,
                    progressStrategy: .detailed
                )
                
                let observer = UnifiedConsoleProgressObserver(prefix: strategyName)
                manager.addProgressObserver(observer)
                
                let startTime = Date()
                let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
                let totalTime = Date().timeIntervalSince(startTime)
                
                print("   Strategy: \(strategyName)")
                print("   Time: \(String(format: "%.2f", totalTime))s")
                print("   Speed: \(String(format: "%.1f", result.overallStats.averageDownloadSpeed)) tiles/sec")
            }
            
        } catch {
            print("Strategy comparison error: \(error.localizedDescription)")
        }
    }
    
    /// Example 5: Storage strategies
    public static func storageStrategies() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB()
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 13)
            
            let strategies: [(String, UnifiedTileManager.StorageStrategy)] = [
                ("Separate", .separate),
                ("Merged", .merged)
            ]
            
            for (strategyName, storageStrategy) in strategies {
                print("\n--- Testing \(strategyName) Storage ---")
                
                let manager = try await sdk.createManager(
                    with: configs,
                    storageStrategy: storageStrategy
                )
                
                let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
                
                // Test tile retrieval
                let testCoordinate = TileCoordinate(x: 163, y: 395, zoom: 12)
                
                if storageStrategy == .separate {
                    // With separate storage, we can get tiles from specific configs
                    let osmData = await manager.getTileData(for: testCoordinate, from: "OpenStreetMap")
                    let cartoData = await manager.getTileData(for: testCoordinate, from: "CartoDB Positron")
                    
                    print("   OSM tile available: \(osmData != nil)")
                    print("   CartoDB tile available: \(cartoData != nil)")
                    
                    let availableConfigs = await manager.getAvailableConfigurations(for: testCoordinate)
                    print("   Available configs for tile: \(availableConfigs)")
                    
                } else {
                    // With merged storage, get from primary config
                    let data = await manager.getTileData(for: testCoordinate)
                    print("   Merged tile available: \(data != nil)")
                    
                    // Test fallback
                    let fallbackResult = await manager.getTileDataWithFallback(for: testCoordinate)
                    print("   Fallback source: \(fallbackResult.source ?? "none")")
                }
                
                print("   Total tiles downloaded: \(result.overallStats.totalSuccessful)")
            }
            
        } catch {
            print("Storage strategy error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Progress Reporting Examples
    
    /// Example 6: Different progress reporting strategies
    public static func progressStrategies() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB(),
                TileServerConfigFactory.cartoDB(style: .darkMatter)
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 13)
            
            let strategies: [(String, UnifiedTileManager.ProgressStrategy)] = [
                ("Unified", .unified),
                ("Individual", .individual),
                ("Detailed", .detailed)
            ]
            
            for (strategyName, progressStrategy) in strategies {
                print("\n--- Testing \(strategyName) Progress ---")
                
                let manager = try await sdk.createManager(
                    with: configs,
                    progressStrategy: progressStrategy
                )
                
                let observer = CustomUnifiedProgressObserver(strategy: strategyName)
                manager.addProgressObserver(observer)
                
                let _ = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            }
            
        } catch {
            print("Progress strategy error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Convenience Methods Examples
    
    /// Example 7: Quick download methods
    public static func quickDownloads() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 13)
            
            // Quick single config download
            print("--- Quick Single Config ---")
            let singleConfig = TileServerConfigFactory.openStreetMap()
            let singleResult = try await sdk.quickDownload(
                config: singleConfig,
                bounds: bounds,
                zoomRange: zoomRange,
                observer: UnifiedConsoleProgressObserver(prefix: "Quick Single")
            )
            print("Single quick download: \(singleResult.overallStats.totalSuccessful) tiles")
            
            // Quick multi config download
            print("\n--- Quick Multi Config ---")
            let multiConfigs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB()
            ]
            let multiResult = try await sdk.quickDownload(
                configs: multiConfigs,
                bounds: bounds,
                zoomRange: zoomRange,
                observer: UnifiedConsoleProgressObserver(prefix: "Quick Multi")
            )
            print("Multi quick download: \(multiResult.overallStats.totalSuccessful) tiles from \(multiResult.configResults.count) configs")
            
            // Smart quick download (automatically optimized)
            print("\n--- Smart Quick Download ---")
            let smartResult = try await sdk.smartQuickDownload(
                configs: multiConfigs,
                bounds: bounds,
                zoomRange: zoomRange,
                observer: UnifiedConsoleProgressObserver(prefix: "Smart Quick")
            )
            print("Smart quick download: \(smartResult.overallStats.totalSuccessful) tiles")
            
        } catch {
            print("Quick download error: \(error.localizedDescription)")
        }
    }
    
    /// Example 8: Size estimation and validation
    public static func estimationAndValidation() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB(),
                TileServerConfigFactory.cartoDB(style: .darkMatter)
            ]
            
            // Different sized areas
            let testAreas = [
                ("Small", MapBounds(
                    northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                    southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
                ), ZoomRange(minZoom: 12, maxZoom: 14)),
                
                ("Medium", MapBounds(
                    northEast: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.4),
                    southWest: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.5)
                ), ZoomRange(minZoom: 10, maxZoom: 15)),
                
                ("Large", MapBounds(
                    northEast: CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0),
                    southWest: CLLocationCoordinate2D(latitude: 37.5, longitude: -123.0)
                ), ZoomRange(minZoom: 8, maxZoom: 16))
            ]
            
            for (areaName, bounds, zoomRange) in testAreas {
                print("\n--- \(areaName) Area Analysis ---")
                
                // Estimate size
                let estimation = try await sdk.estimateDownloadSize(
                    for: configs,
                    bounds: bounds,
                    zoomRange: zoomRange
                )
                
                print("Total tiles: \(estimation.totalTiles)")
                print("Total size: \(estimation.formattedTotalSize)")
                print("Within limit: \(estimation.isWithinRecommendedLimit ? "✅" : "❌")")
                
                // Show per-config breakdown
                for (configName, configEstimation) in estimation.configEstimations {
                    print("  \(configName): \(configEstimation.formattedSize)")
                }
                
                if let largest = estimation.largestConfiguration {
                    print("Largest config: \(largest.name) (\(largest.estimation.formattedSize))")
                }
                
                // Validate download
                let validation = try await sdk.validateDownload(
                    for: configs,
                    bounds: bounds,
                    zoomRange: zoomRange
                )
                
                print("Validation: \(validation.summary)")
                
                if !validation.recommendations.isEmpty {
                    print("Recommendations:")
                    for recommendation in validation.recommendations {
                        print("  • \(recommendation)")
                    }
                }
                
                // Only download if valid and small
                if validation.isValid && areaName == "Small" {
                    print("Proceeding with download...")
                    let result = try await sdk.smartQuickDownload(
                        configs: configs,
                        bounds: bounds,
                        zoomRange: zoomRange
                    )
                    print("Downloaded: \(result.overallStats.totalSuccessful) tiles")
                }
            }
            
        } catch {
            print("Estimation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Management Example
    
    /// Example 9: Cache management
    public static func cacheManagement() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // Check initial cache size
            let initialSize = await sdk.getCacheSize()
            print("Initial cache size: \(ByteCountFormatter().string(fromByteCount: initialSize))")
            
            // Download some tiles
            let configs = [
                TileServerConfigFactory.openStreetMap(),
                TileServerConfigFactory.cartoDB()
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
                southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 13)
            
            let manager = try await sdk.createManager(with: configs, storageStrategy: .separate)
            let _ = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            // Check cache size after download
            let afterDownloadSize = await sdk.getCacheSize()
            print("Cache size after download: \(ByteCountFormatter().string(fromByteCount: afterDownloadSize))")
            
            // Get per-config cache sizes
            let cacheSizes = await manager.getCacheSizes()
            print("Per-config cache sizes:")
            for (configName, size) in cacheSizes {
                print("  \(configName): \(ByteCountFormatter().string(fromByteCount: size))")
            }
            
            // Clear specific config cache
            try await manager.clearCache(for: "OpenStreetMap")
            print("Cleared OpenStreetMap cache")
            
            let afterClearSize = await sdk.getCacheSize()
            print("Cache size after clearing OSM: \(ByteCountFormatter().string(fromByteCount: afterClearSize))")
            
            // Clear all cache
            try await sdk.clearAllCache()
            print("Cleared all cache")
            
            let finalSize = await sdk.getCacheSize()
            print("Final cache size: \(ByteCountFormatter().string(fromByteCount: finalSize))")
            
        } catch {
            print("Cache management error: \(error.localizedDescription)")
        }
    }
    
    /// Example 15: Data deletion with detailed information
    public static func dataDelectionWithInfo() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // First, check what data exists
            let dataInfo = await sdk.getStoredDataInfo()
            print("Before deletion: \(dataInfo.summary)")
            
            if dataInfo.hasStoredData {
                // Delete all data with detailed information
                let deletionInfo = try await sdk.deleteAllDataWithInfo()
                print("Deletion completed: \(deletionInfo.formattedSummary)")
                
                if deletionInfo.hadDataToDelete {
                    print("Successfully freed up space!")
                } else {
                    print("No data was found to delete")
                }
            } else {
                print("No stored data to delete")
            }
            
            // Verify deletion
            let afterInfo = await sdk.getStoredDataInfo()
            print("After deletion: \(afterInfo.summary)")
            
        } catch {
            print("Data deletion error: \(error.localizedDescription)")
        }
    }
    
    /// Example 16: Selective data deletion for specific configurations
    public static func selectiveDataDeletion() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            // Get current data info
            let initialInfo = await sdk.getStoredDataInfo()
            print("Current stored data: \(initialInfo.summary)")
            
            // Delete data for specific configurations
            let configsToDelete = ["OpenStreetMap", "CartoDB-Positron"]
            try await sdk.deleteData(for: configsToDelete)
            print("Deleted data for configurations: \(configsToDelete.joined(separator: ", "))")
            
            // Check remaining data
            let remainingInfo = await sdk.getStoredDataInfo()
            print("Remaining data: \(remainingInfo.summary)")
            
            // Alternative: Delete data for just one configuration
            try await sdk.deleteData(for: "CartoDB-DarkMatter")
            print("Deleted data for CartoDB-DarkMatter configuration")
            
        } catch {
            print("Selective deletion error: \(error.localizedDescription)")
        }
    }
    
    /// Example 17: Complete data management workflow
    public static func completeDataManagementWorkflow() async {
        do {
            let sdk = UnifiedOfflineMapTilesSDK()
            
            print("=== Data Management Workflow ===")
            
            // Step 1: Check current data
            let currentInfo = await sdk.getStoredDataInfo()
            print("1. Current data status: \(currentInfo.summary)")
            
            // Step 2: If we have data, show size information
            if currentInfo.hasStoredData {
                let totalSize = await sdk.getCacheSize()
                let formattedSize = ByteCountFormatter().string(fromByteCount: totalSize)
                print("2. Total cache size: \(formattedSize)")
                
                // Step 3: Delete with tracking
                print("3. Deleting all data...")
                let deletionInfo = try await sdk.deleteAllDataWithInfo()
                print("   \(deletionInfo.formattedSummary)")
                
                // Step 4: Verify deletion was successful
                let finalInfo = await sdk.getStoredDataInfo()
                print("4. Final status: \(finalInfo.summary)")
                
                if !finalInfo.hasStoredData {
                    print("✅ All data successfully deleted!")
                } else {
                    print("⚠️  Some data may still remain")
                }
                
            } else {
                print("2. No data to delete")
            }
            
            print("=== Workflow Complete ===")
            
        } catch {
            print("Data management workflow error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Custom Progress Observer for Examples

private final class CustomUnifiedProgressObserver: UnifiedProgressObserver {
    private let strategy: String
    
    init(strategy: String) {
        self.strategy = strategy
    }
    
    func didUpdateUnifiedProgress(_ progress: UnifiedProgress) {
        if strategy == "Unified" || strategy == "Detailed" {
            print("  [\(strategy)] Overall: \(String(format: "%.1f", progress.overallPercentage))% (\(progress.totalDownloaded)/\(progress.totalTiles))")
        }
    }
    
    func didUpdateConfigProgress(configName: String, progress: DownloadProgress) {
        if strategy == "Individual" || strategy == "Detailed" {
            print("  [\(strategy)] \(configName): \(String(format: "%.1f", progress.percentage))%")
        }
    }
    
    func didCompleteDownload(with result: UnifiedDownloadResult) {
        print("  [\(strategy)] ✅ Completed: \(result.overallStats.totalSuccessful) tiles from \(result.configResults.count) config(s)")
    }
    
    func didFailDownload(with error: Error) {
        print("  [\(strategy)] ❌ Failed: \(error.localizedDescription)")
    }
}

// MARK: - Usage Summary

/*
 ## Unified SDK Usage Summary
 
 The UnifiedOfflineMapTilesSDK provides a single, consistent API that works seamlessly with both single and multiple configurations:
 
 ### Simple Usage (works for 1 or N configurations):
 ```swift
 let sdk = UnifiedOfflineMapTilesSDK()
 
 // Single config
 let manager = try await sdk.createManager(with: singleConfig)
 
 // Multiple configs - same API!
 let manager = try await sdk.createManager(with: multipleConfigs)
 
 // Smart manager - automatically optimizes
 let manager = try await sdk.createSmartManager(with: anyConfigs)
 
 // Same download API regardless of config count
 let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
 ```
 
 ### Key Benefits:
 1. **Unified API**: Same methods work for single or multiple configurations
 2. **Smart Defaults**: Automatically chooses optimal strategies based on config count
 3. **Flexible Strategies**: Fine-tune download, storage, and progress reporting behavior
 4. **Comprehensive Progress**: Unified progress reporting across all configurations
 5. **Size Estimation**: Accurate estimation and validation across multiple configs
 6. **Tile Retrieval**: Flexible tile access with fallback strategies
 7. **Cache Management**: Intelligent caching with per-config and unified operations
 
 ### Strategies Available:
 - **Download**: concurrent, sequential, priority-based
 - **Storage**: single namespace, separate namespaces, merged
 - **Progress**: unified, individual, detailed reporting
 
 This unified approach eliminates the complexity of managing separate single and multi-config APIs while providing powerful customization options for advanced use cases.
 */