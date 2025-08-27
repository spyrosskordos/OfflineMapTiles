import Foundation

/// Comprehensive error types for tile downloading
public enum TileDownloadError: Error, LocalizedError, Sendable {
    // Network-related errors
    case networkUnavailable
    case requestTimeout
    case invalidURL(String)
    case httpError(statusCode: Int, url: String)
    case connectionFailed(underlying: Error)
    
    // Authentication errors
    case unauthorized
    case forbidden
    case apiKeyInvalid
    case quotaExceeded
    
    // Tile-specific errors
    case tileNotFound(coordinate: TileCoordinate)
    case tileOutOfBounds(coordinate: TileCoordinate, bounds: MapBounds?)
    case unsupportedZoomLevel(zoom: Int, supportedRange: ClosedRange<Int>)
    case unsupportedTileFormat(format: TileFormat)
    
    // Data errors
    case invalidTileData(coordinate: TileCoordinate)
    case corruptedData
    case dataTooLarge(size: Int64, limit: Int64)
    
    // System errors
    case operationCancelled
    case memoryWarning
    case diskSpaceInsufficient(required: Int64, available: Int64)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .requestTimeout:
            return "Request timed out"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let statusCode, let url):
            return "HTTP error \(statusCode) for URL: \(url)"
        case .connectionFailed(let underlying):
            return "Connection failed: \(underlying.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access - check API credentials"
        case .forbidden:
            return "Access forbidden"
        case .apiKeyInvalid:
            return "Invalid API key"
        case .quotaExceeded:
            return "API quota exceeded"
        case .tileNotFound(let coordinate):
            return "Tile not found at zoom \(coordinate.zoom), x: \(coordinate.x), y: \(coordinate.y)"
        case .tileOutOfBounds(let coordinate, let bounds):
            if let bounds = bounds {
                return "Tile (\(coordinate.x), \(coordinate.y)) at zoom \(coordinate.zoom) is outside bounds: NE(\(bounds.northEast.latitude), \(bounds.northEast.longitude)) SW(\(bounds.southWest.latitude), \(bounds.southWest.longitude))"
            } else {
                return "Tile (\(coordinate.x), \(coordinate.y)) at zoom \(coordinate.zoom) is outside server bounds"
            }
        case .unsupportedZoomLevel(let zoom, let supportedRange):
            return "Zoom level \(zoom) is not supported. Supported range: \(supportedRange.lowerBound)-\(supportedRange.upperBound)"
        case .unsupportedTileFormat(let format):
            return "Tile format '\(format.rawValue)' is not supported"
        case .invalidTileData(let coordinate):
            return "Invalid tile data for coordinate (\(coordinate.x), \(coordinate.y)) at zoom \(coordinate.zoom)"
        case .corruptedData:
            return "Tile data is corrupted"
        case .dataTooLarge(let size, let limit):
            return "Tile data size (\(ByteCountFormatter().string(fromByteCount: size))) exceeds limit (\(ByteCountFormatter().string(fromByteCount: limit)))"
        case .operationCancelled:
            return "Operation was cancelled"
        case .memoryWarning:
            return "Operation cancelled due to memory warning"
        case .diskSpaceInsufficient(let required, let available):
            return "Insufficient disk space. Required: \(ByteCountFormatter().string(fromByteCount: required)), Available: \(ByteCountFormatter().string(fromByteCount: available))"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .networkUnavailable, .requestTimeout, .connectionFailed:
            return "Network connectivity issue"
        case .unauthorized, .forbidden, .apiKeyInvalid:
            return "Authentication failure"
        case .quotaExceeded:
            return "Service limit exceeded"
        case .tileNotFound, .tileOutOfBounds:
            return "Tile availability issue"
        case .unsupportedZoomLevel, .unsupportedTileFormat:
            return "Configuration mismatch"
        case .invalidTileData, .corruptedData:
            return "Data integrity issue"
        case .operationCancelled:
            return "User cancellation"
        case .memoryWarning, .diskSpaceInsufficient:
            return "System resource constraint"
        default:
            return "Unknown issue"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable, .requestTimeout, .connectionFailed:
            return "Check your internet connection and try again"
        case .unauthorized, .forbidden, .apiKeyInvalid:
            return "Verify your API credentials and permissions"
        case .quotaExceeded:
            return "Wait for quota reset or upgrade your service plan"
        case .unsupportedZoomLevel:
            return "Use a supported zoom level range"
        case .diskSpaceInsufficient:
            return "Free up disk space or choose a smaller download area"
        case .memoryWarning:
            return "Reduce the download area size or restart the app"
        default:
            return "Contact support if the issue persists"
        }
    }
}

/// Storage-specific errors
public enum TileStorageError: Error, LocalizedError, Sendable {
    case fileSystemError(underlying: Error)
    case permissionDenied(path: String)
    case diskFull
    case corruptedIndex
    case invalidCachePath(path: String)
    case cacheVersionMismatch(expected: String, found: String)
    
    public var errorDescription: String? {
        switch self {
        case .fileSystemError(let underlying):
            return "File system error: \(underlying.localizedDescription)"
        case .permissionDenied(let path):
            return "Permission denied for path: \(path)"
        case .diskFull:
            return "Insufficient disk space"
        case .corruptedIndex:
            return "Cache index is corrupted"
        case .invalidCachePath(let path):
            return "Invalid cache path: \(path)"
        case .cacheVersionMismatch(let expected, let found):
            return "Cache version mismatch. Expected: \(expected), Found: \(found)"
        }
    }
}