import Foundation
import CoreLocation

/// Examples demonstrating the unified TileService architecture
public final class TileServiceExample {
    
    /// Example 1: Basic setup - one service instance with multiple URLs
    public static func basicMultiServerSetup() async {
        do {
            // Create multiple server configurations
            let servers: [String: TileServerConfig] = [
                "osm": TileServerConfig(
                    name: "osm",
                    baseURL: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    maxZoom: 19
                ),
                "cartodb-light": TileServerConfig(
                    name: "cartodb-light", 
                    baseURL: "https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                    maxZoom: 18
                ),
                "cartodb-dark": TileServerConfig(
                    name: "cartodb-dark",
                    baseURL: "https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png",
                    maxZoom: 18
                )
            ]
            
            // ONE service instance handles ALL servers with NO CONFLICTS
            let tileService = try TileService(serverConfigs: servers)
            
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            print("=== Basic Multi-Server Setup ===")
            
            // Get tiles from different servers - no conflicts!
            if let osmTile = await tileService.getTile(for: coordinate, from: "osm") {
                print("✅ OSM tile: \(osmTile.count) bytes")
            }
            
            if let lightTile = await tileService.getTile(for: coordinate, from: "cartodb-light") {
                print("✅ CartoDB Light tile: \(lightTile.count) bytes")
            }
            
            if let darkTile = await tileService.getTile(for: coordinate, from: "cartodb-dark") {
                print("✅ CartoDB Dark tile: \(darkTile.count) bytes")
            }
            
            // Show that each server has its own isolated cache
            let diagnostics = await tileService.getDiagnostics()
            print("🔍 \(diagnostics.summary)")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 2: Fallback behavior - try servers until one works
    public static func fallbackBehavior() async {
        do {
            let servers = [
                TileServerConfig(
                    name: "primary",
                    baseURL: "https://primary-tiles.example.com/{z}/{x}/{y}.png",
                    maxZoom: 18
                ),
                TileServerConfig(
                    name: "fallback1", 
                    baseURL: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    maxZoom: 19
                ),
                TileServerConfig(
                    name: "fallback2",
                    baseURL: "https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                    maxZoom: 18
                )
            ]
            
            let tileService = try TileService(configs: servers)
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            print("=== Fallback Behavior Example ===")
            
            // Try servers in priority order
            let serverPriority = ["primary", "fallback1", "fallback2"]
            let (tileData, serverUsed) = await tileService.getTileWithFallback(
                for: coordinate,
                serverPriority: serverPriority
            )
            
            if let data = tileData, let server = serverUsed {
                print("✅ Got tile from '\(server)': \(data.count) bytes")
            } else {
                print("❌ No tile available from any server")
            }
            
            // Show which servers have this tile cached
            let serversWithTile = await tileService.getServersWithTile(for: coordinate)
            print("Servers with this tile cached: \(serversWithTile.isEmpty ? "none" : serversWithTile.joined(separator: ", "))")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 3: Batch download from multiple servers simultaneously
    public static func batchDownloadFromMultipleServers() async {
        do {
            let servers = [
                TileServerConfig(
                    name: "osm",
                    baseURL: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    maxZoom: 19
                ),
                TileServerConfig(
                    name: "stamen-terrain",
                    baseURL: "https://stamen-tiles-a.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png",
                    maxZoom: 18
                )
            ]
            
            let tileService = try TileService(configs: servers)
            
            // Define a small area
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            print("=== Batch Download from Multiple Servers ===")
            
            // Download from both servers simultaneously with progress tracking
            let results = await tileService.downloadTiles(
                in: bounds,
                at: 14,
                progressHandler: { serverName, progress in
                    let percentage = String(format: "%.1f", progress.percentage)
                    print("[\(serverName)] Progress: \(percentage)% (\(progress.downloadedTiles)/\(progress.totalTiles))")
                }
            )
            
            // Show results
            for (serverName, successCount) in results {
                print("✅ \(serverName): \(successCount) tiles downloaded")
            }
            
            // Show cache sizes after download
            let cacheSizes = await tileService.getCacheSizes()
            for (serverName, size) in cacheSizes {
                let formattedSize = ByteCountFormatter().string(fromByteCount: size)
                print("📦 \(serverName) cache: \(formattedSize)")
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 4: Cache management per server
    public static func perServerCacheManagement() async {
        do {
            let servers = [
                TileServerConfig.openStreetMap,
                TileServerConfig.cartoDB,
                TileServerConfig.cartoDBDark
            ]
            
            let tileService = try TileService(configs: servers)
            
            print("=== Per-Server Cache Management ===")
            
            // Download some tiles to different servers
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            for server in servers {
                _ = await tileService.downloadTile(for: coordinate, from: server.name)
                print("Downloaded tile to \(server.name)")
            }
            
            // Show individual cache sizes
            let cacheStats = await tileService.getCacheStats()
            for (serverName, stats) in cacheStats.sorted(by: { $0.key < $1.key }) {
                print("📊 \(serverName): \(stats.formattedSize) (\(stats.tileCount) tiles)")
            }
            
            // Clear cache for one server only
            try await tileService.clearCache(for: "OpenStreetMap")
            print("🗑️ Cleared OpenStreetMap cache")
            
            // Show cache sizes after partial clear
            let newCacheStats = await tileService.getCacheStats()
            for (serverName, stats) in newCacheStats.sorted(by: { $0.key < $1.key }) {
                print("📊 After clear - \(serverName): \(stats.formattedSize) (\(stats.tileCount) tiles)")
            }
            
            // Clear all caches
            try await tileService.clearCache()
            print("🗑️ Cleared all caches")
            
            let totalSize = await tileService.getTotalCacheSize()
            print("📦 Total cache size after clear all: \(ByteCountFormatter().string(fromByteCount: totalSize))")
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 5: Smart tile access patterns
    public static func smartTileAccessPatterns() async {
        do {
            let servers = [
                TileServerConfig(
                    name: "fast-server",
                    baseURL: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    maxZoom: 19
                ),
                TileServerConfig(
                    name: "slow-server",
                    baseURL: "https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png",
                    maxZoom: 18
                )
            ]
            
            let tileService = try TileService(configs: servers)
            let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            print("=== Smart Tile Access Patterns ===")
            
            // Pattern 1: Try fast server first, fallback to slow
            print("1. Trying fast server first...")
            if let tile = await tileService.getTile(for: coordinate, from: "fast-server") {
                print("   ✅ Got from fast server: \(tile.count) bytes")
            } else {
                print("   ❌ Fast server failed, trying slow server...")
                if let tile = await tileService.getTile(for: coordinate, from: "slow-server") {
                    print("   ✅ Got from slow server: \(tile.count) bytes")
                }
            }
            
            // Pattern 2: Check what's available in cache first
            print("\n2. Checking cache availability...")
            let availableServers = await tileService.getServersWithTile(for: coordinate)
            if !availableServers.isEmpty {
                print("   📦 Available in cache from: \(availableServers.joined(separator: ", "))")
                if let tile = await tileService.getCachedTile(for: coordinate, from: availableServers[0]) {
                    print("   ✅ Retrieved from cache: \(tile.count) bytes")
                }
            } else {
                print("   📭 Not available in any cache")
            }
            
            // Pattern 3: Automatic fallback
            print("\n3. Using automatic fallback...")
            let (data, serverUsed) = await tileService.getTileWithFallback(for: coordinate)
            if let data = data, let server = serverUsed {
                print("   ✅ Automatic fallback got tile from '\(server)': \(data.count) bytes")
            }
            
            // Pattern 4: Check cache before download decision
            print("\n4. Smart download decision...")
            let testCoordinate = TileCoordinate(x: 5678, y: 9012, zoom: 12)
            let hasCached = await tileService.hasCachedTile(for: testCoordinate, from: "fast-server")
            
            if hasCached {
                let tile = await tileService.getCachedTile(for: testCoordinate, from: "fast-server")
                print("   📦 Using cached tile: \(tile?.count ?? 0) bytes")
            } else {
                print("   ⬇️ Not cached, downloading...")
                let tile = await tileService.downloadTile(for: testCoordinate, from: "fast-server")
                print("   ✅ Downloaded fresh tile: \(tile?.count ?? 0) bytes")
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 6: Debugging and diagnostics
    public static func debuggingAndDiagnostics() async {
        do {
            let servers = [
                TileServerConfig.openStreetMap,
                TileServerConfig.cartoDB,
                TileServerConfig.stamenTerrain
            ]
            
            let tileService = try TileService(configs: servers)
            
            print("=== Debugging and Diagnostics ===")
            
            // Show service configuration
            print("Available servers: \(tileService.availableServers.joined(separator: ", "))")
            
            // Download some test data
            let testCoordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
            
            for serverName in tileService.availableServers.prefix(2) {
                _ = await tileService.downloadTile(for: testCoordinate, from: serverName)
            }
            
            // Get comprehensive diagnostics
            let diagnostics = await tileService.getDiagnostics()
            print("\n🔍 Service Diagnostics:")
            print(diagnostics.summary)
            
            // Get server-specific information
            print("\n🏢 Server Configurations:")
            let allConfigs = tileService.getAllServerConfigs()
            for (name, config) in allConfigs.sorted(by: { $0.key < $1.key }) {
                print("  \(name):")
                print("    Base URL: \(config.baseURL)")
                print("    Max Zoom: \(config.maxZoom)")
                print("    Valid coordinate test: \(config.isCoordinateValid(testCoordinate) ? "✅" : "❌")")
            }
            
            // Test coordinate validation
            print("\n🎯 Coordinate Validation Test:")
            let testCoordinates = [
                TileCoordinate(x: 0, y: 0, zoom: 0),      // Valid
                TileCoordinate(x: -1, y: 0, zoom: 1),     // Invalid X
                TileCoordinate(x: 0, y: -1, zoom: 1),     // Invalid Y
                TileCoordinate(x: 0, y: 0, zoom: 25)      // Invalid zoom
            ]
            
            for coord in testCoordinates {
                for serverName in tileService.availableServers.prefix(1) {
                    if let config = tileService.getServerConfig(serverName) {
                        let isValid = config.isCoordinateValid(coord)
                        print("  \(serverName) - (\(coord.x), \(coord.y), \(coord.zoom)): \(isValid ? "✅" : "❌")")
                    }
                }
            }
            
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    /// Example 7: Error handling and edge cases
    public static func errorHandlingAndEdgeCases() async {
        do {
            let servers = [
                TileServerConfig(
                    name: "valid-server",
                    baseURL: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    maxZoom: 19
                )
            ]
            
            let tileService = try TileService(configs: servers)
            
            print("=== Error Handling and Edge Cases ===")
            
            // Test 1: Invalid server name
            print("1. Testing invalid server name...")
            let invalidServerTile = await tileService.getTile(
                for: TileCoordinate(x: 1234, y: 2345, zoom: 12),
                from: "nonexistent-server"
            )
            print("   Result: \(invalidServerTile == nil ? "✅ Properly returned nil" : "❌ Should have returned nil")")
            
            // Test 2: Invalid coordinates
            print("\n2. Testing invalid coordinates...")
            let invalidCoord = TileCoordinate(x: -1, y: -1, zoom: 25)
            let invalidCoordTile = await tileService.getTile(for: invalidCoord, from: "valid-server")
            print("   Result: \(invalidCoordTile == nil ? "✅ Properly rejected invalid coordinate" : "❌ Should have rejected coordinate")")
            
            // Test 3: Network error simulation (using invalid URL)
            print("\n3. Testing network error handling...")
            let badServer = TileServerConfig(
                name: "bad-server",
                baseURL: "https://definitely-does-not-exist.invalid/{z}/{x}/{y}.png",
                maxZoom: 18
            )
            
            let badTileService = try TileService(configs: [badServer])
            let networkErrorTile = await badTileService.getTile(
                for: TileCoordinate(x: 1, y: 1, zoom: 1),
                from: "bad-server"
            )
            print("   Result: \(networkErrorTile == nil ? "✅ Properly handled network error" : "❌ Should have failed gracefully")")
            
            // Test 4: Empty fallback
            print("\n4. Testing empty fallback...")
            let (emptyFallbackData, emptyFallbackServer) = await badTileService.getTileWithFallback(
                for: TileCoordinate(x: 1, y: 1, zoom: 1)
            )
            print("   Result: \(emptyFallbackData == nil && emptyFallbackServer == nil ? "✅ Properly returned empty result" : "❌ Should have returned empty result")")
            
            // Test 5: Cache operations on empty cache
            print("\n5. Testing cache operations on empty cache...")
            let emptySize = await tileService.getCacheSize(for: "valid-server")
            let hasNonexistentTile = await tileService.hasCachedTile(
                for: TileCoordinate(x: 9999, y: 9999, zoom: 15),
                from: "valid-server"
            )
            print("   Empty cache size: \(emptySize) bytes ✅")
            print("   Has nonexistent tile: \(hasNonexistentTile ? "❌ Should be false" : "✅ Correctly false")")
            
        } catch {
            print("Error during error handling test: \(error.localizedDescription)")
        }
    }
    
    /// Run all examples
    public static func runAllExamples() async {
        print("🚀 Running TileService Examples")
        print("=====================================")
        
        await basicMultiServerSetup()
        print()
        
        await fallbackBehavior()
        print()
        
        await batchDownloadFromMultipleServers()
        print()
        
        await perServerCacheManagement()
        print()
        
        await smartTileAccessPatterns()
        print()
        
        await debuggingAndDiagnostics()
        print()
        
        await errorHandlingAndEdgeCases()
        
        print("=====================================")
        print("✅ All examples completed!")
        print("\n🎯 Key Takeaways:")
        print("- ONE service instance handles MULTIPLE servers")
        print("- NO conflicts between different tile sources")
        print("- Clear, explicit API with server names")
        print("- Proper error handling and validation")
        print("- Isolated cache namespaces per server")
        print("- Flexible fallback and priority strategies")
    }
}