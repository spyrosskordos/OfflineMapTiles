import Foundation

// Note: Using existing TileCoordinate from Models/TileCoordinate.swift

// Note: Using existing Logger from Logging/Logger.swift

// MARK: - Cache Statistics

/// Cache statistics for a tile server
public struct CacheStats {
    public let serverName: String
    public let totalSizeBytes: Int64
    public let tileCount: Int
    public let averageTileSize: Int64
    
    public init(serverName: String, totalSizeBytes: Int64, tileCount: Int, averageTileSize: Int64) {
        self.serverName = serverName
        self.totalSizeBytes = totalSizeBytes
        self.tileCount = tileCount
        self.averageTileSize = averageTileSize
    }
    
    public var formattedSize: String {
        return ByteCountFormatter().string(fromByteCount: totalSizeBytes)
    }
}

// Note: Using AsyncSemaphore from Utilities/AsyncSemaphore.swift