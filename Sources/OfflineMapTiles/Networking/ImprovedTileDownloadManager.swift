import Foundation

/// Improved tile download manager with better error handling and monitoring
public final class ImprovedTileDownloadManager: TileDownloaderProtocol {
    private let session: URLSession
    private let httpConfig: HTTPConfigurationProtocol
    private let retryPolicy: RetryPolicyProtocol
    private let activeTasks: ProtectedSet<URLSessionDataTask> = ProtectedSet()
    private let logger = Logger.shared
    
    public init(
        httpConfig: HTTPConfigurationProtocol,
        retryPolicy: RetryPolicyProtocol
    ) {
        self.httpConfig = httpConfig
        self.retryPolicy = retryPolicy
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = httpConfig.timeout
        config.timeoutIntervalForResource = httpConfig.timeout * 2
        config.httpMaximumConnectionsPerHost = httpConfig.maxConcurrentOperations
        config.waitsForConnectivity = true
        config.httpShouldUsePipelining = true
        
        // Configure HTTP/2 and connection pooling
        if #available(iOS 13.0, macOS 10.15, *) {
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
        }
        
        self.session = URLSession(configuration: config)
    }
    
    deinit {
        cancelAll()
        session.invalidateAndCancel()
    }
    
    public func downloadTile(from url: URL) async -> Result<Data, Error> {
        logger.logNetworkRequest(url: url.absoluteString)
        
        return await withRetry(maxAttempts: retryPolicy.maxAttempts) {
            try await performDownload(from: url)
        }
    }
    
    public func cancelAll() {
        let tasksToCancel = activeTasks.removeAll()
        logger.debug("Cancelling \(tasksToCancel.count) active download tasks")
        
        tasksToCancel.forEach { $0.cancel() }
    }
    
    // MARK: - Private Methods
    
    private func performDownload(from url: URL) async throws -> Data {
        let request = buildRequest(for: url)
        let task = session.dataTask(with: request)
        
        activeTasks.insert(task)
        
        defer {
            activeTasks.remove(task)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TileDownloadError.invalidURL(url.absoluteString)
            }
            
            logger.logNetworkResponse(
                url: url.absoluteString,
                statusCode: httpResponse.statusCode,
                size: Int64(data.count)
            )
            
            try validateResponse(httpResponse, url: url, data: data)
            
            return data
        } catch {
            let mappedError = mapError(error, url: url)
            logger.logDownloadError(configName: "Network", error: mappedError)
            throw mappedError
        }
    }
    
    private func buildRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(httpConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        // Add custom headers
        for (key, value) in httpConfig.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
    
    private func validateResponse(_ response: HTTPURLResponse, url: URL, data: Data) throws {
        switch response.statusCode {
        case 200:
            // Success - validate data if needed
            if data.isEmpty {
                throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
            }
            
            // Check content type if available
            if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
               !isValidTileContentType(contentType) {
                throw TileDownloadError.invalidTileData(coordinate: TileCoordinate(x: 0, y: 0, zoom: 0))
            }
            
        case 204:
            // No content - valid but empty tile
            break
            
        case 400:
            throw TileDownloadError.invalidURL(url.absoluteString)
            
        case 401:
            throw TileDownloadError.unauthorized
            
        case 403:
            throw TileDownloadError.forbidden
            
        case 404:
            throw TileDownloadError.tileNotFound(coordinate: extractCoordinate(from: url))
            
        case 429:
            throw TileDownloadError.quotaExceeded
            
        case 500...599:
            throw TileDownloadError.httpError(statusCode: response.statusCode, url: url.absoluteString)
            
        default:
            throw TileDownloadError.httpError(statusCode: response.statusCode, url: url.absoluteString)
        }
    }
    
    private func isValidTileContentType(_ contentType: String) -> Bool {
        let validTypes = [
            "image/png",
            "image/jpeg",
            "image/jpg",
            "image/webp",
            "application/x-protobuf", // For vector tiles
            "application/vnd.mapbox-vector-tile"
        ]
        
        return validTypes.contains { contentType.lowercased().contains($0) }
    }
    
    private func extractCoordinate(from url: URL) -> TileCoordinate {
        let pathComponents = url.pathComponents
        
        // Try to extract z/x/y from URL path
        for i in 0..<(pathComponents.count - 2) {
            if let zoom = Int(pathComponents[i]),
               let x = Int(pathComponents[i + 1]) {
                let yComponent = pathComponents[i + 2]
                if let y = Int(yComponent.components(separatedBy: ".").first ?? "") {
                    return TileCoordinate(x: x, y: y, zoom: zoom)
                }
            }
        }
        
        return TileCoordinate(x: 0, y: 0, zoom: 0)
    }
    
    private func mapError(_ error: Error, url: URL) -> Error {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return TileDownloadError.requestTimeout
            case .notConnectedToInternet, .networkConnectionLost:
                return TileDownloadError.networkUnavailable
            case .cancelled:
                return TileDownloadError.operationCancelled
            case .badURL:
                return TileDownloadError.invalidURL(url.absoluteString)
            default:
                return TileDownloadError.connectionFailed(underlying: error)
            }
        }
        
        return error
    }
    
    private func withRetry<T>(
        maxAttempts: Int,
        operation: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                
                if attempt > 1 {
                    logger.debug("Retry attempt \(attempt) succeeded")
                }
                
                return .success(result)
            } catch {
                lastError = error
                
                // Don't retry certain errors
                if !shouldRetry(error: error) {
                    logger.debug("Error not retryable: \(error)")
                    break
                }
                
                if attempt < maxAttempts {
                    let delay = calculateDelay(attempt: attempt)
                    logger.debug("Retry attempt \(attempt) failed, retrying in \(delay)s: \(error)")
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    logger.debug("All retry attempts exhausted")
                }
            }
        }
        
        return .failure(lastError ?? TileDownloadError.connectionFailed(underlying: URLError(.unknown)))
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let tileError = error as? TileDownloadError {
            switch tileError {
            case .networkUnavailable, .requestTimeout, .connectionFailed, .httpError:
                return true
            case .unauthorized, .forbidden, .apiKeyInvalid, .tileNotFound, .operationCancelled:
                return false
            default:
                return true
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled, .badURL:
                return false
            default:
                return true
            }
        }
        
        return true
    }
    
    private func calculateDelay(attempt: Int) -> TimeInterval {
        let delay = retryPolicy.baseDelay * pow(retryPolicy.backoffMultiplier, Double(attempt - 1))
        return min(delay, retryPolicy.maxDelay)
    }
}

// MARK: - Network Monitoring

public final class NetworkMonitor: @unchecked Sendable {
    public static let shared = NetworkMonitor()
    
    private var isConnected = true
    private let logger = Logger.shared
    
    private init() {
        startMonitoring()
    }
    
    public var networkAvailable: Bool {
        return isConnected
    }
    
    private func startMonitoring() {
        // Basic network monitoring - in a real implementation,
        // you might want to use Network framework for more detailed monitoring
        logger.debug("Network monitoring started")
    }
    
    public func checkConnectivity() async -> Bool {
        // Simple connectivity check
        guard let url = URL(string: "https://www.google.com") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}