import Foundation

/// File system implementation of tile storage
public final class FileSystemTileStorage: TileStorageProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue
    private let cachePolicy: CacheManagementProtocol
    private let tileFormat: TileFormat
    
    public init(
        baseURL: URL,
        cachePolicy: CacheManagementProtocol,
        tileFormat: TileFormat,
        fileManager: FileManager = .default
    ) throws {
        self.baseURL = baseURL
        self.cachePolicy = cachePolicy
        self.tileFormat = tileFormat
        self.fileManager = fileManager
        self.queue = DispatchQueue(
            label: "com.offlinemaptiles.storage",
            qos: .utility,
            attributes: .concurrent
        )
        
        try createDirectoryIfNeeded()
    }
    
    public func saveTile(coordinate: TileCoordinate, data: Data, configName: String? = nil) async throws {
        let url = tileURL(for: coordinate, configName: configName)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: CocoaError(.fileWriteUnknown)))
                    return
                }
                
                do {
                    let directory = url.deletingLastPathComponent()
                    try self.fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    // Validate data size
                    if data.count > 50 * 1024 * 1024 { // 50MB limit per tile
                        throw TileDownloadError.dataTooLarge(size: Int64(data.count), limit: 50 * 1024 * 1024)
                    }
                    
                    try data.write(to: url, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: error))
                }
            }
        }
        
        await performCleanupIfNeeded()
    }
    
    public func getTile(coordinate: TileCoordinate, configName: String? = nil) async -> Data? {
        let url = tileURL(for: coordinate, configName: configName)
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    
                    // Update access time for LRU cache management
                    self.updateAccessTime(for: url)
                    
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    public func tileExists(coordinate: TileCoordinate, configName: String? = nil) async -> Bool {
        let url = tileURL(for: coordinate, configName: configName)
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                
                let exists = self.fileManager.fileExists(atPath: url.path)
                continuation.resume(returning: exists)
            }
        }
    }
    
    public func clearAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: CocoaError(.fileWriteUnknown)))
                    return
                }
                
                do {
                    if self.fileManager.fileExists(atPath: self.baseURL.path) {
                        try self.fileManager.removeItem(at: self.baseURL)
                    }
                    try self.createDirectoryIfNeeded()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: error))
                }
            }
        }
    }
    
    public func clearCache(for configName: String) async throws {
        let configURL = baseURL.appendingPathComponent(configName)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: CocoaError(.fileWriteUnknown)))
                    return
                }
                
                do {
                    if self.fileManager.fileExists(atPath: configURL.path) {
                        try self.fileManager.removeItem(at: configURL)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: TileStorageError.fileSystemError(underlying: error))
                }
            }
        }
    }
    
    public func getCacheSize() async -> Int64 {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: 0)
                    return
                }
                
                let size = self.calculateDirectorySize(at: self.baseURL)
                continuation.resume(returning: size)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createDirectoryIfNeeded() throws {
        do {
            try fileManager.createDirectory(
                at: baseURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw TileStorageError.fileSystemError(underlying: error)
        }
    }
    
    private func tileURL(for coordinate: TileCoordinate, configName: String?) -> URL {
        var url = baseURL
        
        if let configName = configName {
            url = url.appendingPathComponent(configName)
        }
        
        return url
            .appendingPathComponent("\(coordinate.zoom)")
            .appendingPathComponent("\(coordinate.x)")
            .appendingPathComponent("\(coordinate.y).\(tileFormat.rawValue)")
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    private func performCleanupIfNeeded() async {
        let currentSize = await getCacheSize()
        
        if cachePolicy.shouldCleanup(currentSize: currentSize) {
            await cleanupOldFiles()
        }
    }
    
    private func cleanupOldFiles() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                
                do {
                    let urls = try self.getAllTileURLs()
                    let sortedURLs = urls.sorted { url1, url2 in
                        let date1 = (try? url1.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                        let date2 = (try? url2.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                        return date1 < date2
                    }
                    
                    let targetSize = self.cachePolicy.getTargetSize()
                    var currentSize = self.calculateDirectorySize(at: self.baseURL)
                    
                    for url in sortedURLs {
                        if currentSize <= targetSize {
                            break
                        }
                        
                        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            try? self.fileManager.removeItem(at: url)
                            currentSize -= Int64(fileSize)
                        }
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume()
                }
            }
        }
    }
    
    private func getAllTileURLs() throws -> [URL] {
        var urls: [URL] = []
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        
        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return urls
        }
        
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            if resourceValues.isRegularFile == true,
               TileFormat.allCases.contains(where: { $0.rawValue == fileURL.pathExtension }) {
                urls.append(fileURL)
            }
        }
        
        return urls
    }
    
    private func updateAccessTime(for url: URL) {
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
    }
}

/// Default cache management policy
public struct DefaultCacheManagementPolicy: CacheManagementProtocol {
    public let maxCacheSize: Int64
    public let cleanupThreshold: Double
    
    public init(maxCacheSize: Int64 = 1024 * 1024 * 1024, cleanupThreshold: Double = 0.9) {
        self.maxCacheSize = maxCacheSize
        self.cleanupThreshold = cleanupThreshold
    }
    
    public func shouldCleanup(currentSize: Int64) -> Bool {
        return Double(currentSize) >= Double(maxCacheSize) * cleanupThreshold
    }
    
    public func getTargetSize() -> Int64 {
        return Int64(Double(maxCacheSize) * 0.75) // Clean up to 75% of max size
    }
}