import Foundation

public protocol OfflineMapTilesDelegate: AnyObject {
    func offlineMapTiles(_ manager: OfflineMapTiles, didUpdateProgress progress: DownloadProgress)
    func offlineMapTiles(_ manager: OfflineMapTiles, didFailWithError error: OfflineMapTilesError)
    func offlineMapTilesDidFinish(_ manager: OfflineMapTiles, with result: DownloadResult)
}