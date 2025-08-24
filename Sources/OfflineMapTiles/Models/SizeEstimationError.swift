import Foundation

public enum SizeEstimationError: Error, LocalizedError {
    case downloadSizeExceedsLimit(estimatedSize: Int64, limit: Int64)
    case invalidBoundsForEstimation
    case unsupportedTileFormatForEstimation
    
    public var errorDescription: String? {
        switch self {
        case .downloadSizeExceedsLimit(let estimatedSize, let limit):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let sizeStr = formatter.string(fromByteCount: estimatedSize)
            let limitStr = formatter.string(fromByteCount: limit)
            return "Estimated download size (\(sizeStr)) exceeds the limit (\(limitStr))"
        case .invalidBoundsForEstimation:
            return "Invalid bounds provided for size estimation"
        case .unsupportedTileFormatForEstimation:
            return "Cannot estimate size for this tile format"
        }
    }
}