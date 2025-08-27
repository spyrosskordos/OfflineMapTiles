import Foundation

public enum TileFormat: String, CaseIterable, Sendable {
    case png = "png"
    case jpg = "jpg"
    case jpeg = "jpeg"
    case webp = "webp"
    case mvt = "mvt"
}

public struct TileServerConfig: TileServerConfigProtocol, Sendable {
    public let name: String
    public let baseURL: String
    public let format: TileFormat
    public let minZoom: Int
    public let maxZoom: Int
    public let attribution: String?
    public let apiKey: String?
    public let customHeaders: [String: String]
    private let _retryPolicy: RetryPolicy
    public let bounds: MapBounds?
    
    public init(
        name: String,
        baseURL: String,
        format: TileFormat = .png,
        minZoom: Int = 0,
        maxZoom: Int = 18,
        attribution: String? = nil,
        apiKey: String? = nil,
        customHeaders: [String: String] = [:],
        retryPolicy: RetryPolicy = .default,
        bounds: MapBounds? = nil
    ) {
        self.name = name
        self.baseURL = baseURL
        self.format = format
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.attribution = attribution
        self.apiKey = apiKey
        self.customHeaders = customHeaders
        self._retryPolicy = retryPolicy
        self.bounds = bounds
    }
    
    public func tileURL(for coordinate: TileCoordinate) -> String {
        var url = baseURL
            .replacingOccurrences(of: "{z}", with: String(coordinate.zoom))
            .replacingOccurrences(of: "{x}", with: String(coordinate.x))
            .replacingOccurrences(of: "{y}", with: String(coordinate.y))
        
        // Support for quadkey format (used by Bing Maps)
        if url.contains("{quadkey}") {
            let quadkey = generateQuadkey(coordinate: coordinate)
            url = url.replacingOccurrences(of: "{quadkey}", with: quadkey)
        }
        
        // Support for TMS y-coordinate (flipped)
        if url.contains("{-y}") {
            let tmsY = (1 << coordinate.zoom) - 1 - coordinate.y
            url = url.replacingOccurrences(of: "{-y}", with: String(tmsY))
        }
        
        // Support for subdomain rotation
        if url.contains("{s}") {
            let subdomains = ["a", "b", "c", "d"]
            let subdomain = subdomains[(coordinate.x + coordinate.y) % subdomains.count]
            url = url.replacingOccurrences(of: "{s}", with: subdomain)
        }
        
        // Add API key if provided
        if let apiKey = apiKey {
            let separator = url.contains("?") ? "&" : "?"
            if url.contains("{api_key}") {
                url = url.replacingOccurrences(of: "{api_key}", with: apiKey)
            } else {
                url += "\(separator)access_token=\(apiKey)"
            }
        }
        
        return url
    }
    
    private func generateQuadkey(coordinate: TileCoordinate) -> String {
        var quadkey = ""
        for i in stride(from: coordinate.zoom, to: 0, by: -1) {
            var digit = 0
            let mask = 1 << (i - 1)
            if (coordinate.x & mask) != 0 {
                digit += 1
            }
            if (coordinate.y & mask) != 0 {
                digit += 2
            }
            quadkey += String(digit)
        }
        return quadkey
    }
    
    public func isCoordinateInBounds(_ coordinate: TileCoordinate) -> Bool {
        guard let bounds = self.bounds else {
            return true
        }
        
        let calculator = DefaultTileCalculator()
        let tileToCoordinate = calculator.tileToCoordinate(tile: coordinate)
        
        return tileToCoordinate.latitude <= bounds.northEast.latitude &&
               tileToCoordinate.latitude >= bounds.southWest.latitude &&
               tileToCoordinate.longitude >= bounds.southWest.longitude &&
               tileToCoordinate.longitude <= bounds.northEast.longitude
    }
}

// MARK: - TileServerConfigProtocol Conformance
extension TileServerConfig {
    public var retryPolicy: RetryPolicyProtocol {
        return _retryPolicy
    }
    
    public var httpConfiguration: HTTPConfigurationProtocol {
        return DefaultHTTPConfiguration()
    }
    
    public func isZoomLevelSupported(_ zoom: Int) -> Bool {
        return zoom >= minZoom && zoom <= maxZoom
    }
}

public struct RetryPolicy: RetryPolicyProtocol, Sendable {
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
    
    public static let `default` = RetryPolicy()
    public static let aggressive = RetryPolicy(maxAttempts: 5, baseDelay: 0.5)
    public static let conservative = RetryPolicy(maxAttempts: 2, baseDelay: 2.0, maxDelay: 16.0)
}

// MARK: - Common Tile Server Configurations

public extension TileServerConfig {
    
    static let openStreetMap = TileServerConfig(
        name: "OpenStreetMap",
        baseURL: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        format: .png,
        maxZoom: 19,
        attribution: "© OpenStreetMap contributors"
    )
    
    static let openStreetMapDe = TileServerConfig(
        name: "OpenStreetMap DE",
        baseURL: "https://{s}.tile.openstreetmap.de/{z}/{x}/{y}.png",
        format: .png,
        maxZoom: 18,
        attribution: "© OpenStreetMap contributors"
    )
    
    static let cartoDB = TileServerConfig(
        name: "CartoDB Positron",
        baseURL: "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
        format: .png,
        maxZoom: 18,
        attribution: "© OpenStreetMap contributors © CARTO"
    )
    
    static let cartoDBDark = TileServerConfig(
        name: "CartoDB Dark Matter",
        baseURL: "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png",
        format: .png,
        maxZoom: 18,
        attribution: "© OpenStreetMap contributors © CARTO"
    )
    
    static let stamenTerrain = TileServerConfig(
        name: "Stamen Terrain",
        baseURL: "https://stamen-tiles-{s}.a.ssl.fastly.net/terrain/{z}/{x}/{y}.jpg",
        format: .jpg,
        maxZoom: 18,
        attribution: "Map tiles by Stamen Design, CC BY 3.0 — Map data © OpenStreetMap contributors"
    )
    
    static let stamenWatercolor = TileServerConfig(
        name: "Stamen Watercolor",
        baseURL: "https://stamen-tiles-{s}.a.ssl.fastly.net/watercolor/{z}/{x}/{y}.jpg",
        format: .jpg,
        maxZoom: 16,
        attribution: "Map tiles by Stamen Design, CC BY 3.0 — Map data © OpenStreetMap contributors"
    )
    
    static func mapbox(style: String, apiKey: String) -> TileServerConfig {
        return TileServerConfig(
            name: "Mapbox \(style.capitalized)",
            baseURL: "https://api.mapbox.com/styles/v1/mapbox/\(style)/tiles/{z}/{x}/{y}",
            format: .png,
            maxZoom: 22,
            attribution: "© Mapbox © OpenStreetMap contributors",
            apiKey: apiKey,
            customHeaders: ["User-Agent": "OfflineMapTiles/1.0"]
        )
    }
    
    static func googleMaps(mapType: String, apiKey: String) -> TileServerConfig {
        return TileServerConfig(
            name: "Google Maps \(mapType.capitalized)",
            baseURL: "https://mt1.google.com/vt/lyrs=\(mapType)&x={x}&y={y}&z={z}",
            format: .png,
            maxZoom: 20,
            attribution: "© Google",
            apiKey: apiKey
        )
    }
    
    static func bingMaps(mapType: String, apiKey: String) -> TileServerConfig {
        return TileServerConfig(
            name: "Bing Maps \(mapType.capitalized)",
            baseURL: "https://ecn.t3.tiles.virtualearth.net/tiles/\(mapType){quadkey}.jpeg?g=1",
            format: .jpeg,
            maxZoom: 19,
            attribution: "© Microsoft Corporation",
            apiKey: apiKey
        )
    }
    
    static func arcGISOnline(service: ArcGISService) -> TileServerConfig {
        return TileServerConfig(
            name: "ArcGIS \(service.name)",
            baseURL: "https://server.arcgisonline.com/ArcGIS/rest/services/\(service.path)/MapServer/tile/{z}/{y}/{x}",
            format: .jpg,
            maxZoom: 19,
            attribution: "Powered by Esri"
        )
    }
}

// GoogleMapType moved to TileServerConfigFactory.swift

// BingMapType moved to TileServerConfigFactory.swift

public enum ArcGISService {
    case worldImagery
    case worldStreetMap
    case worldTopographic
    case worldTerrain
    case worldShadedRelief
    case worldPhysical
    case oceanBasemap
    case natGeoWorldMap
    
    var name: String {
        switch self {
        case .worldImagery: return "World Imagery"
        case .worldStreetMap: return "World Street Map"
        case .worldTopographic: return "World Topographic"
        case .worldTerrain: return "World Terrain"
        case .worldShadedRelief: return "World Shaded Relief"
        case .worldPhysical: return "World Physical"
        case .oceanBasemap: return "Ocean Basemap"
        case .natGeoWorldMap: return "National Geographic World Map"
        }
    }
    
    var path: String {
        switch self {
        case .worldImagery: return "World_Imagery"
        case .worldStreetMap: return "World_Street_Map"
        case .worldTopographic: return "World_Topo_Map"
        case .worldTerrain: return "World_Terrain_Base"
        case .worldShadedRelief: return "World_Shaded_Relief"
        case .worldPhysical: return "World_Physical_Map"
        case .oceanBasemap: return "Ocean_Basemap"
        case .natGeoWorldMap: return "NatGeo_World_Map"
        }
    }
}