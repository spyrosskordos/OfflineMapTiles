import Foundation
import CoreLocation

/// Protocol defining tile calculation operations
public protocol TileCalculatorProtocol: Sendable {
    /// Calculates all tiles for the given bounds and zoom range
    /// - Parameters:
    ///   - bounds: The geographic bounds
    ///   - zoomRange: The zoom range
    /// - Returns: Array of tile coordinates
    func calculateTiles(for bounds: MapBounds, zoomRange: ZoomRange) -> [TileCoordinate]
    
    /// Calculates tiles for a specific zoom level
    /// - Parameters:
    ///   - bounds: The geographic bounds
    ///   - zoom: The zoom level
    /// - Returns: Array of tile coordinates for the zoom level
    func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate]
    
    /// Converts a geographic coordinate to a tile coordinate
    /// - Parameters:
    ///   - coordinate: The geographic coordinate
    ///   - zoom: The zoom level
    /// - Returns: The tile coordinate
    func coordinateToTile(coordinate: CLLocationCoordinate2D, zoom: Int) -> TileCoordinate
    
    /// Converts a tile coordinate to a geographic coordinate
    /// - Parameter tile: The tile coordinate
    /// - Returns: The geographic coordinate
    func tileToCoordinate(tile: TileCoordinate) -> CLLocationCoordinate2D
    
    /// Calculates the geographic bounds of a tile
    /// - Parameter tile: The tile coordinate
    /// - Returns: The geographic bounds of the tile
    func calculateTileBounds(tile: TileCoordinate) -> MapBounds
}

/// Protocol for different tile coordinate systems
public protocol TileCoordinateSystemProtocol: Sendable {
    /// Converts standard tile coordinates to the specific coordinate system
    /// - Parameter tile: Standard tile coordinate
    /// - Returns: Converted tile coordinate
    func convertTileCoordinate(_ tile: TileCoordinate) -> TileCoordinate
    
    /// Generates URL-specific coordinate representation (e.g., quadkey)
    /// - Parameter tile: The tile coordinate
    /// - Returns: String representation for URL
    func generateCoordinateString(for tile: TileCoordinate) -> String?
}