import Foundation

public struct TileCoordinate: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int
    public let zoom: Int
    
    public init(x: Int, y: Int, zoom: Int) {
        self.x = x
        self.y = y
        self.zoom = zoom
    }
}