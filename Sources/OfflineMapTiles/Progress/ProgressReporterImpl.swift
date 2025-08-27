import Foundation

/// Thread-safe implementation of ProgressReporter
public final class DefaultProgressReporter: ProgressReporter, @unchecked Sendable {
    private var observers: [WeakProgressObserver] = []
    private let queue = DispatchQueue(label: "progress.reporter", attributes: .concurrent)
    
    public init() {}
    
    public func addObserver(_ observer: ProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cleanupWeakReferences()
            self?.observers.append(WeakProgressObserver(observer))
        }
    }
    
    public func removeObserver(_ observer: ProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.observers.removeAll { weakObserver in
                weakObserver.observer === observer
            }
        }
    }
    
    public func notifyProgressUpdate(_ progress: DownloadProgress) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didUpdateProgress(progress)
                }
            }
        }
    }
    
    public func notifyCompletion(with result: DownloadResult) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didCompleteDownload(with: result)
                }
            }
        }
    }
    
    public func notifyFailure(with error: Error) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didFailDownload(with: error)
                }
            }
        }
    }
    
    private func cleanupWeakReferences() {
        observers.removeAll { $0.observer == nil }
    }
}

/// Multi-config progress reporter
public final class DefaultMultiConfigProgressReporter: @unchecked Sendable {
    private var observers: [WeakMultiConfigProgressObserver] = []
    private let queue = DispatchQueue(label: "multiconfig.progress.reporter", attributes: .concurrent)
    
    public init() {}
    
    public func addObserver(_ observer: MultiConfigProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cleanupWeakReferences()
            self?.observers.append(WeakMultiConfigProgressObserver(observer))
        }
    }
    
    public func removeObserver(_ observer: MultiConfigProgressObserver) {
        queue.async(flags: .barrier) { [weak self] in
            self?.observers.removeAll { weakObserver in
                weakObserver.observer === observer
            }
        }
    }
    
    public func notifyProgressUpdate(for configName: String, progress: DownloadProgress) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didUpdateProgress(for: configName, progress: progress)
                }
            }
        }
    }
    
    public func notifyCompletion(for configName: String, with result: DownloadResult) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didCompleteDownload(for: configName, with: result)
                }
            }
        }
    }
    
    public func notifyAllCompleted(with results: [String: DownloadResult]) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didCompleteAllDownloads(with: results)
                }
            }
        }
    }
    
    public func notifyFailure(with error: Error) {
        queue.async { [weak self] in
            let validObservers = self?.observers.compactMap { $0.observer } ?? []
            
            for observer in validObservers {
                DispatchQueue.main.async {
                    observer.didFailDownload(with: error)
                }
            }
        }
    }
    
    private func cleanupWeakReferences() {
        observers.removeAll { $0.observer == nil }
    }
}

// MARK: - Weak Reference Wrappers

private struct WeakProgressObserver {
    weak var observer: ProgressObserver?
    
    init(_ observer: ProgressObserver) {
        self.observer = observer
    }
}

private struct WeakMultiConfigProgressObserver {
    weak var observer: MultiConfigProgressObserver?
    
    init(_ observer: MultiConfigProgressObserver) {
        self.observer = observer
    }
}

// MARK: - Convenience Observers

/// Simple progress observer that logs to console
public final class ConsoleProgressObserver: ProgressObserver {
    private let prefix: String
    
    public init(prefix: String = "Download") {
        self.prefix = prefix
    }
    
    public func didUpdateProgress(_ progress: DownloadProgress) {
        print("\(prefix): \(String(format: "%.1f", progress.percentage))% complete (\(progress.downloadedTiles)/\(progress.totalTiles) tiles)")
    }
    
    public func didCompleteDownload(with result: DownloadResult) {
        print("\(prefix): Completed! \(result.successfulTiles) tiles downloaded in \(String(format: "%.2f", result.downloadTime))s")
    }
    
    public func didFailDownload(with error: Error) {
        print("\(prefix): Failed with error: \(error.localizedDescription)")
    }
}

/// Progress observer that provides detailed statistics
public final class DetailedProgressObserver: ProgressObserver, @unchecked Sendable {
    private let startTime = Date()
    private var lastUpdateTime = Date()
    
    public init() {}
    
    public func didUpdateProgress(_ progress: DownloadProgress) {
        let currentTime = Date()
        let totalElapsed = currentTime.timeIntervalSince(startTime)
        let _ = currentTime.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = currentTime
        
        let tilesPerSecond = progress.downloadedTiles > 0 ? Double(progress.downloadedTiles) / totalElapsed : 0
        let estimatedTimeRemaining = tilesPerSecond > 0 ? Double(progress.totalTiles - progress.downloadedTiles) / tilesPerSecond : 0
        
        print("""
            Progress Update:
            - Progress: \(String(format: "%.1f", progress.percentage))%
            - Downloaded: \(progress.downloadedTiles)/\(progress.totalTiles) tiles
            - Failed: \(progress.failedTiles) tiles
            - Speed: \(String(format: "%.1f", tilesPerSecond)) tiles/sec
            - Elapsed: \(String(format: "%.1f", totalElapsed))s
            - ETA: \(String(format: "%.1f", estimatedTimeRemaining))s
            """)
    }
    
    public func didCompleteDownload(with result: DownloadResult) {
        print("""
            Download Complete:
            - Success Rate: \(String(format: "%.1f", result.successRate * 100))%
            - Total Time: \(String(format: "%.2f", result.downloadTime))s
            - Average Speed: \(String(format: "%.2f", result.averageDownloadSpeed)) tiles/sec
            """)
    }
    
    public func didFailDownload(with error: Error) {
        print("Download failed: \(error.localizedDescription)")
        if let detailedError = error as? TileDownloadError {
            if let suggestion = detailedError.recoverySuggestion {
                print("Suggestion: \(suggestion)")
            }
        }
    }
}