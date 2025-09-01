import Foundation
import CoreLocation

/// Simple examples demonstrating the straightforward TileService API
public final class SimpleTileServiceExample {
    
    /// Example 1: Basic tile retrieval - the simplest possible usage
    public static func basicTileRetrieval() async {
        do {
            // Create server configuration
            let serverConfig = TileServerConfig(
                name: "OpenStreetMap",
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                maxZoom: 19
            )
            
            // Create tile service for this server
            let tileService = try TileService(serverConfig: serverConfig)
            
            // Get a specific tile - downloads if not cached, returns cached if available
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            if let tileData = await tileService.getTile(for: coordinate) {
                print("✅ Got tile: \(tileData.count) bytes")
            } else {
                print("❌ Failed to get tile")
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 2: Download tiles for an area with progress tracking
    public static func downloadAreaWithProgress() async {
        do {
            // Create CartoDB server configuration
            let serverConfig = TileServerConfig(
                name: "CartoDB-Positron",
                urlTemplate: "https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                maxZoom: 18
            )
            
            let tileService = try TileService(serverConfig: serverConfig)
            
            // Define a small area (San Francisco)
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            print("Starting download for area...")
            
            // Download with progress tracking
            let successCount = await tileService.downloadTiles(in: bounds, at: 15) { progress in
                let percentage = String(format: "%.1f", progress.percentage)
                print("Progress: \(percentage)% (\(progress.successfulTiles)/\(progress.totalTiles))")
            }
            
            print("✅ Downloaded \(successCount) tiles successfully")
            
            // Check cache stats
            let cacheStats = await tileService.getCacheStats()
            print("Cache size: \(cacheStats.formattedSize) (\(cacheStats.tileCount) tiles)")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 3: Working with multiple tile services (no conflicts!)
    public static func multipleTileServices() async {
        do {
            // Create multiple services for different servers
            let osmService = try TileService(serverConfig: TileServerConfig(
                name: "OpenStreetMap",
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                maxZoom: 19
            ))
            
            let cartoService = try TileService(serverConfig: TileServerConfig(
                name: "CartoDB-DarkMatter",
                urlTemplate: "https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png",
                maxZoom: 18
            ))
            
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            print("=== Multiple Tile Services Example ===")
            
            // Get tiles from both services - completely isolated, no conflicts
            if let osmTile = await osmService.getTile(for: coordinate) {
                print("OSM tile: \(osmTile.count) bytes")
            }
            
            if let cartoTile = await cartoService.getTile(for: coordinate) {
                print("CartoDB tile: \(cartoTile.count) bytes")
            }
            
            // Check individual cache sizes
            let osmStats = await osmService.getCacheStats()
            let cartoStats = await cartoService.getCacheStats()
            
            print("OSM cache: \(osmStats.formattedSize)")
            print("CartoDB cache: \(cartoStats.formattedSize)")
            
            print("✅ No conflicts - each service manages its own cache!")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 4: Cache management operations
    public static func cacheManagement() async {
        do {
            let serverConfig = TileServerConfig(
                name: "TestServer",
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                maxZoom: 19
            )
            
            let tileService = try TileService(serverConfig: serverConfig)
            
            print("=== Cache Management Example ===")
            
            // Check initial cache state
            var cacheStats = await tileService.getCacheStats()
            print("Initial cache: \(cacheStats.formattedSize) (\(cacheStats.tileCount) tiles)")
            
            // Download some tiles
            let bounds = MapBounds(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                radiusInMeters: 1000
            )
            
            await tileService.downloadTiles(in: bounds, at: 12)
            
            // Check cache after download
            cacheStats = await tileService.getCacheStats()
            print("After download: \(cacheStats.formattedSize) (\(cacheStats.tileCount) tiles)")
            
            // Clear cache
            try await tileService.clearCache()
            print("✅ Cache cleared")
            
            // Verify cache is empty
            cacheStats = await tileService.getCacheStats()
            print("After clear: \(cacheStats.formattedSize) (\(cacheStats.tileCount) tiles)")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 5: Cached vs downloaded tile access patterns
    public static func cacheVsDownloadPatterns() async {
        do {
            let serverConfig = TileServerConfig(
                name: "TestServer",
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                maxZoom: 19
            )
            
            let tileService = try TileService(serverConfig: serverConfig)
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            print("=== Cache vs Download Patterns ===")
            
            // Pattern 1: Check cache first
            if let cachedTile = await tileService.getCachedTile(for: coordinate) {
                print("Found in cache: \(cachedTile.count) bytes")
            } else {
                print("Not in cache, need to download")
            }
            
            // Pattern 2: Always download (bypasses cache check)
            if let downloadedTile = await tileService.downloadTile(for: coordinate) {
                print("Downloaded: \(downloadedTile.count) bytes")
            }
            
            // Pattern 3: Get tile (smart - checks cache first, downloads if needed)
            if let smartTile = await tileService.getTile(for: coordinate) {
                print("Smart retrieval: \(smartTile.count) bytes")
            }
            
            // Pattern 4: Check if tile exists in cache
            let exists = await tileService.hasCachedTile(for: coordinate)
            print("Tile exists in cache: \(exists)")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 6: Error handling and validation
    public static func errorHandlingExample() async {
        print("=== Error Handling Example ===")
        
        do {
            // Valid configuration
            let validConfig = TileServerConfig(
                name: "ValidServer",
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                maxZoom: 19
            )
            
            let tileService = try TileService(serverConfig: validConfig)
            
            // Try to get a tile that likely doesn't exist (extreme coordinates)
            let extremeCoordinate = TileCoordinate(x: 999999, y: 999999, zoom: 20)
            
            if let tile = await tileService.getTile(for: extremeCoordinate) {
                print("Got extreme tile: \(tile.count) bytes")
            } else {
                print("Failed to get extreme tile (expected)")
            }
            
            // Test with valid coordinate
            let validCoordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            if let tile = await tileService.getTile(for: validCoordinate) {
                print("✅ Got valid tile: \(tile.count) bytes")
            } else {
                print("❌ Failed to get valid tile")
            }
            
        } catch {
            print("Configuration error: \(error.localizedDescription)")
        }
    }
    
    /// Example 7: Using different tile server configurations
    public static func differentTileServers() async {
        let servers = [
            ("OpenStreetMap", "https://tile.openstreetmap.org/{z}/{x}/{y}.png", 19),
            ("CartoDB Positron", "https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png", 18),
            ("CartoDB Dark Matter", "https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png", 18),
            ("Stamen Terrain", "https://stamen-tiles-a.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png", 18)
        ]
        
        print("=== Different Tile Servers Example ===")
        
        let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
        
        for (name, urlTemplate, maxZoom) in servers {
            do {
                let config = TileServerConfig(
                    name: name,
                    urlTemplate: urlTemplate,
                    maxZoom: maxZoom
                )
                
                let service = try TileService(serverConfig: config)
                
                if let tile = await service.getTile(for: coordinate) {
                    print("\(name): ✅ \(tile.count) bytes")
                } else {
                    print("\(name): ❌ Failed")
                }
                
            } catch {
                print("\(name): Error - \(error.localizedDescription)")
            }
        }
    }
    
    /// Run all examples
    public static func runAllExamples() async {
        print("🚀 Running Simple Tile Service Examples")
        print("=======================================")
        
        await basicTileRetrieval()
        print()
        
        await downloadAreaWithProgress()
        print()
        
        await multipleTileServices()
        print()
        
        await cacheManagement()
        print()
        
        await cacheVsDownloadPatterns()
        print()
        
        await errorHandlingExample()
        print()
        
        await differentTileServers()
        
        print("=======================================")
        print("✅ All examples completed!")
    }
}