import Foundation

/// Protocol defining tile downloading capabilities
public protocol TileDownloaderProtocol: Sendable {
    /// Downloads a single tile from the given URL
    /// - Parameter url: The URL to download the tile from
    /// - Returns: Result containing the tile data or an error
    func downloadTile(from url: URL) async -> Result<Data, Error>
    
    /// Cancels all active downloads
    func cancelAll()
}

/// Protocol for retry behavior configuration
public protocol RetryPolicyProtocol: Sendable {
    var maxAttempts: Int { get }
    var baseDelay: TimeInterval { get }
    var maxDelay: TimeInterval { get }
    var backoffMultiplier: Double { get }
}

/// Protocol for HTTP request configuration
public protocol HTTPConfigurationProtocol: Sendable {
    var timeout: TimeInterval { get }
    var maxConcurrentOperations: Int { get }
    var customHeaders: [String: String] { get }
    var userAgent: String { get }
}