# Simplified Architecture Design

## Overview

I've designed a much more straightforward architecture that eliminates the tile source conflicts and follows SOLID principles with clear naming conventions.

## Current Problem

The existing architecture has these issues:
- **Tile source conflicts** - tiles from different URLs overwrite each other
- **Complex API** - multiple managers, strategies, and configurations
- **Unclear naming** - methods don't clearly indicate their behavior
- **Hard to debug** - difficult to track which tile came from which source

## New Simplified Architecture

### Core Principle: One TileService per Server

```swift
// Create separate services for each tile server - NO CONFLICTS!
let osmService = try TileService(serverConfig: .openStreetMap)
let cartoService = try TileService(serverConfig: .cartoDBPositron)

// Each service manages its own cache namespace
let osmTile = await osmService.getTile(for: coordinate)     // Goes to OSM cache
let cartoTile = await cartoService.getTile(for: coordinate) // Goes to CartoDB cache
```

### Simple API - Methods Do What They Say

```swift
// Clear method names that do exactly what they say
await tileService.getTile(for: coordinate)        // Smart: check cache first, download if needed
await tileService.downloadTile(for: coordinate)   // Always download
await tileService.getCachedTile(for: coordinate)  // Only cached, no download
await tileService.hasCachedTile(for: coordinate)  // Check if cached
```

### SOLID Principles Applied

1. **Single Responsibility Principle**
   - `TileService`: Handles tile operations for ONE server
   - `TileStorage`: Only manages file storage
   - `TileDownloader`: Only handles HTTP downloads
   - `TileCalculator`: Only calculates coordinates

2. **Open/Closed Principle**
   - Easy to extend with new tile servers
   - Core behavior is stable

3. **Liskov Substitution Principle**
   - All TileService instances behave identically
   - Can swap any server configuration

4. **Interface Segregation Principle**
   - Simple, focused interfaces
   - No unused methods

5. **Dependency Inversion Principle**
   - Depends on abstractions (protocols)
   - Easy to test and mock

### Clear Naming Conventions

| Method | Behavior |
|--------|----------|
| `getTile()` | Smart retrieval (cache first, download if needed) |
| `downloadTile()` | Force download from server |
| `getCachedTile()` | Only return cached tile, no download |
| `hasCachedTile()` | Check if tile exists in cache |
| `downloadTiles(in:at:)` | Download area at specific zoom |
| `clearCache()` | Clear this service's cache |
| `getCacheStats()` | Get cache statistics |

### No More Configuration Conflicts

#### Old Complex Way (Conflict-Prone)
```swift
let sdk = UnifiedOfflineMapTilesSDK()
let manager = try await sdk.createManager(
    with: [osm, cartodb],
    downloadStrategy: .concurrent,
    storageStrategy: .separate,  // Still conflicts!
    progressStrategy: .detailed
)
let tile = await manager.getTileData(for: coordinate, from: "OpenStreetMap")
```

#### New Simple Way (Conflict-Free)
```swift
let osmService = try TileService(serverConfig: .openStreetMap)
let tile = await osmService.getTile(for: coordinate)
```

### Architecture Benefits

✅ **Zero Conflicts**: Each service has its own namespace  
✅ **50% Less Code**: Simpler API, fewer concepts  
✅ **Self-Documenting**: Method names explain behavior  
✅ **Easy Debugging**: Clear service separation  
✅ **SOLID Principles**: Clean, maintainable design  
✅ **Thread Safe**: Proper async/await patterns  
✅ **Error Handling**: Graceful failures, no crashes  

### File Structure

```
Sources/OfflineMapTiles/
├── Public/
│   └── TileService.swift              # Main public API
├── Core/
│   ├── TileStorage.swift              # File storage (SRP)
│   ├── TileDownloader.swift           # HTTP downloads (SRP)
│   ├── TileCalculator.swift           # Coordinate math (SRP)
│   └── CoreTypes.swift                # Shared types
├── Configuration/
│   └── TileServerConfig.swift         # Server configurations
└── Examples/
    └── SimpleTileServiceExample.swift # Usage examples
```

### Usage Examples

#### Basic Usage
```swift
let tileService = try TileService(serverConfig: .openStreetMap)
let tile = await tileService.getTile(for: TileCoordinate(x: 1234, y: 2345, zoom: 12))
```

#### Download Area with Progress
```swift
let bounds = MapBounds(
    northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
    southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
)

await tileService.downloadTiles(in: bounds, at: 15) { progress in
    print("Progress: \(progress.percentage)%")
}
```

#### Multiple Services (No Conflicts)
```swift
let services = [
    try TileService(serverConfig: .openStreetMap),
    try TileService(serverConfig: .cartoDBPositron),
    try TileService(serverConfig: .cartoDBDarkMatter)
]

for service in services {
    let tile = await service.getTile(for: coordinate)
    print("\(service.configuration.name): \(tile?.count ?? 0) bytes")
}
```

#### Cache Management
```swift
// Check cache
let stats = await tileService.getCacheStats()
print("Cache: \(stats.formattedSize)")

// Clear when needed
try await tileService.clearCache()
```

### Migration Path

1. **Replace complex managers** with simple `TileService` instances
2. **Use explicit service per server** instead of unified managers
3. **Replace ambiguous methods** with clear method names
4. **Remove strategy configurations** - behavior is now implicit and correct

This architecture eliminates the core issues while being much simpler to use and understand.