import Foundation

/// Protocol for observing download progress
public protocol ProgressObserver: AnyObject, Sendable {
    /// Called when download progress is updated
    /// - Parameter progress: The current progress information
    func didUpdateProgress(_ progress: DownloadProgress)
    
    /// Called when a download completes successfully
    /// - Parameter result: The download result
    func didCompleteDownload(with result: DownloadResult)
    
    /// Called when a download fails
    /// - Parameter error: The error that caused the failure
    func didFailDownload(with error: Error)
}

/// Protocol for progress reporting
public protocol ProgressReporter: Sendable {
    /// Adds a progress observer
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: ProgressObserver)
    
    /// Removes a progress observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: ProgressObserver)
    
    /// Notifies all observers of progress update
    /// - Parameter progress: The progress information
    func notifyProgressUpdate(_ progress: DownloadProgress)
    
    /// Notifies all observers of completion
    /// - Parameter result: The download result
    func notifyCompletion(with result: DownloadResult)
    
    /// Notifies all observers of failure
    /// - Parameter error: The error that occurred
    func notifyFailure(with error: Error)
}

/// Protocol for multi-config progress reporting
public protocol MultiConfigProgressObserver: AnyObject, Sendable {
    /// Called when progress is updated for a specific configuration
    /// - Parameters:
    ///   - configName: Name of the configuration
    ///   - progress: The current progress information
    func didUpdateProgress(for configName: String, progress: DownloadProgress)
    
    /// Called when a configuration completes downloading
    /// - Parameters:
    ///   - configName: Name of the configuration
    ///   - result: The download result
    func didCompleteDownload(for configName: String, with result: DownloadResult)
    
    /// Called when all configurations complete
    /// - Parameter results: Dictionary of results by configuration name
    func didCompleteAllDownloads(with results: [String: DownloadResult])
    
    /// Called when download fails
    /// - Parameter error: The error that caused the failure
    func didFailDownload(with error: Error)
}