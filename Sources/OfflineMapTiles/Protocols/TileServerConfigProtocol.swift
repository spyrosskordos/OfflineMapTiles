import Foundation
import CoreLocation

/// Protocol defining tile server configuration
public protocol TileServerConfigProtocol: Sendable {
    var name: String { get }
    var baseURL: String { get }
    var format: TileFormat { get }
    var minZoom: Int { get }
    var maxZoom: Int { get }
    var attribution: String? { get }
    var bounds: MapBounds? { get }
    var retryPolicy: RetryPolicyProtocol { get }
    var httpConfiguration: HTTPConfigurationProtocol { get }
    
    /// Generates the URL for a specific tile coordinate
    /// - Parameter coordinate: The tile coordinate
    /// - Returns: The complete URL for the tile
    func tileURL(for coordinate: TileCoordinate) -> String
    
    /// Checks if a coordinate is within the server's bounds
    /// - Parameter coordinate: The tile coordinate to check
    /// - Returns: True if the coordinate is within bounds
    func isCoordinateInBounds(_ coordinate: TileCoordinate) -> Bool
    
    /// Validates if a zoom level is supported
    /// - Parameter zoom: The zoom level to validate
    /// - Returns: True if the zoom level is supported
    func isZoomLevelSupported(_ zoom: Int) -> Bool
}

/// Protocol for URL template processing
public protocol URLTemplateProcessorProtocol: Sendable {
    /// Processes a URL template with tile coordinate
    /// - Parameters:
    ///   - template: The URL template
    ///   - coordinate: The tile coordinate
    ///   - config: The server configuration
    /// - Returns: The processed URL
    func processTemplate(_ template: String, coordinate: TileCoordinate, config: TileServerConfigProtocol) -> String
}

/// Protocol for authentication providers
public protocol AuthenticationProviderProtocol: Sendable {
    /// Adds authentication parameters to a URL
    /// - Parameter url: The base URL
    /// - Returns: URL with authentication parameters
    func authenticateURL(_ url: String) -> String
    
    /// Provides authentication headers
    /// - Returns: Dictionary of authentication headers
    func authenticationHeaders() -> [String: String]
}