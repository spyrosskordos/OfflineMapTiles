import Foundation

internal final class TileDownloadManager: NSObject, @unchecked Sendable {
    private let session: URLSession
    private let maxConcurrentOperations = 8
    private let timeout: TimeInterval = 30.0
    private let retryPolicy: RetryPolicy
    private let customHeaders: [String: String]
    
    private let activeTasks: ProtectedSet<URLSessionDataTask> = ProtectedSet()
    
    init(retryPolicy: RetryPolicy = .default, customHeaders: [String: String] = [:]) {
        self.retryPolicy = retryPolicy
        self.customHeaders = customHeaders
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.httpMaximumConnectionsPerHost = maxConcurrentOperations
        config.waitsForConnectivity = true
        
        self.session = URLSession(configuration: config)
        super.init()
    }
    
    deinit {
        cancelAll()
    }
    
    func downloadTile(from url: URL) async -> Result<Data, Error> {
        return await withRetry(maxAttempts: retryPolicy.maxAttempts) {
            try await performDownload(from: url)
        }
    }
    
    private func performDownload(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("OfflineMapTiles/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // Add custom headers
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = session.dataTask(with: request)
        
        activeTasks.insert(task)
        
        defer {
            activeTasks.remove(task)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OfflineMapTilesError.networkError(URLError(.badServerResponse))
            }
            
            guard httpResponse.statusCode == 200 else {
                throw OfflineMapTilesError.networkError(URLError(.badServerResponse))
            }
            
            return data
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                throw OfflineMapTilesError.downloadCancelled
            } else {
                throw OfflineMapTilesError.networkError(error)
            }
        }
    }
    
    func cancelAll() {
        let tasksToCancel = activeTasks.removeAll()
        
        tasksToCancel.forEach { $0.cancel() }
    }
    
    private func withRetry<T>(maxAttempts: Int, operation: @Sendable () async throws -> T) async -> Result<T, Error> {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    let delay = min(retryPolicy.baseDelay * pow(retryPolicy.backoffMultiplier, Double(attempt - 1)), retryPolicy.maxDelay)
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        return .failure(lastError ?? OfflineMapTilesError.networkError(URLError(.unknown)))
    }
}

