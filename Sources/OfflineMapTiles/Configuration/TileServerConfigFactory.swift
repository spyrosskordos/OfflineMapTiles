import Foundation
import CoreLocation

/// Factory for creating tile server configurations
public final class TileServerConfigFactory {
    
    // MARK: - Popular Tile Servers
    
    public static func openStreetMap(
        retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    ) -> TileServerConfigProtocol {
        return DefaultTileServerConfig(
            name: "OpenStreetMap",
            baseURL: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            format: .png,
            minZoom: 0,
            maxZoom: 19,
            attribution: "© OpenStreetMap contributors",
            bounds: nil,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: DefaultURLTemplateProcessor(),
            authProvider: nil
        )
    }
    
    public static func cartoDB(
        style: CartoDBStyle = .positron,
        retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    ) -> TileServerConfigProtocol {
        let baseURL: String
        let name: String
        
        switch style {
        case .positron:
            baseURL = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png"
            name = "CartoDB Positron"
        case .darkMatter:
            baseURL = "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png"
            name = "CartoDB Dark Matter"
        case .voyager:
            baseURL = "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png"
            name = "CartoDB Voyager"
        }
        
        return DefaultTileServerConfig(
            name: name,
            baseURL: baseURL,
            format: .png,
            minZoom: 0,
            maxZoom: 18,
            attribution: "© OpenStreetMap contributors © CARTO",
            bounds: nil,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: DefaultURLTemplateProcessor(),
            authProvider: nil
        )
    }
    
    public static func mapbox(
        style: String,
        apiKey: String,
        retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    ) -> TileServerConfigProtocol {
        let authProvider = MapboxAuthProvider(apiKey: apiKey)
        
        return DefaultTileServerConfig(
            name: "Mapbox \(style.capitalized)",
            baseURL: "https://api.mapbox.com/styles/v1/mapbox/\(style)/tiles/{z}/{x}/{y}",
            format: .png,
            minZoom: 0,
            maxZoom: 22,
            attribution: "© Mapbox © OpenStreetMap contributors",
            bounds: nil,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: DefaultURLTemplateProcessor(),
            authProvider: authProvider
        )
    }
    
    public static func googleMaps(
        mapType: GoogleMapType,
        apiKey: String? = nil,
        retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    ) -> TileServerConfigProtocol {
        let authProvider = apiKey.map { GoogleMapsAuthProvider(apiKey: $0) }
        
        return DefaultTileServerConfig(
            name: "Google Maps \(mapType.displayName)",
            baseURL: "https://mt1.google.com/vt/lyrs=\(mapType.lyrsCode)&x={x}&y={y}&z={z}",
            format: .png,
            minZoom: 0,
            maxZoom: 20,
            attribution: "© Google",
            bounds: nil,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: DefaultURLTemplateProcessor(),
            authProvider: authProvider
        )
    }
    
    public static func bingMaps(
        mapType: BingMapType,
        apiKey: String,
        retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy(),
        httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    ) -> TileServerConfigProtocol {
        let authProvider = BingMapsAuthProvider(apiKey: apiKey)
        let urlProcessor = QuadKeyURLTemplateProcessor()
        
        return DefaultTileServerConfig(
            name: "Bing Maps \(mapType.displayName)",
            baseURL: "https://ecn.t3.tiles.virtualearth.net/tiles/\(mapType.tileType){quadkey}.jpeg?g=1",
            format: .jpeg,
            minZoom: 0,
            maxZoom: 19,
            attribution: "© Microsoft Corporation",
            bounds: nil,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: urlProcessor,
            authProvider: authProvider
        )
    }
    
    // MARK: - Custom Configuration Builder
    
    public static func custom() -> TileServerConfigBuilder {
        return TileServerConfigBuilder()
    }
    
    // MARK: - Bounded Configurations
    
    public static func boundedConfiguration(
        baseConfig: TileServerConfigProtocol,
        bounds: MapBounds
    ) -> TileServerConfigProtocol {
        return BoundedTileServerConfig(baseConfig: baseConfig, bounds: bounds)
    }
}

// MARK: - Supporting Types

public enum CartoDBStyle {
    case positron
    case darkMatter
    case voyager
}

public enum GoogleMapType {
    case roadmap
    case satellite
    case terrain
    case hybrid
    
    var lyrsCode: String {
        switch self {
        case .roadmap: return "m"
        case .satellite: return "s"
        case .terrain: return "t"
        case .hybrid: return "y"
        }
    }
    
    var displayName: String {
        switch self {
        case .roadmap: return "Roadmap"
        case .satellite: return "Satellite"
        case .terrain: return "Terrain"
        case .hybrid: return "Hybrid"
        }
    }
}

public enum BingMapType {
    case road
    case aerial
    case aerialWithLabels
    
    var tileType: String {
        switch self {
        case .road: return "r"
        case .aerial: return "a"
        case .aerialWithLabels: return "h"
        }
    }
    
    var displayName: String {
        switch self {
        case .road: return "Road"
        case .aerial: return "Aerial"
        case .aerialWithLabels: return "Aerial with Labels"
        }
    }
}

// MARK: - Builder Pattern

public final class TileServerConfigBuilder {
    private var name: String = "Custom Server"
    private var baseURL: String = ""
    private var format: TileFormat = .png
    private var minZoom: Int = 0
    private var maxZoom: Int = 18
    private var attribution: String?
    private var bounds: MapBounds?
    private var retryPolicy: RetryPolicyProtocol = DefaultRetryPolicy()
    private var httpConfig: HTTPConfigurationProtocol = DefaultHTTPConfiguration()
    private var urlProcessor: URLTemplateProcessorProtocol = DefaultURLTemplateProcessor()
    private var authProvider: AuthenticationProviderProtocol?
    
    public func name(_ name: String) -> TileServerConfigBuilder {
        self.name = name
        return self
    }
    
    public func baseURL(_ url: String) -> TileServerConfigBuilder {
        self.baseURL = url
        return self
    }
    
    public func format(_ format: TileFormat) -> TileServerConfigBuilder {
        self.format = format
        return self
    }
    
    public func zoomRange(min: Int, max: Int) -> TileServerConfigBuilder {
        self.minZoom = min
        self.maxZoom = max
        return self
    }
    
    public func attribution(_ attribution: String?) -> TileServerConfigBuilder {
        self.attribution = attribution
        return self
    }
    
    public func bounds(_ bounds: MapBounds?) -> TileServerConfigBuilder {
        self.bounds = bounds
        return self
    }
    
    public func retryPolicy(_ policy: RetryPolicyProtocol) -> TileServerConfigBuilder {
        self.retryPolicy = policy
        return self
    }
    
    public func httpConfiguration(_ config: HTTPConfigurationProtocol) -> TileServerConfigBuilder {
        self.httpConfig = config
        return self
    }
    
    public func urlProcessor(_ processor: URLTemplateProcessorProtocol) -> TileServerConfigBuilder {
        self.urlProcessor = processor
        return self
    }
    
    public func authProvider(_ provider: AuthenticationProviderProtocol?) -> TileServerConfigBuilder {
        self.authProvider = provider
        return self
    }
    
    public func apiKey(_ key: String) -> TileServerConfigBuilder {
        self.authProvider = SimpleAPIKeyAuthProvider(apiKey: key)
        return self
    }
    
    public func build() -> TileServerConfigProtocol {
        return DefaultTileServerConfig(
            name: name,
            baseURL: baseURL,
            format: format,
            minZoom: minZoom,
            maxZoom: maxZoom,
            attribution: attribution,
            bounds: bounds,
            retryPolicy: retryPolicy,
            httpConfiguration: httpConfig,
            urlProcessor: urlProcessor,
            authProvider: authProvider
        )
    }
}