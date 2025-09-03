# OfflineMapTiles Architecture

This document describes the simplified architecture of the OfflineMapTiles library.

## 🎯 Design Philosophy

**Simple, Key-Based Tile Storage with Multiple URL Template Support**

- **One TileService** for all operations
- **Key-based storage** using coordinates + URL template hash
- **Multiple URL templates** supported in single download
- **Clean public API** with only essential methods
- **Proper cancellation** support for downloads

## 📁 Current Directory Structure

```
Sources/OfflineMapTiles/
├── Public/
│   └── TileService.swift              # Main public API class
├── Core/
│   ├── TileStorage.swift              # Simple key-based file storage
│   ├── TileDownloader.swift           # HTTP tile downloading
│   ├── TileCalculator.swift           # Tile coordinate calculations
│   ├── TileKey.swift                  # Key generation for storage
│   ├── Logger.swift                   # Simple logging utility
│   ├── AsyncSemaphore.swift           # Concurrency control
│   └── CoreTypes.swift                # Core data structures
└── Examples/
    └── Usage examples and tests
```

## 🏗️ Architecture Overview

### Core Components

1. **TileService** - Main public API
   - `getTile(x:y:z:urlTemplate:)` - Retrieve cached tile
   - `download(bounds:zoomRange:urlTemplates:)` - Download tiles from multiple sources  
   - `clearCache()` - Clear all cached tiles
   - `cancelDownloads()` - Cancel ongoing downloads

2. **TileStorage** - Simple file system storage
   - Key-based storage using SHA256 hashes
   - Automatic directory creation
   - Thread-safe operations

3. **TileDownloader** - HTTP tile fetching
   - Basic HTTP client with error handling
   - Configurable timeout and retry logic

4. **TileCalculator** - Coordinate calculations
   - Convert geographic bounds to tile coordinates
   - Support for different zoom levels
   - TMS format support

5. **TileKey** - Storage key generation
   - Combines coordinates and URL template for unique keys
   - SHA256 hashing for consistent naming
   - Collision-resistant design

## 🔄 Data Flow

```
User Request
    ↓
TileService (Public API)
    ↓
TileStorage ←→ TileKey (for cache lookup)
    ↓
TileDownloader (if not cached)
    ↓ 
TileCalculator (for coordinate math)
```

## 🚀 Key Features

### Multiple URL Template Support
```swift
await tileService.download(
    bounds: bounds,
    zoomRange: 10...15,
    urlTemplates: [
        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        "https://cartodb.com/{z}/{x}/{y}.png",
        "https://satellite.example.com/{z}/{x}/{y}.jpg"
    ]
)
```

### Key-Based Storage
- Each tile stored with unique key: `SHA256(zoom-x-y-urlTemplate)`
- No namespace conflicts between different tile sources
- Efficient cache lookups

### Progress Tracking
- Total progress across all zoom levels and templates
- Real-time updates via progress handler
- Accurate completion percentages

### Cancellation Support
- Cancel ongoing downloads
- Proper task cleanup
- Graceful handling of partial downloads

## 📊 Public API

### Essential Methods Only

```swift
public final class TileService {
    // Initialization
    public init() throws
    
    // Core operations
    public func getTile(x: Int, y: Int, z: Int, urlTemplate: String) async -> Data?
    public func download(bounds: MapBounds, zoomRange: ClosedRange<Int>, 
                        urlTemplates: [String]) async -> Int
    public func clearCache() async throws
    public func cancelDownloads()
}
```

### Private Implementation Details
All other methods are private to maintain clean API:
- `hasCachedTile()` - Internal cache checking
- `deleteTile()` - Internal tile removal  
- `getCacheSize()` - Internal cache statistics
- `getTileCount()` - Internal tile counting

## 🎯 Design Principles

### Single Responsibility
- **TileService**: High-level tile operations
- **TileStorage**: File system persistence  
- **TileDownloader**: HTTP network operations
- **TileCalculator**: Mathematical calculations
- **TileKey**: Key generation logic

### Minimal Public API
- Only expose what users actually need
- Hide implementation complexity
- Clear, predictable method behavior

### Key-Based Storage
- Eliminates tile source conflicts
- Simple, predictable storage patterns
- Easy cache management

### Async/Await First
- Modern concurrency patterns
- Proper cancellation support
- Thread-safe operations

## 📈 Benefits

### Simplicity
- Single service class handles everything
- No complex configuration required
- Predictable behavior

### Flexibility  
- Support multiple tile sources simultaneously
- Easy to add new URL templates
- Configurable zoom ranges and bounds

### Performance
- Efficient concurrent downloads
- Smart caching with unique keys
- Proper resource management

### Reliability
- Graceful error handling
- Cancellable operations
- Thread-safe design

## 🔧 Usage Examples

### Basic Tile Retrieval
```swift
let tileService = try TileService()
let tile = await tileService.getTile(
    x: 1234, y: 2345, z: 12,
    urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
)
```

### Multi-Source Downloads
```swift
let bounds = MapBounds(/* geographic bounds */)
let templates = [
    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "https://cartodb.com/{z}/{x}/{y}.png"
]

let downloaded = await tileService.download(
    bounds: bounds,
    zoomRange: 10...15,
    urlTemplates: templates
) { progress in
    print("Downloaded \(progress.downloadedTiles)/\(progress.totalTiles)")
}
```

### Cache Management
```swift
// Clear all cached tiles
try await tileService.clearCache()

// Cancel ongoing downloads
tileService.cancelDownloads()
```

This architecture provides a clean, simple, and powerful tile caching solution with support for multiple tile sources and modern Swift concurrency patterns.