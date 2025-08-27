import Foundation

public final class TileSizeEstimator: @unchecked Sendable {
    private let tileCalculator: TileCalculatorProtocol
    private let maxDownloadSize: Int64 = 600 * 1024 * 1024 // 600MB
    
    // Average tile sizes in bytes based on format and content type
    private let averageTileSizes: [TileFormat: Int64] = [
        .png: 12_000,     // ~12KB for typical PNG tiles
        .jpg: 8_000,      // ~8KB for typical JPEG tiles  
        .jpeg: 8_000,     // ~8KB for typical JPEG tiles
        .webp: 6_000,     // ~6KB for WebP tiles (better compression)
        .mvt: 3_000       // ~3KB for vector tiles
    ]
    
    init(tileCalculator: TileCalculatorProtocol) {
        self.tileCalculator = tileCalculator
    }
    
    func estimateDownloadSize(for bounds: MapBounds, zoomRange: ZoomRange, tileFormat: TileFormat) throws -> TileSizeEstimation {
        // Validate bounds
        guard bounds.northEast.latitude > bounds.southWest.latitude &&
              bounds.northEast.longitude > bounds.southWest.longitude else {
            throw SizeEstimationError.invalidBoundsForEstimation
        }
        
        // Get average tile size for format
        guard let avgTileSize = averageTileSizes[tileFormat] else {
            throw SizeEstimationError.unsupportedTileFormatForEstimation
        }
        
        // Calculate tiles for each zoom level
        var zoomLevelCounts: [Int: Int] = [:]
        var totalTiles = 0
        
        for zoom in zoomRange.minZoom...zoomRange.maxZoom {
            let tilesForZoom = tileCalculator.calculateTilesForZoom(bounds: bounds, zoom: zoom)
            let count = tilesForZoom.count
            zoomLevelCounts[zoom] = count
            totalTiles += count
        }
        
        // Calculate size estimation with format-specific adjustments
        let baseEstimatedSize = Int64(totalTiles) * avgTileSize
        let adjustedSize = applyContentAdjustments(baseSize: baseEstimatedSize, bounds: bounds, zoomRange: zoomRange, format: tileFormat)
        
        let estimation = TileSizeEstimation(
            totalTiles: totalTiles,
            estimatedSizeBytes: adjustedSize,
            averageTileSize: avgTileSize,
            tileFormat: tileFormat,
            zoomLevels: zoomLevelCounts
        )
        
        return estimation
    }
    
    func validateDownloadSize(_ estimation: TileSizeEstimation, customLimit: Int64? = nil) throws {
        let limit = customLimit ?? maxDownloadSize
        
        if estimation.estimatedSizeBytes > limit {
            throw SizeEstimationError.downloadSizeExceedsLimit(
                estimatedSize: estimation.estimatedSizeBytes,
                limit: limit
            )
        }
    }
    
    private func applyContentAdjustments(baseSize: Int64, bounds: MapBounds, zoomRange: ZoomRange, format: TileFormat) -> Int64 {
        var adjustedSize = baseSize
        
        // Geographic content adjustments
        let latRange = bounds.northEast.latitude - bounds.southWest.latitude
        let lonRange = bounds.northEast.longitude - bounds.southWest.longitude
        let area = latRange * lonRange
        
        // Ocean/water areas tend to compress better
        let isLargeWaterArea = area > 1.0 // Large area, likely includes ocean
        if isLargeWaterArea {
            adjustedSize = Int64(Double(adjustedSize) * 0.7) // 30% smaller for water-heavy areas
        }
        
        // Urban areas tend to be larger due to complexity
        let isUrbanArea = area < 0.01 && zoomRange.maxZoom > 15 // Small area with high zoom
        if isUrbanArea {
            adjustedSize = Int64(Double(adjustedSize) * 1.3) // 30% larger for urban areas
        }
        
        // High zoom levels have more detail
        if zoomRange.maxZoom > 16 {
            adjustedSize = Int64(Double(adjustedSize) * 1.2) // 20% larger for high-detail tiles
        }
        
        // Format-specific adjustments
        switch format {
        case .png:
            // PNG with transparency can vary significantly
            adjustedSize = Int64(Double(adjustedSize) * 1.1)
        case .jpg, .jpeg:
            // JPEG compression is consistent
            break
        case .webp:
            // WebP has better compression
            adjustedSize = Int64(Double(adjustedSize) * 0.8)
        case .mvt:
            // Vector tiles vary greatly by content
            adjustedSize = Int64(Double(adjustedSize) * 1.5)
        }
        
        return adjustedSize
    }
    
    // Helper method to calculate tiles for a specific zoom
    private func calculateTilesForZoom(bounds: MapBounds, zoom: Int) -> [TileCoordinate] {
        return tileCalculator.calculateTilesForZoom(bounds: bounds, zoom: zoom)
    }
}