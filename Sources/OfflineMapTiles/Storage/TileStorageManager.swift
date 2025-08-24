import Foundation

internal final class TileStorageManager: @unchecked Sendable {
    private let baseURL: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "TileStorageQueue", qos: .utility, attributes: .concurrent)
    private let maxCacheSize: Int64 = 1024 * 1024 * 1024 // 1GB default
    private let tileFormat: TileFormat
    
    init(storageDirectory: URL? = nil, tileFormat: TileFormat = .png) throws {
        if let customDirectory = storageDirectory {
            self.baseURL = customDirectory
        } else {
            guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw OfflineMapTilesError.fileSystemError(CocoaError(.fileWriteFileExists))
            }
            self.baseURL = documentsPath.appendingPathComponent("OfflineMapTiles")
        }
        
        self.tileFormat = tileFormat
        try createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() throws {
        do {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw OfflineMapTilesError.fileSystemError(error)
        }
    }
    
    func saveTile(coordinate: TileCoordinate, data: Data) async throws {
        let url = tileURL(for: coordinate)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) {
                do {
                    let directory = url.deletingLastPathComponent()
                    try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    
                    try data.write(to: url, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: OfflineMapTilesError.fileSystemError(error))
                }
            }
        }
        
        await checkCacheSizeAndCleanup()
    }
    
    func getTile(coordinate: TileCoordinate) async -> Data? {
        let url = tileURL(for: coordinate)
        
        return await withCheckedContinuation { continuation in
            queue.async {
                do {
                    let data = try Data(contentsOf: url)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func tileExists(coordinate: TileCoordinate) async -> Bool {
        let url = tileURL(for: coordinate)
        
        return await withCheckedContinuation { continuation in
            queue.async {
                let exists = self.fileManager.fileExists(atPath: url.path)
                continuation.resume(returning: exists)
            }
        }
    }
    
    func clearAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) {
                do {
                    if self.fileManager.fileExists(atPath: self.baseURL.path) {
                        try self.fileManager.removeItem(at: self.baseURL)
                    }
                    try self.createDirectoryIfNeeded()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: OfflineMapTilesError.fileSystemError(error))
                }
            }
        }
    }
    
    func getCacheSize() async -> Int64 {
        return await withCheckedContinuation { continuation in
            queue.async {
                let size = self.calculateDirectorySize(at: self.baseURL)
                continuation.resume(returning: size)
            }
        }
    }
    
    private func checkCacheSizeAndCleanup() async {
        let currentSize = await getCacheSize()
        
        if currentSize > maxCacheSize {
            await cleanupOldFiles()
        }
    }
    
    private func cleanupOldFiles() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                do {
                    let urls = try self.getAllTileURLs()
                    let sortedURLs = urls.sorted { url1, url2 in
                        let date1 = (try? url1.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                        let date2 = (try? url2.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? Date.distantPast
                        return date1 < date2
                    }
                    
                    let targetSize = self.maxCacheSize * 3 / 4
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
            if resourceValues.isRegularFile == true && fileURL.pathExtension == "png" {
                urls.append(fileURL)
            }
        }
        
        return urls
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
    
    private func tileURL(for coordinate: TileCoordinate) -> URL {
        return baseURL
            .appendingPathComponent("\(coordinate.zoom)")
            .appendingPathComponent("\(coordinate.x)")
            .appendingPathComponent("\(coordinate.y).\(tileFormat.rawValue)")
    }
}