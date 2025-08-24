# OfflineMapTiles

A high-performance Swift library for downloading and persisting offline map tiles with progress tracking and comprehensive error handling.

## Features

- ✅ **High Performance**: Concurrent downloading with configurable limits
- ✅ **Progress Tracking**: Real-time download progress with percentage and tile-level details
- ✅ **Smart Caching**: Efficient file system storage with automatic cleanup
- ✅ **Error Handling**: Comprehensive error types with retry mechanisms
- ✅ **Flexible Tile Servers**: Support for 15+ popular tile servers with presets
- ✅ **Multiple Formats**: PNG, JPEG, WebP tile format support
- ✅ **Advanced URL Patterns**: Subdomain rotation, quadkey, TMS coordinate systems
- ✅ **Modern Swift**: Built with Swift 6, async/await, and structured concurrency
- ✅ **Cross-Platform**: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/OfflineMapTiles.git", from: "1.0.0")
]
```

Or add it through Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

```swift
import OfflineMapTiles
import CoreLocation

class MapDownloadManager: OfflineMapTilesDelegate {
    private var mapTiles: OfflineMapTiles?
    
    func downloadSanFranciscoTiles() async {
        do {
            // Initialize with default OpenStreetMap tiles
            mapTiles = try OfflineMapTiles(tileServerConfig: .openStreetMap)
            mapTiles?.delegate = self
            
            // Define the geographical bounds
            let bounds = MapBounds(
                northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
                southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            )
            
            // Define zoom range
            let zoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
            
            // Estimate download size first
            let estimation = try mapTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
            print("Estimated download: \(estimation.formattedSize) (\(estimation.totalTiles) tiles)")
            print("Within 600MB limit: \(estimation.isWithinRecommendedLimit)")
            
            // Start downloading (automatically validates size)
            let result = try await mapTiles.downloadTiles(for: bounds, zoomRange: zoomRange)
            print("Downloaded \(result?.successfulTiles ?? 0) tiles successfully!")
            
        } catch {
            print("Download failed: \(error)")
        }
    }
    
    // MARK: - OfflineMapTilesDelegate
    
    func offlineMapTiles(_ manager: OfflineMapTiles, didUpdateProgress progress: DownloadProgress) {
        print("Progress: \(String(format: "%.1f", progress.percentage))%")
    }
    
    func offlineMapTiles(_ manager: OfflineMapTiles, didFailWithError error: OfflineMapTilesError) {
        print("Error: \(error.localizedDescription)")
    }
    
    func offlineMapTilesDidFinish(_ manager: OfflineMapTiles, with result: DownloadResult) {
        print("Success rate: \(String(format: "%.1f", result.successRate * 100))%")
    }
}
```

## Advanced Usage

### Built-in Tile Server Presets

```swift
// OpenStreetMap (default)
let osmTiles = try OfflineMapTiles(tileServerConfig: .openStreetMap)

// CartoDB Light theme
let cartoTiles = try OfflineMapTiles(tileServerConfig: .cartoDB)

// Mapbox with API key
let mapboxTiles = try OfflineMapTiles(
    tileServerConfig: .mapbox(style: "streets-v11", apiKey: "YOUR_TOKEN")
)

// Google Maps satellite
let googleTiles = try OfflineMapTiles(
    tileServerConfig: .googleMaps(mapType: .satellite, apiKey: "YOUR_KEY")
)

// ArcGIS World Imagery
let arcgisTiles = try OfflineMapTiles(
    tileServerConfig: .arcGISOnline(service: .worldImagery)
)
```

### Custom Tile Server Configuration

```swift
let customConfig = TileServerConfig(
    name: "My Custom Server",
    baseURL: "https://tiles.example.com/{z}/{x}/{y}.png",
    format: .png,
    minZoom: 0,
    maxZoom: 18,
    attribution: "© My Company",
    customHeaders: ["Authorization": "Bearer token"],
    retryPolicy: .aggressive
)

let customTiles = try OfflineMapTiles(tileServerConfig: customConfig)
```

### Size Estimation and Validation

```swift
// Estimate download size before starting
let estimation = try mapTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)

print("Total tiles: \(estimation.totalTiles)")
print("Estimated size: \(estimation.formattedSize)")
print("Average tile size: \(ByteCountFormatter().string(fromByteCount: estimation.averageTileSize))")
print("Within 600MB limit: \(estimation.isWithinRecommendedLimit)")

// Tiles per zoom level
for (zoom, count) in estimation.zoomLevels.sorted(by: { $0.key < $1.key }) {
    print("Zoom \(zoom): \(count) tiles")
}

// Downloads are automatically validated against 600MB limit
// Use skipSizeValidation: true to bypass if needed
try await mapTiles.downloadTiles(for: bounds, zoomRange: zoomRange, skipSizeValidation: true)

// Or set a custom size limit
try await mapTiles.downloadTiles(for: bounds, zoomRange: zoomRange, maxDownloadSizeMB: 1024)
```

### Cache Management

```swift
// Check cache size
let cacheSize = await mapTiles?.getCacheSize() ?? 0
print("Cache size: \(ByteCountFormatter().string(fromByteCount: cacheSize))")

// Get specific tile
let tile = TileCoordinate(x: 1024, y: 1536, zoom: 12)
if let data = await mapTiles?.getTileData(for: tile) {
    // Use tile data
}

// Clear cache
try await mapTiles?.clearCache()
```

### Error Handling

```swift
do {
    let result = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
} catch let error as OfflineMapTilesError {
    switch error {
    case .invalidBounds:
        print("Invalid geographical bounds")
    case .networkError(let networkError):
        print("Network issue: \(networkError)")
    case .fileSystemError(let fsError):
        print("Storage issue: \(fsError)")
    case .downloadCancelled:
        print("Download was cancelled")
    case .storageQuotaExceeded:
        print("Not enough storage space")
    case .invalidTileServer:
        print("Invalid tile server URL")
    }
}
```

### Download Cancellation

```swift
// Start download
Task {
    _ = try await mapTiles?.downloadTiles(for: bounds, zoomRange: zoomRange)
}

// Cancel if needed
mapTiles?.cancelDownload()
```

## API Reference

### Core Classes

#### `OfflineMapTiles`
Main class for downloading and managing offline map tiles.

**Methods:**
- `init(tileServerConfig:storageDirectory:)`: Initialize with tile server configuration
- `init(tileServerURL:storageDirectory:)`: Legacy initializer for backward compatibility
- `estimateDownloadSize(for:zoomRange:)`: Calculate estimated download size and tile count
- `downloadTiles(for:zoomRange:)`: Download tiles with automatic size validation (600MB limit)
- `downloadTiles(for:zoomRange:maxDownloadSizeMB:)`: Download with custom size limit
- `downloadTiles(for:zoomRange:skipSizeValidation:)`: Download bypassing size validation
- `cancelDownload()`: Cancel current download operation
- `getTileData(for:)`: Retrieve cached tile data
- `clearCache()`: Remove all cached tiles
- `getCacheSize()`: Get current cache size in bytes

#### `MapBounds`
Defines geographical boundaries for tile downloads.

```swift
let bounds = MapBounds(
    northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
    southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
)
```

#### `ZoomRange`
Specifies the zoom levels to download (0-20).

```swift
let zoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
```

#### `TileCoordinate`
Represents a specific tile in the tile pyramid.

```swift
let tile = TileCoordinate(x: 1024, y: 1536, zoom: 12)
```

#### `TileSizeEstimation`
Provides detailed information about estimated download size.

```swift
struct TileSizeEstimation {
    let totalTiles: Int              // Total number of tiles
    let estimatedSizeBytes: Int64    // Estimated size in bytes
    let estimatedSizeMB: Double      // Estimated size in MB
    let averageTileSize: Int64       // Average bytes per tile
    let tileFormat: TileFormat       // Tile format (PNG, JPEG, etc.)
    let zoomLevels: [Int: Int]       // Tiles per zoom level
    
    var formattedSize: String        // Human-readable size ("2.5 MB")
    var isWithinRecommendedLimit: Bool // Whether under 600MB limit
}
```

#### `TileServerConfig`
Configures tile server settings with advanced URL pattern support.

```swift
let config = TileServerConfig(
    name: "Custom Server",
    baseURL: "https://{s}.example.com/{z}/{x}/{y}.{format}",
    format: .png,
    retryPolicy: .aggressive
)
```

**Supported URL Patterns:**
- `{z}/{x}/{y}`: Standard tile coordinates
- `{s}`: Subdomain rotation (a, b, c, d)
- `{quadkey}`: Bing Maps quadkey format
- `{-y}`: TMS (Tile Map Service) y-coordinate
- `{api_key}`: API key substitution

**Built-in Presets:**
- OpenStreetMap variants (`.openStreetMap`, `.openStreetMapDe`)
- CartoDB themes (`.cartoDB`, `.cartoDBDark`)
- Stamen maps (`.stamenTerrain`, `.stamenWatercolor`)
- Commercial providers (Mapbox, Google, Bing, ArcGIS) with API key support

### Delegate Protocol

Implement `OfflineMapTilesDelegate` to receive progress updates and handle completion:

```swift
func offlineMapTiles(_ manager: OfflineMapTiles, didUpdateProgress progress: DownloadProgress)
func offlineMapTiles(_ manager: OfflineMapTiles, didFailWithError error: OfflineMapTilesError)
func offlineMapTilesDidFinish(_ manager: OfflineMapTiles, with result: DownloadResult)
```

## Performance Characteristics

- **Concurrent Downloads**: 8 simultaneous tile downloads by default
- **Retry Logic**: 3 retry attempts with exponential backoff
- **Smart Caching**: Automatic cache cleanup when size exceeds 1GB
- **Memory Efficient**: Streaming downloads with minimal memory footprint
- **Network Optimized**: Proper HTTP headers and connection pooling

## Error Types

- `invalidBounds`: Invalid geographical bounds
- `networkError(Error)`: Network-related errors
- `fileSystemError(Error)`: Storage-related errors
- `invalidTileServer`: Invalid tile server URL
- `downloadCancelled`: Download was cancelled
- `storageQuotaExceeded`: Insufficient storage space
- `downloadSizeExceedsLimit`: Estimated download size exceeds the specified limit
- `invalidZoomLevel`: Zoom level outside server's supported range
- `unsupportedTileFormat`: Tile format not supported for size estimation

## Requirements

- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.