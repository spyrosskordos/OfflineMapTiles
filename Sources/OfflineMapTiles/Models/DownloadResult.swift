import Foundation

public struct DownloadResult: Sendable {
    public let totalTiles: Int
    public let successfulTiles: Int
    public let failedTiles: Int
    public let downloadTime: TimeInterval
    public let averageDownloadSpeed: Double
    
    public var successRate: Double {
        return totalTiles > 0 ? Double(successfulTiles) / Double(totalTiles) : 0.0
    }
    
    public init(totalTiles: Int, successfulTiles: Int, failedTiles: Int, downloadTime: TimeInterval, averageDownloadSpeed: Double) {
        self.totalTiles = totalTiles
        self.successfulTiles = successfulTiles
        self.failedTiles = failedTiles
        self.downloadTime = downloadTime
        self.averageDownloadSpeed = averageDownloadSpeed
    }
}