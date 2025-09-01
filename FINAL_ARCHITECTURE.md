# TileService - The Complete Solution

## The Single, Straightforward API

One service class that handles multiple tile server URLs with complete conflict prevention and SOLID design principles.

## Basic Usage

```swift
// Create ONE service with MULTIPLE servers
let tileService = try TileService(configs: [
    TileServerConfig(name: "osm", urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
    TileServerConfig(name: "cartodb", urlTemplate: "https://cartodb-basemaps.com/{z}/{x}/{y}.png"),
    TileServerConfig(name: "stamen", urlTemplate: "https://stamen-tiles.com/{z}/{x}/{y}.png")
])

// Get tiles from any server - NO CONFLICTS!
let coordinate = TileCoordinate(x: 1234, y: 2345, zoom: 12)
let osmTile = await tileService.getTile(for: coordinate, from: "osm")
let cartoTile = await tileService.getTile(for: coordinate, from: "cartodb")
let stamenTile = await tileService.getTile(for: coordinate, from: "stamen")
```

## ✅ Problem Solved

**Before (Conflicts):**
- Tiles from different URLs would overwrite each other
- Complex manager configurations causing confusion
- Unclear which tile came from which source

**After (No Conflicts):**
- Each server has isolated cache namespace
- Simple, explicit API
- Always know which server provided the tile

## Core API Methods

### Tile Retrieval
```swift
// Get tile from specific server (cache-first, downloads if needed)
getTile(for: coordinate, from: serverName) -> Data?

// Try multiple servers in priority order
getTileWithFallback(for: coordinate, serverPriority: [String]) -> (Data?, String?)

// Force download from specific server
downloadTile(for: coordinate, from: serverName) -> Data?

// Get only from cache, no download
getCachedTile(for: coordinate, from: serverName) -> Data?

// Check if tile exists in cache
hasCachedTile(for: coordinate, from: serverName) -> Bool
```

### Batch Operations
```swift
// Download area from specific servers
downloadTiles(in: bounds, at: zoomLevel, from: serverNames, progressHandler: handler)

// Download specific tiles from multiple servers
downloadTiles(coordinates: coords, from: serverNames, progressHandler: handler)
```

### Cache Management
```swift
// Per-server cache operations
getCacheSize(for: serverName) -> Int64
clearCache(for: serverName)
clearCache(for: [serverNames])

// Global cache operations  
getCacheSizes() -> [String: Int64]
getTotalCacheSize() -> Int64
```

### Diagnostics & Debugging
```swift
// Service information
availableServers -> [String]
getServerConfig(serverName) -> TileServerConfig?
getDiagnostics() -> TileServiceDiagnostics

// Tile availability
getServersWithTile(for: coordinate) -> [String]
```

## Conflict Prevention Architecture

### Isolated Storage Namespaces
```
Cache Directory Structure:
├── osm/
│   ├── 12/1234/2345.png      ← OpenStreetMap tile
│   └── 13/2468/4690.png
├── cartodb/  
│   ├── 12/1234/2345.png      ← CartoDB tile (same coordinate, different data!)
│   └── 13/2468/4690.png
└── stamen/
    ├── 12/1234/2345.png      ← Stamen tile (all isolated)
    └── 13/2468/4690.png
```

### Complete Isolation = Zero Conflicts
- Each server gets its own directory
- Same coordinate can have different tiles from different servers
- Cache operations work per-server
- No possibility of tile overwrites

## Advanced Usage Patterns

### Pattern 1: Fallback Strategy
```swift
// Try primary server, fall back to secondary
let (tile, serverUsed) = await tileService.getTileWithFallback(
    for: coordinate,
    serverPriority: ["primary", "backup", "emergency"]
)

if let tile = tile {
    print("Got tile from \(serverUsed!)")
}
```

### Pattern 2: Smart Caching
```swift
// Check cache first to avoid unnecessary downloads
if await tileService.hasCachedTile(for: coordinate, from: "fast-server") {
    tile = await tileService.getCachedTile(for: coordinate, from: "fast-server")
} else {
    // Only download if not cached
    tile = await tileService.downloadTile(for: coordinate, from: "fast-server")
}
```

### Pattern 3: Multi-Server Download
```swift
// Download same area from multiple servers simultaneously 
let results = await tileService.downloadTiles(
    in: bounds,
    at: 15,
    from: ["osm", "cartodb", "stamen"],
    progressHandler: { serverName, progress in
        print("\(serverName): \(progress.percentage)%")
    }
)
```

### Pattern 4: Cache Management
```swift
// Monitor cache usage
let sizes = await tileService.getCacheSizes()
for (server, size) in sizes {
    if size > 100_000_000 { // > 100MB
        try await tileService.clearCache(for: server)
    }
}
```

## SOLID Principles in Action

### Single Responsibility Principle
- `TileService`: Manages multiple tile servers
- `MultiNamespaceStorage`: Isolated file storage
- `TileDownloader`: HTTP tile downloads only
- `TileCalculator`: Coordinate mathematics only

### Open/Closed Principle  
- Easy to add new tile servers without changing existing code
- Core behavior is stable and thoroughly tested

### Liskov Substitution Principle
- All tile server configurations behave consistently
- Swappable server implementations

### Interface Segregation Principle
- Clean method signatures with required parameters only
- No unused or optional complexity

### Dependency Inversion Principle
- Depends on protocols, not concrete implementations
- Easy to test and mock for unit testing

## Error Handling

```swift
do {
    let tileService = try TileService(configs: serverConfigs)
    
    if let tile = await tileService.getTile(for: coordinate, from: "server") {
        // Success - use the tile
        processImage(tile)
    } else {
        // Graceful failure - try fallback or show placeholder
        let (fallbackTile, source) = await tileService.getTileWithFallback(for: coordinate)
        // Handle fallback result...
    }
} catch TileServiceError.noConfigurations {
    print("Please provide at least one server configuration")
} catch {
    print("Service creation failed: \(error)")
}
```

## File Architecture

```
Sources/OfflineMapTiles/
├── Public/
│   └── TileService.swift              # 🎯 THE single API class
├── Core/
│   ├── MultiNamespaceStorage.swift    # Conflict-free storage
│   ├── TileDownloader.swift           # HTTP downloads  
│   └── CoreTypes.swift                # Shared types
└── Examples/
    └── TileServiceExample.swift       # Complete examples
```

## Performance & Features

✅ **Concurrent Downloads**: Multiple servers download simultaneously  
✅ **Smart Caching**: Cache-first with automatic download fallback  
✅ **Bandwidth Control**: Per-server concurrency limits  
✅ **Progress Tracking**: Real-time progress per server  
✅ **Error Recovery**: Graceful fallbacks and error handling  
✅ **Memory Efficient**: Streaming downloads, minimal memory use  
✅ **Thread Safe**: Full async/await with proper synchronization  

## Migration Benefits

**Before (Complex):**
```swift
let sdk = UnifiedOfflineMapTilesSDK()
let manager = try await sdk.createManager(
    with: configs,
    downloadStrategy: .concurrent,
    storageStrategy: .separate,  // Still had conflicts!
    progressStrategy: .detailed
)
let tile = await manager.getTileData(for: coordinate, from: "server")
```

**After (Simple):**
```swift
let tileService = try TileService(configs: configs)
let tile = await tileService.getTile(for: coordinate, from: "server")
```

## Summary

`TileService` is the complete, final solution:

🎯 **One class handles everything** - multiple servers, conflict prevention, caching  
🛡️ **Zero conflicts guaranteed** - isolated storage namespaces  
📝 **Clear, explicit API** - always specify which server you want  
🏗️ **SOLID architecture** - clean, testable, maintainable  
⚡ **High performance** - concurrent downloads with smart caching  
🔍 **Easy debugging** - comprehensive diagnostics and logging  

This is the straightforward, conflict-free tile service architecture you requested.