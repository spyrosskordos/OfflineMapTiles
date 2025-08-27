import Foundation
import os.log

/// Logging levels
public enum LogLevel: Int, CaseIterable, Comparable, Sendable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
    
    public var name: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
}

/// Protocol for log destinations
public protocol LogDestination: Sendable {
    func write(message: String, level: LogLevel, category: String, timestamp: Date)
}

/// Protocol for log formatting
public protocol LogFormatter: Sendable {
    func format(message: String, level: LogLevel, category: String, timestamp: Date) -> String
}

/// Main logger class
public final class Logger: @unchecked Sendable {
    public static let shared = Logger()
    
    private var destinations: [LogDestination] = []
    private var formatter: LogFormatter
    private var minimumLogLevel: LogLevel = .info
    private let queue = DispatchQueue(label: "logger.queue", qos: .utility)
    
    public init(formatter: LogFormatter = DefaultLogFormatter()) {
        self.formatter = formatter
        
        #if DEBUG
        self.minimumLogLevel = .debug
        addDestination(ConsoleLogDestination())
        #else
        self.minimumLogLevel = .info
        #endif
    }
    
    public func setMinimumLogLevel(_ level: LogLevel) {
        queue.async { [weak self] in
            self?.minimumLogLevel = level
        }
    }
    
    public func addDestination(_ destination: LogDestination) {
        queue.async { [weak self] in
            self?.destinations.append(destination)
        }
    }
    
    public func removeAllDestinations() {
        queue.async { [weak self] in
            self?.destinations.removeAll()
        }
    }
    
    public func setFormatter(_ formatter: LogFormatter) {
        queue.async { [weak self] in
            self?.formatter = formatter
        }
    }
    
    // MARK: - Logging Methods
    
    public func verbose(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .verbose, category: category)
    }
    
    public func debug(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .debug, category: category)
    }
    
    public func info(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .info, category: category)
    }
    
    public func warning(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .warning, category: category)
    }
    
    public func error(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .error, category: category)
    }
    
    public func critical(_ message: String, category: String = "OfflineMapTiles") {
        log(message, level: .critical, category: category)
    }
    
    private func log(_ message: String, level: LogLevel, category: String) {
        queue.async { [weak self] in
            guard let self = self,
                  level >= self.minimumLogLevel else { return }
            
            let timestamp = Date()
            let formattedMessage = self.formatter.format(
                message: message,
                level: level,
                category: category,
                timestamp: timestamp
            )
            
            for destination in self.destinations {
                destination.write(
                    message: formattedMessage,
                    level: level,
                    category: category,
                    timestamp: timestamp
                )
            }
        }
    }
}

// MARK: - Default Formatter

public struct DefaultLogFormatter: LogFormatter {
    private let dateFormatter: DateFormatter
    
    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    public func format(message: String, level: LogLevel, category: String, timestamp: Date) -> String {
        let timestampString = dateFormatter.string(from: timestamp)
        return "\(timestampString) [\(level.name)] [\(category)] \(message)"
    }
}

public struct CompactLogFormatter: LogFormatter {
    public init() {}
    
    public func format(message: String, level: LogLevel, category: String, timestamp: Date) -> String {
        return "\(level.emoji) [\(category)] \(message)"
    }
}

// MARK: - Log Destinations

public struct ConsoleLogDestination: LogDestination {
    public init() {}
    
    public func write(message: String, level: LogLevel, category: String, timestamp: Date) {
        if level >= .error {
            // Use stderr for errors and critical messages
            fputs("\(message)\n", stderr)
        } else {
            print(message)
        }
    }
}

public struct FileLogDestination: LogDestination, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager = FileManager.default
    
    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        
        // Create directory if it doesn't exist
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        // Create file if it doesn't exist
        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
    }
    
    public func write(message: String, level: LogLevel, category: String, timestamp: Date) {
        guard let data = "\(message)\n".data(using: .utf8) else { return }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } catch {
            // Fallback to console if file writing fails
            print("Failed to write to log file: \(error)")
            print(message)
        }
    }
}

@available(iOS 14.0, macOS 11.0, *)
public struct OSLogDestination: LogDestination {
    private let osLog: OSLog
    
    public init(subsystem: String = "com.offlinemaptiles", category: String = "default") {
        self.osLog = OSLog(subsystem: subsystem, category: category)
    }
    
    public func write(message: String, level: LogLevel, category: String, timestamp: Date) {
        let osLogType: OSLogType
        switch level {
        case .verbose, .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        case .critical:
            osLogType = .fault
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, message)
    }
}

// MARK: - Convenience Extensions

extension Logger {
    public func logDownloadStart(configName: String, tileCount: Int, bounds: MapBounds, zoomRange: ZoomRange) {
        info("Starting download for '\(configName)': \(tileCount) tiles, zoom \(zoomRange.minZoom)-\(zoomRange.maxZoom)")
        debug("Bounds: NE(\(bounds.northEast.latitude), \(bounds.northEast.longitude)) SW(\(bounds.southWest.latitude), \(bounds.southWest.longitude))")
    }
    
    public func logDownloadProgress(configName: String, progress: DownloadProgress) {
        debug("Progress for '\(configName)': \(progress.downloadedTiles)/\(progress.totalTiles) (\(String(format: "%.1f", progress.percentage))%)")
    }
    
    public func logDownloadComplete(configName: String, result: DownloadResult) {
        info("Download complete for '\(configName)': \(result.successfulTiles)/\(result.totalTiles) tiles in \(String(format: "%.2f", result.downloadTime))s")
    }
    
    public func logDownloadError(configName: String, error: Error) {
        self.error("Download failed for '\(configName)': \(error.localizedDescription)")
        if let detailedError = error as? TileDownloadError {
            if let suggestion = detailedError.recoverySuggestion {
                info("Recovery suggestion: \(suggestion)")
            }
        }
    }
    
    public func logCacheOperation(operation: String, details: String) {
        debug("Cache \(operation): \(details)")
    }
    
    public func logNetworkRequest(url: String, method: String = "GET") {
        verbose("Network request: \(method) \(url)")
    }
    
    public func logNetworkResponse(url: String, statusCode: Int, size: Int64) {
        verbose("Network response: \(statusCode) for \(url) (\(ByteCountFormatter().string(fromByteCount: size)))")
    }
}