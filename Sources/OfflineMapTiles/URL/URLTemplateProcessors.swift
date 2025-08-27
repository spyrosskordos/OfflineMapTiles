import Foundation

/// Default URL template processor
public struct DefaultURLTemplateProcessor: URLTemplateProcessorProtocol {
    public init() {}
    
    public func processTemplate(
        _ template: String,
        coordinate: TileCoordinate,
        config: TileServerConfigProtocol
    ) -> String {
        var url = template
            .replacingOccurrences(of: "{z}", with: String(coordinate.zoom))
            .replacingOccurrences(of: "{x}", with: String(coordinate.x))
            .replacingOccurrences(of: "{y}", with: String(coordinate.y))
        
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
        
        return url
    }
}

/// QuadKey URL template processor (used by Bing Maps)
public struct QuadKeyURLTemplateProcessor: URLTemplateProcessorProtocol {
    public init() {}
    
    public func processTemplate(
        _ template: String,
        coordinate: TileCoordinate,
        config: TileServerConfigProtocol
    ) -> String {
        let defaultProcessor = DefaultURLTemplateProcessor()
        var url = defaultProcessor.processTemplate(template, coordinate: coordinate, config: config)
        
        // Support for quadkey format
        if url.contains("{quadkey}") {
            let quadkey = generateQuadkey(coordinate: coordinate)
            url = url.replacingOccurrences(of: "{quadkey}", with: quadkey)
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
}

/// TMS (Tile Map Service) URL template processor
public struct TMSURLTemplateProcessor: URLTemplateProcessorProtocol {
    public init() {}
    
    public func processTemplate(
        _ template: String,
        coordinate: TileCoordinate,
        config: TileServerConfigProtocol
    ) -> String {
        let defaultProcessor = DefaultURLTemplateProcessor()
        var url = defaultProcessor.processTemplate(template, coordinate: coordinate, config: config)
        
        // TMS uses flipped Y coordinate by default
        let tmsY = (1 << coordinate.zoom) - 1 - coordinate.y
        url = url.replacingOccurrences(of: "{y}", with: String(tmsY))
        
        return url
    }
}

/// Custom URL template processor that allows for custom placeholder replacements
public struct CustomURLTemplateProcessor: URLTemplateProcessorProtocol {
    private let customReplacements: [String: @Sendable (TileCoordinate, TileServerConfigProtocol) -> String]
    private let baseProcessor: URLTemplateProcessorProtocol
    
    public init(
        customReplacements: [String: @Sendable (TileCoordinate, TileServerConfigProtocol) -> String] = [:],
        baseProcessor: URLTemplateProcessorProtocol = DefaultURLTemplateProcessor()
    ) {
        self.customReplacements = customReplacements
        self.baseProcessor = baseProcessor
    }
    
    public func processTemplate(
        _ template: String,
        coordinate: TileCoordinate,
        config: TileServerConfigProtocol
    ) -> String {
        var url = baseProcessor.processTemplate(template, coordinate: coordinate, config: config)
        
        for (placeholder, replacementFunction) in customReplacements {
            if url.contains(placeholder) {
                let replacement = replacementFunction(coordinate, config)
                url = url.replacingOccurrences(of: placeholder, with: replacement)
            }
        }
        
        return url
    }
}