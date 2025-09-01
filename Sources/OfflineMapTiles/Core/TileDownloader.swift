import Foundation

/// Simple, focused tile downloader
/// Follows Single Responsibility Principle: only handles HTTP tile downloads
public final class TileDownloader: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let logger: Logger
    
    // MARK: - Initialization
    
    /// Create a tile downloader with HTTP configuration
    /// - Parameters:
    ///   - httpConfig: HTTP configuration settings
    ///   - logger: Logger instance
    public init(httpConfig: HTTPConfiguration, logger: Logger = Logger.shared) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = httpConfig.timeout
        config.httpMaximumConnectionsPerHost = httpConfig.maxConcurrentOperations
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil // Disable built-in caching, we handle our own
        
        self.session = URLSession(configuration: config)
        self.logger = logger
    }
    
    // MARK: - Core Download Operation
    
    /// Download a tile from the specified URL
    /// - Parameter url: URL to download the tile from
    /// - Returns: Result with tile data or error
    public func downloadTile(from url: URL) async -> Result<Data, OfflineMapTiles.TileDownloadError> {
        logger.debug("Downloading tile from: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidURL(url.absoluteString))
            }
            
            // Check status code
            guard 200...299 ~= httpResponse.statusCode else {
                return .failure(.httpError(statusCode: httpResponse.statusCode, url: url.absoluteString))
            }
            
            // Validate data
            guard !data.isEmpty else {
                return .failure(.corruptedData)
            }
            
            // Basic validation that this looks like image data
            if !isValidImageData(data) {
                logger.warning("Downloaded data doesn't appear to be valid image data from \(url)")
                // Still return it in case our validation is wrong
            }
            
            logger.debug("Successfully downloaded tile: \(data.count) bytes")
            return .success(data)
            
        } catch {
            logger.warning("Failed to download tile from \(url): \(error.localizedDescription)")
            return .failure(.connectionFailed(underlying: error))
        }
    }
    
    // MARK: - Private Methods
    
    private func isValidImageData(_ data: Data) -> Bool {
        guard data.count > 8 else { return false }
        
        // Check for common image file signatures
        let bytes = data.prefix(8)
        
        // PNG signature
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return true
        }
        
        // JPEG signature
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return true
        }
        
        // WebP signature
        if bytes.count >= 8 &&
           bytes[0...3] == Data([0x52, 0x49, 0x46, 0x46]) && // "RIFF"
           bytes[8...] == Data([0x57, 0x45, 0x42, 0x50]) {   // "WEBP"
            return true
        }
        
        return false
    }
}

// MARK: - HTTP Configuration

/// HTTP configuration for tile downloads
public protocol HTTPConfiguration {
    var timeout: TimeInterval { get }
    var maxConcurrentOperations: Int { get }
}

/// Basic HTTP configuration adapter
public struct BasicHTTPConfiguration: HTTPConfiguration, Sendable {
    public let timeout: TimeInterval = 30.0
    public let maxConcurrentOperations: Int = 8
    
    public init() {}
}