import Foundation

public enum OfflineMapTilesError: Error, LocalizedError {
    case invalidBounds
    case networkError(Error)
    case fileSystemError(Error)
    case invalidTileServer
    case downloadCancelled
    case storageQuotaExceeded
    case invalidZoomLevel
    case unsupportedTileFormat
    case downloadSizeExceedsLimit(SizeEstimationError)
    
    public var errorDescription: String? {
        switch self {
        case .invalidBounds:
            return "Invalid map bounds provided"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .invalidTileServer:
            return "Invalid tile server URL"
        case .downloadCancelled:
            return "Download was cancelled"
        case .storageQuotaExceeded:
            return "Storage quota exceeded"
        case .invalidZoomLevel:
            return "Zoom level is outside the supported range for this tile server"
        case .unsupportedTileFormat:
            return "Unsupported tile format"
        case .downloadSizeExceedsLimit(let sizeError):
            return sizeError.localizedDescription
        }
    }
}