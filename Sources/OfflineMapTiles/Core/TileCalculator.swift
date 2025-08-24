import Foundation
import CoreLocation

internal final class TileCalculator {
    
    func calculateTiles(for bounds: MapBounds, zoomRange: ZoomRange) -> [TileCoordinate] {
        var tiles: [TileCoordinate] = []
        
        for zoom in zoomRange.minZoom...zoomRange.maxZoom {
            let tilesForZoom = calculateTilesForZoom(bounds: bounds, zoom: zoom)
            tiles.append(contentsOf: tilesForZoom)
        }
        
        return tiles
    }
    
    func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate] {
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
    
    func coordinateToTile(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoordinate {
        let lat = coordinate.latitude * .pi / 180.0
        let lon = coordinate.longitude * .pi / 180.0
        
        let n = pow(2.0, Double(zoom))
        
        let x = Int((lon + .pi) / (2.0 * .pi) * n)
        let y = Int((1.0 - asinh(tan(lat)) / .pi) / 2.0 * n)
        
        return TileCoordinate(x: x, y: y, zoom: zoom)
    }
    
    func tileToCoordinate(tile: TileCoordinate) -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(tile.zoom))
        
        let lonDeg = Double(tile.x) / n * 360.0 - 180.0
        let latRad = atan(sinh(.pi * (1.0 - 2.0 * Double(tile.y) / n)))
        let latDeg = latRad * 180.0 / .pi
        
        return CLLocationCoordinate2D(latitude: latDeg, longitude: lonDeg)
    }
    
    func calculateTileBounds(tile: TileCoordinate) -> MapBounds {
        let topLeft = tileToCoordinate(tile: tile)
        let bottomRight = tileToCoordinate(tile: TileCoordinate(x: tile.x + 1, y: tile.y + 1, zoom: tile.zoom))
        
        return MapBounds(
            northEast: CLLocationCoordinate2D(latitude: topLeft.latitude, longitude: bottomRight.longitude),
            southWest: CLLocationCoordinate2D(latitude: bottomRight.latitude, longitude: topLeft.longitude)
        )
    }
}