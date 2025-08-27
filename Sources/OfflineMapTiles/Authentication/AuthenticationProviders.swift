import Foundation

/// Simple API key authentication provider
public struct SimpleAPIKeyAuthProvider: AuthenticationProviderProtocol {
    private let apiKey: String
    private let parameterName: String
    
    public init(apiKey: String, parameterName: String = "access_token") {
        self.apiKey = apiKey
        self.parameterName = parameterName
    }
    
    public func authenticateURL(_ url: String) -> String {
        if url.contains("{\(parameterName)}") {
            return url.replacingOccurrences(of: "{\(parameterName)}", with: apiKey)
        } else {
            let separator = url.contains("?") ? "&" : "?"
            return url + "\(separator)\(parameterName)=\(apiKey)"
        }
    }
    
    public func authenticationHeaders() -> [String: String] {
        return [:]
    }
}

/// Mapbox-specific authentication provider
public struct MapboxAuthProvider: AuthenticationProviderProtocol {
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func authenticateURL(_ url: String) -> String {
        if url.contains("{access_token}") {
            return url.replacingOccurrences(of: "{access_token}", with: apiKey)
        } else {
            let separator = url.contains("?") ? "&" : "?"
            return url + "\(separator)access_token=\(apiKey)"
        }
    }
    
    public func authenticationHeaders() -> [String: String] {
        return ["User-Agent": "OfflineMapTiles/2.0"]
    }
}

/// Google Maps authentication provider
public struct GoogleMapsAuthProvider: AuthenticationProviderProtocol {
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func authenticateURL(_ url: String) -> String {
        if url.contains("{api_key}") {
            return url.replacingOccurrences(of: "{api_key}", with: apiKey)
        } else {
            let separator = url.contains("?") ? "&" : "?"
            return url + "\(separator)key=\(apiKey)"
        }
    }
    
    public func authenticationHeaders() -> [String: String] {
        return [:]
    }
}

/// Bing Maps authentication provider
public struct BingMapsAuthProvider: AuthenticationProviderProtocol {
    private let apiKey: String
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func authenticateURL(_ url: String) -> String {
        if url.contains("{api_key}") {
            return url.replacingOccurrences(of: "{api_key}", with: apiKey)
        } else {
            let separator = url.contains("?") ? "&" : "?"
            return url + "\(separator)key=\(apiKey)"
        }
    }
    
    public func authenticationHeaders() -> [String: String] {
        return [:]
    }
}

/// Header-based authentication provider
public struct HeaderAuthProvider: AuthenticationProviderProtocol {
    private let headers: [String: String]
    
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    public init(apiKey: String, headerName: String = "Authorization") {
        self.init(headers: [headerName: "Bearer \(apiKey)"])
    }
    
    public func authenticateURL(_ url: String) -> String {
        return url // No URL modification needed for header auth
    }
    
    public func authenticationHeaders() -> [String: String] {
        return headers
    }
}

/// OAuth2 bearer token authentication provider
public struct OAuth2AuthProvider: AuthenticationProviderProtocol {
    private let accessToken: String
    private let tokenType: String
    
    public init(accessToken: String, tokenType: String = "Bearer") {
        self.accessToken = accessToken
        self.tokenType = tokenType
    }
    
    public func authenticateURL(_ url: String) -> String {
        return url // OAuth2 typically uses headers
    }
    
    public func authenticationHeaders() -> [String: String] {
        return ["Authorization": "\(tokenType) \(accessToken)"]
    }
}

/// Custom authentication provider for advanced scenarios
public struct CustomAuthProvider: AuthenticationProviderProtocol {
    private let urlModifier: @Sendable (String) -> String
    private let headers: [String: String]
    
    public init(
        urlModifier: @escaping @Sendable (String) -> String = { $0 },
        headers: [String: String] = [:]
    ) {
        self.urlModifier = urlModifier
        self.headers = headers
    }
    
    public func authenticateURL(_ url: String) -> String {
        return urlModifier(url)
    }
    
    public func authenticationHeaders() -> [String: String] {
        return headers
    }
}