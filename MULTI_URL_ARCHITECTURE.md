# Multi-URL Single Service Architecture

## Overview

This architecture provides **one service instance** that can handle **multiple tile server URLs** without any conflicts, while following SOLID principles and clear naming conventions.

## Core Requirement Met

✅ **Single service instance with multiple URLs** - `MultiTileService` handles all servers in one instance  
✅ **No tile source conflicts** - each server has its own isolated namespace  
✅ **Clear, explicit API** - always specify which server you want  
✅ **SOLID principles** - clean separation of concerns  

## Basic Usage

```swift
// Create ONE service instance with MULTIPLE server URLs
let servers = [
    TileServerConfig(name: "osm", urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
    TileServerConfig(name: "cartodb", urlTemplate: "https://cartodb-basemaps.com/{z}/{x}/{y}.png"),
    TileServerConfig(name: "stamen", urlTemplate: "https://stamen-tiles.com/{z}/{x}/{y}.png")
]

let tileService = try MultiTileService(configs: servers)

// Get tiles from specific servers - NO CONFLICTS!
let osmTile = await tileService.getTile(for: coordinate, from: "osm")
let cartoTile = await tileService.getTile(for: coordinate, from: "cartodb") 
let stamenTile = await tileService.getTile(for: coordinate, from: "stamen")
```

## Key Architecture Benefits

### ✅ Conflict Prevention
Each server gets its own **isolated namespace** in storage:
```
Cache Structure:
├── osm/
│   ├── 12/1234/2345.png
│   └── 13/2468/4690.png
├── cartodb/
│   ├── 12/1234/2345.png  ← Same coordinate, different tile!
│   └── 13/2468/4690.png
└── stamen/
    ├── 12/1234/2345.png  ← No conflicts possible
    └── 13/2468/4690.png
```

### ✅ Clear API Design
Every method requires explicit server specification:

| Method | Purpose |
|--------|---------|
| `getTile(for:from:)` | Get tile from specific server |
| `getTileWithFallback(for:serverPriority:)` | Try servers in order |
| `downloadTile(for:from:)` | Force download from server |
| `getCachedTile(for:from:)` | Only cached, no download |
| `hasCachedTile(for:from:)` | Check cache for server |

### ✅ Batch Operations
Download from multiple servers simultaneously:
```swift
// Download area from ALL servers at once
let results = await tileService.downloadTiles(
    in: bounds,
    at: zoomLevel,
    progressHandler: { serverName, progress in
        print("\(serverName): \(progress.percentage)%")
    }
)

// Results: ["osm": 45, "cartodb": 43, "stamen": 44] tiles downloaded
```

### ✅ Flexible Fallback Strategies
```swift
// Try servers in priority order until one succeeds
let (tile, serverUsed) = await tileService.getTileWithFallback(
    for: coordinate,
    serverPriority: ["primary", "backup1", "backup2"]
)

if let tile = tile {
    print("Got tile from \(serverUsed!): \(tile.count) bytes")
}
```

## SOLID Principles Applied

### Single Responsibility Principle
- `MultiTileService`: Manages multiple tile servers
- `MultiNamespaceStorage`: Handles isolated file storage
- `TileDownloader`: Only HTTP downloads
- `TileCalculator`: Only coordinate calculations

### Open/Closed Principle
- Easy to add new tile servers
- Core behavior is stable and tested

### Liskov Substitution Principle
- All server configs behave consistently
- Interchangeable server implementations

### Interface Segregation Principle
- Clean, focused method signatures
- No unused parameters or methods

### Dependency Inversion Principle
- Depends on abstractions (protocols)
- Testable and mockable components

## Solving the Original Conflicts

### ❌ Old Problem: Tile Source Conflicts
```swift
// OLD: Complex manager with conflicts
let manager = try sdk.createManager(with: [osm, cartodb], strategy: .merged)
let tile1 = await manager.getTile(coordinate) // Which server??? 🤔
let tile2 = await manager.getTile(coordinate) // Could be different! 🐛
```

### ✅ New Solution: Explicit Server Selection
```swift
// NEW: Clear, conflict-free API
let tileService = try MultiTileService(configs: [osm, cartodb])
let osmTile = await tileService.getTile(for: coordinate, from: "osm")      // Always OSM
let cartoTile = await tileService.getTile(for: coordinate, from: "cartodb") // Always CartoDB
```

## Advanced Features

### Cache Management Per Server
```swift
// Check individual server caches
let cacheSizes = await tileService.getCacheSizes()
// Result: ["osm": 52428800, "cartodb": 31457280, "stamen": 18874368]

// Clear specific server cache
try await tileService.clearCache(for: "osm")

// Clear multiple servers
try await tileService.clearCache(for: ["cartodb", "stamen"])
```

### Diagnostics and Debugging
```swift
// Get comprehensive diagnostics
let diagnostics = await tileService.getDiagnostics()
print(diagnostics.summary)

// Check which servers have a tile
let serversWithTile = await tileService.getServersWithTile(for: coordinate)
print("Available from: \(serversWithTile)")
```

### Smart Access Patterns
```swift
// Pattern 1: Check cache first, then download
if await tileService.hasCachedTile(for: coordinate, from: "fast-server") {
    tile = await tileService.getCachedTile(for: coordinate, from: "fast-server")
} else {
    tile = await tileService.downloadTile(for: coordinate, from: "fast-server")
}

// Pattern 2: Automatic fallback with priority
let (tile, source) = await tileService.getTileWithFallback(
    for: coordinate,
    serverPriority: ["primary", "secondary", "tertiary"]
)
```

## File Structure

```
Sources/OfflineMapTiles/
├── Public/
│   └── MultiTileService.swift         # Main API - handles multiple URLs
├── Core/
│   ├── MultiNamespaceStorage.swift    # Isolated storage per server
│   ├── TileDownloader.swift           # HTTP downloads
│   └── CoreTypes.swift                # Shared types
├── Configuration/
│   └── TileServerConfig.swift         # Server configurations  
└── Examples/
    └── MultiTileServiceExample.swift  # Usage examples
```

## Migration Guide

### Simple, Direct Architecture  
```swift
// Clean, conflict-free approach
let tileService = try TileService(configs: configs)

// Get cached tile (no automatic downloads)
let tile = await tileService.getTile(for: coordinate, from: "OpenStreetMap")

// Or explicitly download when needed
let downloadedTile = await tileService.downloadTile(for: coordinate, from: "OpenStreetMap")
```

## Key Advantages

1. **🎯 Meets Requirement**: One service instance, multiple URLs
2. **🛡️ Prevents Conflicts**: Isolated storage namespaces 
3. **📝 Clear Naming**: Methods explain exactly what they do
4. **🏗️ SOLID Design**: Clean architecture principles
5. **🔍 Easy Debugging**: Explicit server specification
6. **⚡ High Performance**: Concurrent downloads across servers
7. **🧪 Testable**: Clean dependency injection
8. **📈 Scalable**: Easy to add new tile servers

## Error Handling

```swift
// Graceful error handling
if let tile = await tileService.getTile(for: coordinate, from: "server") {
    // Success - use tile
} else {
    // Failed - try fallback or handle gracefully
    let (fallbackTile, source) = await tileService.getTileWithFallback(for: coordinate)
    // ...
}
```

This architecture completely eliminates tile source conflicts while providing a single, powerful service instance that can handle multiple tile server URLs with clear, explicit control.