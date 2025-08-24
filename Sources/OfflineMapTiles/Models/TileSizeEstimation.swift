import Foundation

public struct TileSizeEstimation: Sendable {
    public let totalTiles: Int
    public let estimatedSizeBytes: Int64
    public let estimatedSizeMB: Double
    public let averageTileSize: Int64
    public let tileFormat: TileFormat
    public let zoomLevels: [Int: Int] // zoom level -> tile count
    
    public init(totalTiles: Int, estimatedSizeBytes: Int64, averageTileSize: Int64, tileFormat: TileFormat, zoomLevels: [Int: Int]) {
        self.totalTiles = totalTiles
        self.estimatedSizeBytes = estimatedSizeBytes
        self.estimatedSizeMB = Double(estimatedSizeBytes) / (1024 * 1024)
        self.averageTileSize = averageTileSize
        self.tileFormat = tileFormat
        self.zoomLevels = zoomLevels
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: estimatedSizeBytes)
    }
    
    public var isWithinRecommendedLimit: Bool {
        return estimatedSizeBytes <= 600 * 1024 * 1024 // 600MB
    }
}