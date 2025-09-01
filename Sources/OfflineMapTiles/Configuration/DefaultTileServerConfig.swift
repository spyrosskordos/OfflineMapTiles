import Foundation
import CoreLocation

/// Default implementation of TileServerConfigProtocol
public struct DefaultTileServerConfig: TileServerConfigProtocol {
    public let name: String
    public let baseURL: String
    public let format: TileFormat
    public let minZoom: Int
    public let maxZoom: Int
    public let attribution: String?
    public let bounds: MapBounds?
    public let retryPolicy: RetryPolicyProtocol
    public let httpConfiguration: HTTPConfigurationProtocol
    
    private let urlProcessor: URLTemplateProcessorProtocol
    private let authProvider: AuthenticationProviderProtocol?
    
    public init(
        name: String,
        baseURL: String,
        format: TileFormat,
        minZoom: Int,
        maxZoom: Int,
        attribution: String?,
        bounds: MapBounds?,
        retryPolicy: RetryPolicyProtocol,
        httpConfiguration: HTTPConfigurationProtocol,
        urlProcessor: URLTemplateProcessorProtocol,
        authProvider: AuthenticationProviderProtocol?
    ) {
        self.name = name
        self.baseURL = baseURL
        self.format = format
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.attribution = attribution
        self.bounds = bounds
        self.retryPolicy = retryPolicy
        self.httpConfiguration = httpConfiguration
        self.urlProcessor = urlProcessor
        self.authProvider = authProvider
    }
    
    public func tileURL(for coordinate: TileCoordinate) -> String {
        var url = urlProcessor.processTemplate(baseURL, coordinate: coordinate, config: self)
        
        if let authProvider = authProvider {
            url = authProvider.authenticateURL(url)
        }
        
        return url
    }
    
    public func isCoordinateInBounds(_ coordinate: TileCoordinate) -> Bool {
        guard let bounds = self.bounds else {
            return true
        }
        
        let calculator = DefaultTileCalculator()
        let tileCoordinate = calculator.tileToCoordinate(tile: coordinate)
        
        return tileCoordinate.latitude <= bounds.northEast.latitude &&
               tileCoordinate.latitude >= bounds.southWest.latitude &&
               tileCoordinate.longitude >= bounds.southWest.longitude &&
               tileCoordinate.longitude <= bounds.northEast.longitude
    }
    
    public func isZoomLevelSupported(_ zoom: Int) -> Bool {
        return zoom >= minZoom && zoom <= maxZoom
    }
}

/// Bounded tile server configuration wrapper
public struct BoundedTileServerConfig: TileServerConfigProtocol {
    private let baseConfig: TileServerConfigProtocol
    public let bounds: MapBounds?
    
    public init(baseConfig: TileServerConfigProtocol, bounds: MapBounds) {
        self.baseConfig = baseConfig
        self.bounds = bounds
    }
    
    public var name: String { baseConfig.name + " (Bounded)" }
    public var baseURL: String { baseConfig.baseURL }
    public var format: TileFormat { baseConfig.format }
    public var minZoom: Int { baseConfig.minZoom }
    public var maxZoom: Int { baseConfig.maxZoom }
    public var attribution: String? { baseConfig.attribution }
    public var retryPolicy: RetryPolicyProtocol { baseConfig.retryPolicy }
    public var httpConfiguration: HTTPConfigurationProtocol { baseConfig.httpConfiguration }
    
    public func tileURL(for coordinate: TileCoordinate) -> String {
        return baseConfig.tileURL(for: coordinate)
    }
    
    public func isCoordinateInBounds(_ coordinate: TileCoordinate) -> Bool {
        guard let bounds = self.bounds else {
            return baseConfig.isCoordinateInBounds(coordinate)
        }
        
        let calculator = DefaultTileCalculator()
        let tileCoordinate = calculator.tileToCoordinate(tile: coordinate)
        
        return tileCoordinate.latitude <= bounds.northEast.latitude &&
               tileCoordinate.latitude >= bounds.southWest.latitude &&
               tileCoordinate.longitude >= bounds.southWest.longitude &&
               tileCoordinate.longitude <= bounds.northEast.longitude
    }
    
    public func isZoomLevelSupported(_ zoom: Int) -> Bool {
        return baseConfig.isZoomLevelSupported(zoom)
    }
}

// MARK: - Default Implementations

public struct DefaultRetryPolicy: RetryPolicyProtocol {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 8.0,
        backoffMultiplier: Double = 2.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }
    
    public static let `default` = DefaultRetryPolicy()
    public static let aggressive = DefaultRetryPolicy(maxAttempts: 5, baseDelay: 0.5)
    public static let conservative = DefaultRetryPolicy(maxAttempts: 2, baseDelay: 2.0, maxDelay: 16.0)
}

public struct DefaultHTTPConfiguration: HTTPConfigurationProtocol {
    public let timeout: TimeInterval
    public let maxConcurrentOperations: Int
    public let customHeaders: [String: String]
    public let userAgent: String
    
    public init(
        timeout: TimeInterval = 30.0,
        maxConcurrentOperations: Int = 8,
        customHeaders: [String: String] = [:],
        userAgent: String = "OfflineMapTiles/2.0"
    ) {
        self.timeout = timeout
        self.maxConcurrentOperations = maxConcurrentOperations
        self.customHeaders = customHeaders
        self.userAgent = userAgent
    }
    
    public static let `default` = DefaultHTTPConfiguration()
}
