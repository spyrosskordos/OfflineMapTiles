import Foundation
import CoreLocation

@available(iOS 13.0, macOS 10.15, *)
public final class ExampleUsage: OfflineMapTilesDelegate, @unchecked Sendable {
    private var mapTiles: OfflineMapTiles?
    
    public init() {}
    
    public func demonstrateBasicUsage() async {
        do {
            // Initialize the library with default OpenStreetMap tile server
            mapTiles = try OfflineMapTiles(tileServerConfig: .openStreetMap)
            mapTiles?.delegate = self
            
            // Define the geographical bounds (San Francisco area)
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            // Define zoom range (street level to city level)
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
            
            // Estimate download size before starting
            if let estimation = try mapTiles?.estimateDownloadSize(for: bounds, zoomRange: zoomRange) {
                print("Download estimation:")
                print("- Total tiles: \(estimation.totalTiles)")
                print("- Estimated size: \(estimation.formattedSize)")
                print("- Within recommended limit: \(estimation.isWithinRecommendedLimit ? "Yes" : "No")")
                
                if !estimation.isWithinRecommendedLimit {
                    print("⚠️ Warning: Download size exceeds recommended 600MB limit")
                }
            }
            
            // Start downloading tiles
            let result = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
            
            print("Download completed:")
            print("- Total tiles: \(result?.totalTiles ?? 0)")
            print("- Successful: \(result?.successfulTiles ?? 0)")
            print("- Failed: \(result?.failedTiles ?? 0)")
            print("- Success rate: \(String(format: "%.1f", (result?.successRate ?? 0) * 100))%")
            print("- Download time: \(String(format: "%.1f", result?.downloadTime ?? 0))s")
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    public func demonstrateCustomTileServer() async {
        do {
            // Using Mapbox tiles with API key
            let mapboxConfig = TileServerConfig.mapbox(style: "streets-v11", apiKey: "YOUR_MAPBOX_TOKEN")
            mapTiles = try OfflineMapTiles(tileServerConfig: mapboxConfig)
            mapTiles?.delegate = self
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 40.7829, longitude: -73.9654),
                southWest: CLLocationCoordinate2D(latitude: 40.7489, longitude: -74.0074)
            )
            
            let zoomRange = ZoomRange(minZoom: 12, maxZoom: 18)
            
            let result = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
            print("Custom tile server download result: \(result?.successRate ?? 0)")
            
        } catch {
            print("Custom tile server error: \(error)")
        }
    }
    
    public func demonstrateCacheManagement() async {
        do {
            mapTiles = try OfflineMapTiles()
            
            // Check current cache size
            let cacheSize = await mapTiles?.getCacheSize() ?? 0
            print("Current cache size: \(formatBytes(cacheSize))")
            
            // Get a specific tile
            let tileCoordinate = TileCoordinate(x: 1024, y: 1536, zoom: 12)
            if let tileData = await mapTiles?.getTileData(for: tileCoordinate) {
                print("Retrieved tile data: \(tileData.count) bytes")
            }
            
            // Clear all cached tiles
            try await mapTiles?.clearCache()
            print("Cache cleared")
            
        } catch {
            print("Cache management error: \(error)")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - OfflineMapTilesDelegate
    
    public func offlineMapTiles(_ manager: OfflineMapTiles, didUpdateProgress progress: DownloadProgress) {
        print("Progress: \(String(format: "%.1f", progress.percentage))% (\(progress.downloadedTiles)/\(progress.totalTiles))")
        
        if let currentTile = progress.currentTile {
            print("Downloading tile: z=\(currentTile.zoom), x=\(currentTile.x), y=\(currentTile.y)")
        }
    }
    
    public func offlineMapTiles(_ manager: OfflineMapTiles, didFailWithError error: OfflineMapTilesError) {
        print("Download failed with error: \(error.localizedDescription)")
    }
    
    public func offlineMapTilesDidFinish(_ manager: OfflineMapTiles, with result: DownloadResult) {
        print("Download finished successfully!")
        print("Final result - Success rate: \(String(format: "%.1f", result.successRate * 100))%")
    }
}

// MARK: - Advanced Usage Examples

@available(iOS 13.0, macOS 10.15, *)
public extension ExampleUsage {
    
    func demonstrateProgressTracking() async {
        do {
            mapTiles = try OfflineMapTiles()
            mapTiles?.delegate = self
            
            let largeBounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.3),
                southWest: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.5)
            )
            
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 15)
            
            // This will trigger multiple progress updates
            _ = try await mapTiles?.downloadTiles(for: largeBounds, zoomRange: zoomRange)
            
        } catch {
            print("Progress tracking error: \(error)")
        }
    }
    
    func demonstrateErrorHandling() async {
        do {
            // Invalid tile server URL
            let invalidTileServer = "invalid-url"
            mapTiles = try OfflineMapTiles(tileServerURL: invalidTileServer)
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.3),
                southWest: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.5)
            )
            
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
            
            _ = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
            
        } catch let error as OfflineMapTilesError {
            switch error {
            case .invalidBounds:
                print("The provided bounds are invalid")
            case .networkError(let networkError):
                print("Network error occurred: \(networkError)")
            case .fileSystemError(let fsError):
                print("File system error: \(fsError)")
            case .invalidTileServer:
                print("The tile server URL is invalid")
            case .downloadCancelled:
                print("Download was cancelled")
            case .storageQuotaExceeded:
                print("Storage quota exceeded")
            case .invalidZoomLevel:
                print("Zoom level is outside the supported range")
            case .unsupportedTileFormat:
                print("Unsupported tile format")
            case .downloadSizeExceedsLimit(let sizeError):
                print("Download too large: \(sizeError.localizedDescription)")
            }
        } catch {
            print("Unexpected error: \(error)")
        }
    }
    
    func demonstrateCancellation() async {
        do {
            mapTiles = try OfflineMapTiles()
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.3),
                southWest: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.5)
            )
            
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
            
            // Start download in background
            Task { [weak self] in
                _ = try await self?.mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
            }
            
            // Cancel after 5 seconds
            try await Task.sleep(nanoseconds: 5_000_000_000)
            mapTiles?.cancelDownload()
            
        } catch {
            print("Cancellation demo error: \(error)")
        }
    }
    
    // MARK: - New Tile Server Examples
    
    func demonstrateVariousTileServers() async {
        let servers: [TileServerConfig] = [
            .openStreetMap,
            .cartoDB,
            .cartoDBDark,
            .stamenTerrain,
            TileServerConfig.googleMaps(mapType: .satellite, apiKey: "YOUR_GOOGLE_API_KEY"),
            TileServerConfig.arcGISOnline(service: .worldImagery)
        ]
        
        let bounds = MapBounds(
            northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
            southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
        
        let zoomRange = ZoomRange(minZoom: 10, maxZoom: 14)
        
        for serverConfig in servers {
            do {
                print("\n--- Testing \(serverConfig.name) ---")
                mapTiles = try OfflineMapTiles(tileServerConfig: serverConfig)
                mapTiles?.delegate = self
                
                let result = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
                print("✅ \(serverConfig.name): \(result?.successfulTiles ?? 0) tiles downloaded")
                
                // Clear cache for next server
                try await mapTiles?.clearCache()
                
            } catch {
                print("❌ \(serverConfig.name) failed: \(error)")
            }
        }
    }
    
    func demonstrateCustomTileServerWithRetryPolicy() async {
        do {
            let customRetryPolicy = RetryPolicy(
                maxAttempts: 5,
                baseDelay: 0.5,
                maxDelay: 10.0,
                backoffMultiplier: 2.0
            )
            
            let customConfig = TileServerConfig(
                name: "Custom Resilient Server",
                baseURL: "https://unreliable-tiles.example.com/{z}/{x}/{y}.png",
                format: .png,
                customHeaders: [
                    "User-Agent": "MyCustomApp/1.0",
                    "X-API-Version": "v2"
                ],
                retryPolicy: customRetryPolicy
            )
            
            mapTiles = try OfflineMapTiles(tileServerConfig: customConfig)
            mapTiles?.delegate = self
            
            print("Using custom retry policy: \(customRetryPolicy.maxAttempts) attempts")
            print("Server info: \(mapTiles?.serverInfo.name ?? "Unknown")")
            
        } catch {
            print("Custom server setup error: \(error)")
        }
    }
    
    func demonstrateDifferentTileFormats() async {
        let formatExamples: [(TileServerConfig, String)] = [
            (.openStreetMap, "PNG format tiles"),
            (.stamenTerrain, "JPEG format tiles"),
            (TileServerConfig(
                name: "WebP Example",
                baseURL: "https://example.com/{z}/{x}/{y}.webp",
                format: .webp
            ), "WebP format tiles")
        ]
        
        for (config, description) in formatExamples {
            print("\n--- \(description) ---")
            print("Format: \(config.format.rawValue)")
            print("Max Zoom: \(config.maxZoom)")
            print("Attribution: \(config.attribution ?? "None")")
            
            // You could initialize and test each configuration here
        }
    }
    
    func demonstrateQuadkeyAndTMSSupport() async {
        let quadkeyConfig = TileServerConfig(
            name: "Quadkey Example",
            baseURL: "https://ecn.t3.tiles.virtualearth.net/tiles/r{quadkey}.jpeg?g=1",
            format: .jpeg
        )
        
        let tmsConfig = TileServerConfig(
            name: "TMS Example",
            baseURL: "https://tms.example.com/{z}/{x}/{-y}.png",
            format: .png
        )
        
        let testTile = TileCoordinate(x: 1234, y: 5678, zoom: 12)
        
        print("Quadkey URL: \(quadkeyConfig.tileURL(for: testTile))")
        print("TMS URL: \(tmsConfig.tileURL(for: testTile))")
    }
    
    // MARK: - Size Estimation Examples
    
    func demonstrateSizeEstimation() async {
        do {
            mapTiles = try OfflineMapTiles()
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            // Test different zoom ranges
            let zoomRanges = [
                ZoomRange(minZoom: 10, maxZoom: 12),
                ZoomRange(minZoom: 10, maxZoom: 15),
                ZoomRange(minZoom: 10, maxZoom: 18)
            ]
            
            for zoomRange in zoomRanges {
                if let estimation = try mapTiles?.estimateDownloadSize(for: bounds, zoomRange: zoomRange) {
                    print("\n--- Zoom \(zoomRange.minZoom)-\(zoomRange.maxZoom) ---")
                    print("📏 Total tiles: \(estimation.totalTiles)")
                    print("💾 Estimated size: \(estimation.formattedSize) (\(String(format: "%.1f", estimation.estimatedSizeMB)) MB)")
                    print("📁 Average tile size: \(ByteCountFormatter().string(fromByteCount: estimation.averageTileSize))")
                    print("✅ Within limit: \(estimation.isWithinRecommendedLimit ? "Yes" : "No")")
                    
                    // Show tile count per zoom level
                    for (zoom, count) in estimation.zoomLevels.sorted(by: { $0.key < $1.key }) {
                        print("  - Zoom \(zoom): \(count) tiles")
                    }
                }
            }
            
        } catch {
            print("Size estimation error: \(error)")
        }
    }
    
    func demonstrateSizeValidationAndLimits() async {
        do {
            mapTiles = try OfflineMapTiles()
            
            // Large area that might exceed limits
            let largeBounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0),
                southWest: CLLocationCoordinate2D(latitude: 37.5, longitude: -122.8)
            )
            
            let highZoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
            
            // Get estimation first
            if let estimation = try mapTiles?.estimateDownloadSize(for: largeBounds, zoomRange: highZoomRange) {
                print("\n--- Large Area Download ---")
                print("📏 Estimated: \(estimation.formattedSize)")
                print("⚠️ Exceeds 600MB limit: \(!estimation.isWithinRecommendedLimit)")
                
                if estimation.isWithinRecommendedLimit {
                    // Safe to download
                    let result = try await mapTiles?.downloadTiles(for: largeBounds, zoomRange: highZoomRange)
                    print("✅ Download completed: \(result?.successfulTiles ?? 0) tiles")
                } else {
                    print("❌ Skipping download due to size limit")
                    
                    // Try with custom higher limit (1GB)
                    print("\n--- Trying with 1GB limit ---")
                    do {
                        let result = try await mapTiles?.downloadTiles(for: largeBounds, zoomRange: highZoomRange, maxDownloadSizeMB: 1024)
                        print("✅ Download with custom limit completed: \(result?.successfulTiles ?? 0) tiles")
                    } catch {
                        print("❌ Still exceeds 1GB limit: \(error)")
                    }
                }
            }
            
        } catch {
            print("Size validation error: \(error)")
        }
    }
    
    func demonstrateProgressiveDownloadPlanning() async {
        do {
            mapTiles = try OfflineMapTiles()
            
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            print("\n--- Progressive Download Planning ---")
            
            // Plan downloads in phases to stay under limits
            let phases = [
                ("Base Map", ZoomRange(minZoom: 8, maxZoom: 12)),
                ("Street Level", ZoomRange(minZoom: 13, maxZoom: 15)),
                ("High Detail", ZoomRange(minZoom: 16, maxZoom: 18))
            ]
            
            var totalEstimatedSize: Int64 = 0
            
            for (phaseName, zoomRange) in phases {
                if let estimation = try mapTiles?.estimateDownloadSize(for: bounds, zoomRange: zoomRange) {
                    totalEstimatedSize += estimation.estimatedSizeBytes
                    
                    print("📦 \(phaseName):")
                    print("  Size: \(estimation.formattedSize)")
                    print("  Tiles: \(estimation.totalTiles)")
                    print("  Downloadable: \(estimation.isWithinRecommendedLimit ? "✅" : "❌")")
                    
                    if estimation.isWithinRecommendedLimit {
                        // Could download this phase
                        print("  ➡️ Ready for download")
                    } else {
                        print("  ⚠️ Consider smaller area or zoom range")
                    }
                }
            }
            
            let totalFormatted = ByteCountFormatter().string(fromByteCount: totalEstimatedSize)
            print("\n📋 Total if all phases downloaded: \(totalFormatted)")
            
        } catch {
            print("Progressive planning error: \(error)")
        }
    }
}