import Foundation
import CoreLocation

/// Default implementation of TileCalculatorProtocol
public final class DefaultTileCalculator: TileCalculatorProtocol {
    
    public init() {}
    
    public func calculateTiles(for bounds: MapBounds, zoomRange: ZoomRange) -> [TileCoordinate] {
        var tiles: [TileCoordinate] = []
        
        for zoom in zoomRange.minZoom...zoomRange.maxZoom {
            let tilesForZoom = calculateTilesForZoom(bounds: bounds, zoom: zoom)
            tiles.append(contentsOf: tilesForZoom)
        }
        
        return tiles
    }
    
    public func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate] {
        let topLeftTile = coordinateToTile(coordinate: bounds.northEast, zoom: zoom)
        let bottomRightTile = coordinateToTile(coordinate: bounds.southWest, zoom: zoom)
        
        let minX = min(topLeftTile.x, bottomRightTile.x)
        let maxX = max(topLeftTile.x, bottomRightTile.x)
        let minY = min(topLeftTile.y, bottomRightTile.y)
        let maxY = max(topLeftTile.y, bottomRightTile.y)
        
        var tiles: [TileCoordinate] = []
        
        for x in minX...maxX {
            for y in minY...maxY {
                tiles.append(TileCoordinate(x: x, y: y, zoom: zoom))
            }
        }
        
        return tiles
    }
    
    public func coordinateToTile(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoordinate {
        let lat = coordinate.latitude * .pi / 180.0
        let lon = coordinate.longitude * .pi / 180.0
        
        let n = pow(2.0, Double(zoom))
        
        let x = Int((lon + .pi) / (2.0 * .pi) * n)
        let y = Int((1.0 - asinh(tan(lat)) / .pi) / 2.0 * n)
        
        // Ensure coordinates are within valid range
        let clampedX = max(0, min(Int(n) - 1, x))
        let clampedY = max(0, min(Int(n) - 1, y))
        
        return TileCoordinate(x: clampedX, y: clampedY, zoom: zoom)
    }
    
    public func tileToCoordinate(tile: TileCoordinate) -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(tile.zoom))
        
        let lonDeg = Double(tile.x) / n * 360.0 - 180.0
        let latRad = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y) / n)))
        let latDeg = latRad * 180.0 / .pi
        
        return CLLocationCoordinate2D(latitude: latDeg, longitude: lonDeg)
    }
    
    public func calculateTileBounds(tile: TileCoordinate) -> MapBounds {
        let topLeft = tileToCoordinate(tile: tile)
        let bottomRight = tileToCoordinate(
            tile: TileCoordinate(x: tile.x + 1, y: tile.y + 1, zoom: tile.zoom)
        )
        
        return MapBounds(
            northEast: CLLocationCoordinate2D(
                latitude: topLeft.latitude,
                longitude: bottomRight.longitude
            ),
            southWest: CLLocationCoordinate2D(
                latitude: bottomRight.latitude,
                longitude: topLeft.longitude
            )
        )
    }
}

/// Optimized tile calculator for large areas
public final class OptimizedTileCalculator: TileCalculatorProtocol {
    private let baseCalculator: TileCalculatorProtocol
    
    public init() {
        self.baseCalculator = DefaultTileCalculator()
    }
    
    public func calculateTiles(for bounds: MapBounds, zoomRange: ZoomRange) -> [TileCoordinate] {
        // For large zoom ranges, calculate in batches to avoid memory issues
        let batchSize = 3 // Process 3 zoom levels at a time
        var allTiles: [TileCoordinate] = []
        
        let totalZoomLevels = zoomRange.maxZoom - zoomRange.minZoom + 1
        
        if totalZoomLevels <= batchSize {
            return baseCalculator.calculateTiles(for: bounds, zoomRange: zoomRange)
        }
        
        for batchStart in stride(from: zoomRange.minZoom, through: zoomRange.maxZoom, by: batchSize) {
            let batchEnd = min(batchStart + batchSize - 1, zoomRange.maxZoom)
            let batchRange = ZoomRange(minZoom: batchStart, maxZoom: batchEnd)
            
            let batchTiles = baseCalculator.calculateTiles(for: bounds, zoomRange: batchRange)
            allTiles.append(contentsOf: batchTiles)
        }
        
        return allTiles
    }
    
    public func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate] {
        return baseCalculator.calculateTilesForZoom(bounds: bounds, zoom: zoom)
    }
    
    public func coordinateToTile(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoordinate {
        return baseCalculator.coordinateToTile(coordinate: coordinate, zoom: zoom)
    }
    
    public func tileToCoordinate(tile: TileCoordinate) -> CLLocationCoordinate2D {
        return baseCalculator.tileToCoordinate(tile: tile)
    }
    
    public func calculateTileBounds(tile: TileCoordinate) -> MapBounds {
        return baseCalculator.calculateTileBounds(tile: tile)
    }
}

/// Tile calculator with caching for repeated calculations
public final class CachingTileCalculator: TileCalculatorProtocol, @unchecked Sendable {
    private let baseCalculator: TileCalculatorProtocol
    private var cache: [String: [TileCoordinate]] = [:]
    private let cacheQueue = DispatchQueue(label: "tile.calculator.cache", attributes: .concurrent)
    private let maxCacheSize = 100
    
    public init(baseCalculator: TileCalculatorProtocol = DefaultTileCalculator()) {
        self.baseCalculator = baseCalculator
    }
    
    public func calculateTiles(for bounds: MapBounds, zoomRange: ZoomRange) -> [TileCoordinate] {
        let cacheKey = generateCacheKey(bounds: bounds, zoomRange: zoomRange)
        
        return cacheQueue.sync {
            if let cachedTiles = cache[cacheKey] {
                return cachedTiles
            }
            
            let tiles = baseCalculator.calculateTiles(for: bounds, zoomRange: zoomRange)
            
            // Store in cache if under size limit
            if cache.count < maxCacheSize {
                cache[cacheKey] = tiles
            }
            
            return tiles
        }
    }
    
    public func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate] {
        let zoomRange = ZoomRange(minZoom: zoom, maxZoom: zoom)
        return calculateTiles(for: bounds, zoomRange: zoomRange)
    }
    
    public func coordinateToTile(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoordinate {
        return baseCalculator.coordinateToTile(coordinate: coordinate, zoom: zoom)
    }
    
    public func tileToCoordinate(tile: TileCoordinate) -> CLLocationCoordinate2D {
        return baseCalculator.tileToCoordinate(tile: tile)
    }
    
    public func calculateTileBounds(tile: TileCoordinate) -> MapBounds {
        return baseCalculator.calculateTileBounds(tile: tile)
    }
    
    private func generateCacheKey(bounds: MapBounds, zoomRange: ZoomRange) -> String {
        return "\(bounds.northEast.latitude),\(bounds.northEast.longitude),\(bounds.southWest.latitude),\(bounds.southWest.longitude),\(zoomRange.minZoom),\(zoomRange.maxZoom)"
    }
    
    public func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }
}