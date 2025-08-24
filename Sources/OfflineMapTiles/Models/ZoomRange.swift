import Foundation

public struct ZoomRange: Sendable {
    public let minZoom: Int
    public let maxZoom: Int
    
    public init(minZoom: Int, maxZoom: Int) {
        precondition(minZoom >= 0 && maxZoom >= minZoom && maxZoom <= 20, "Invalid zoom range")
        self.minZoom = minZoom
        self.maxZoom = maxZoom
    }
}