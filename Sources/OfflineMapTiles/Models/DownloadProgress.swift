import Foundation

public struct DownloadProgress: Sendable {
    public let totalTiles: Int
    public let downloadedTiles: Int
    public let failedTiles: Int
    public let percentage: Double
    public let currentTile: TileCoordinate?
    
    public init(totalTiles: Int, downloadedTiles: Int, failedTiles: Int, currentTile: TileCoordinate? = nil) {
        self.totalTiles = totalTiles
        self.downloadedTiles = downloadedTiles
        self.failedTiles = failedTiles
        self.percentage = totalTiles > 0 ? Double(downloadedTiles) / Double(totalTiles) * 100.0 : 0.0
        self.currentTile = currentTile
    }
}