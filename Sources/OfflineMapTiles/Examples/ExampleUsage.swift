import Foundation
import CoreLocation

@available(iOS 13.0, macOS 10.15, *)
public final class ExampleUsage: @unchecked Sendable {
    private let sdk = UnifiedOfflineMapTilesSDK.shared
    
    public init() {}
    
    public func demonstrateBasicUsage() async {
        do {
            // Create unified manager with single OpenStreetMap configuration
            let manager = try await sdk.createManager(with: TileServerConfig.openStreetMap)
            
            // Define the geographical bounds (San Francisco area)
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            // Define zoom range (street level to city level)
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
            
            // Estimate download size before starting
            let estimation = try await sdk.estimateDownloadSize(for: [TileServerConfig.openStreetMap], bounds: bounds, zoomRange: zoomRange)
            print("Download estimation:")
            print("- Total tiles: \(estimation.totalTiles)")
            print("- Estimated size: \(estimation.formattedTotalSize)")
            print("- Within recommended limit: \(estimation.isWithinRecommendedLimit ? "Yes" : "No")")
            
            if !estimation.isWithinRecommendedLimit {
                print("⚠️ Warning: Download size exceeds recommended limit")
            }
            
            // Start downloading tiles
            let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            print("Download completed:")
            print("- Total tiles: \(result.overallStats.totalTiles)")
            print("- Successful: \(result.overallStats.totalSuccessful)")
            print("- Failed: \(result.overallStats.totalFailed)")
            print("- Success rate: \(String(format: "%.1f", result.overallStats.overallSuccessRate * 100))%")
            print("- Download time: \(String(format: "%.1f", result.totalDownloadTime))s")
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    public func demonstrateCustomTileServer() async {
        do {
            // Using Mapbox tiles with API key
            let mapboxConfig = TileServerConfig.mapbox(style: "streets-v11", apiKey: "YOUR_MAPBOX_TOKEN")
            let manager = try await sdk.createManager(with: mapboxConfig)
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654),
                southWest: CLLocationCoordinate2D(latitude: 40.7489, longitude: -74.0074)
            )
            
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 18)
            
            let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            print("Custom tile server download result: \(String(format: "%.1f", result.overallStats.overallSuccessRate * 100))%")
            
        } catch {
            print("Custom tile server error: \(error)")
        }
    }
    
    public func demonstrateCacheManagement() async {
        do {
            let manager = try await sdk.createManager(with: TileServerConfig.openStreetMap)
            
            // Check current cache size
            let cacheSize = await manager.getCacheSize()
            print("Current cache size: \(ByteCountFormatter().string(fromByteCount: cacheSize))")
            
            // Clear cache if needed
            if cacheSize > 100_000_000 { // 100MB
                try await manager.clearAllCache()
                print("Cache cleared due to size limit")
            }
            
        } catch {
            print("Cache management error: \(error)")
        }
    }
    
    public func demonstrateMultipleConfigurations() async {
        do {
            // Multiple tile server configurations
            let configs = [
                TileServerConfig.openStreetMap,
                TileServerConfig.cartoDB,
                TileServerConfig.cartoDBDark,
                TileServerConfig.stamenTerrain,
                TileServerConfig.googleMaps(mapType: "s", apiKey: "YOUR_GOOGLE_API_KEY"),
                TileServerConfig.arcGISOnline(service: .worldImagery)
            ]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 14)
            
            // Create unified manager for multiple configs
            let manager = try await sdk.createManager(
                with: configs,
                downloadStrategy: .concurrent, // Download all simultaneously
                storageStrategy: .separate,    // Keep tiles separate by config
                progressStrategy: .detailed    // Detailed progress reporting
            )
            
            // Add progress observer
            let observer = UnifiedConsoleProgressObserver(prefix: "Multi-Config Download")
            manager.addProgressObserver(observer)
            
            // Start download
            let result = try await manager.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            print("\\n=== Multi-Config Download Results ===")
            print("Overall: \(result.overallStats.totalSuccessful)/\(result.overallStats.totalTiles) tiles")
            print("Success rate: \(String(format: "%.1f", result.overallStats.overallSuccessRate * 100))%")
            print("Total time: \(String(format: "%.2f", result.totalDownloadTime))s")
            
            // Show results per configuration
            for (configName, configResult) in result.configResults {
                print("- \(configName): \(configResult.successfulTiles)/\(configResult.totalTiles) tiles")
            }
            
        } catch {
            print("Multi-config error: \(error)")
        }
    }
    
    public func demonstrateSmartManager() async {
        do {
            let configs = [
                TileServerConfig.openStreetMap,
                TileServerConfig.cartoDB
            ]
            
            // Smart manager automatically optimizes based on config count
            let manager = try await sdk.createSmartManager(with: configs)
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 14)
            
            // Use quick download for convenience
            let result = try await sdk.smartQuickDownload(
                configs: configs,
                bounds: bounds,
                zoomRange: zoomRange,
                observer: DetailedUnifiedProgressObserver()
            )
            
            print("Smart manager result: \(result.overallStats.totalSuccessful) tiles downloaded")
            
        } catch {
            print("Smart manager error: \(error)")
        }
    }
    
    public func demonstrateValidation() async {
        do {
            let configs = [TileServerConfig.openStreetMap]
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            // Large zoom range for testing validation
            let zoomRange = ZoomRange(minZoom: 5, maxZoom: 18)
            
            // Validate download before starting
            let validation = try await sdk.validateDownload(
                for: configs,
                bounds: bounds,
                zoomRange: zoomRange,
                maxSizeMB: 600
            )
            
            print("Download validation:")
            print(validation.summary)
            
            if !validation.isValid {
                print("\\nRecommendations:")
                for recommendation in validation.recommendations {
                    print("- \(recommendation)")
                }
            } else {
                print("✅ Download is valid, proceeding...")
                // Would proceed with actual download here
            }
            
        } catch {
            print("Validation error: \(error)")
        }
    }
}

// MARK: - Convenience Methods

@available(iOS 13.0, macOS 10.15, *)
extension ExampleUsage {
    
    /// Demonstrates all examples in sequence
    public func runAllExamples() async {
        print("=== Running All Examples ===\\n")
        
        print("1. Basic Usage:")
        await demonstrateBasicUsage()
        print("\\n" + String(repeating: "=", count: 50) + "\\n")
        
        print("2. Custom Tile Server:")
        await demonstrateCustomTileServer()
        print("\\n" + String(repeating: "=", count: 50) + "\\n")
        
        print("3. Cache Management:")
        await demonstrateCacheManagement()
        print("\\n" + String(repeating: "=", count: 50) + "\\n")
        
        print("4. Multiple Configurations:")
        await demonstrateMultipleConfigurations()
        print("\\n" + String(repeating: "=", count: 50) + "\\n")
        
        print("5. Smart Manager:")
        await demonstrateSmartManager()
        print("\\n" + String(repeating: "=", count: 50) + "\\n")
        
        print("6. Download Validation:")
        await demonstrateValidation()
        print("\\n" + String(repeating: "=", count: 50))
        
        print("\\n✅ All examples completed!")
    }
}