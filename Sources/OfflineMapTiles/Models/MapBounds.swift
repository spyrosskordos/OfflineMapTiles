import Foundation
import CoreLocation

public struct MapBounds: Sendable {
    public let northEast: CLLocationCoordinate2D
    public let southWest: CLLocationCoordinate2D
    
    public init(northEast: CLLocationCoordinate2D, southWest: CLLocationCoordinate2D) {
        self.northEast = northEast
        self.southWest = southWest
    }
}