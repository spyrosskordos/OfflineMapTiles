import Foundation
import CryptoKit

/// Simple utility for generating tile keys for storage and retrieval
public enum TileKey {
    /// Generate key with URL template for uniqueness
    /// - Parameters:
    ///   - z: Zoom level
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - urlTemplate: URL template for uniqueness
    /// - Returns: Unique key string
    public static func generateKey(z: Int, x: Int, y: Int, urlTemplate: String) -> String {
        let urlHash = createURLHash(from: urlTemplate)
        return "\(urlHash)_\(z)_\(x)_\(y)"
    }
    
    /// Generate simple key without URL template
    /// - Parameters:
    ///   - z: Zoom level
    ///   - x: X coordinate
    ///   - y: Y coordinate
    /// - Returns: Simple key string
    public static func generateKey(z: Int, x: Int, y: Int) -> String {
        "\(z)_\(x)_\(y)"
    }
    
    /// Create hash from URL template
    /// - Parameter urlTemplate: URL template to hash
    /// - Returns: Short hash string
    public static func createURLHash(from urlTemplate: String) -> String {
        if #available(iOS 13.0, *) {
            let data = Data(urlTemplate.utf8)
            let hash = SHA256.hash(data: data)
            return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(6)) // Shorter hash
        } else {
            return String(abs(urlTemplate.hashValue) % 1000000) // Shorter fallback
        }
    }
}

