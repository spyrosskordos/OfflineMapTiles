import Testing
import CoreLocation
@testable import OfflineMapTiles

@Test func testMapBoundsInitialization() async throws {
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
        southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    )
    
    #expect(abs(bounds.northEast.latitude - 37.8044) < 0.0001)
    #expect(abs(bounds.northEast.longitude - (-122.4078)) < 0.0001)
    #expect(abs(bounds.southWest.latitude - 37.7749) < 0.0001)
    #expect(abs(bounds.southWest.longitude - (-122.4194)) < 0.0001)
}

@Test func testZoomRangeValidation() async throws {
    let validRange = ZoomRange(minZoom: 5, maxZoom: 15)
    #expect(validRange.minZoom == 5)
    #expect(validRange.maxZoom == 15)
}

@Test func testTileCoordinateEquality() async throws {
    let tile1 = TileCoordinate(x: 100, y: 200, zoom: 10)
    let tile2 = TileCoordinate(x: 100, y: 200, zoom: 10)
    let tile3 = TileCoordinate(x: 101, y: 200, zoom: 10)
    
    #expect(tile1 == tile2)
    #expect(tile1 != tile3)
    #expect(tile1.hashValue == tile2.hashValue)
}

@Test func testDownloadProgressCalculation() async throws {
    let progress = DownloadProgress(totalTiles: 100, downloadedTiles: 25, failedTiles: 5)
    
    #expect(progress.totalTiles == 100)
    #expect(progress.downloadedTiles == 25)
    #expect(progress.failedTiles == 5)
    #expect(abs(progress.percentage - 25.0) < 0.001)
    #expect(progress.currentTile == nil)
}

@Test func testDownloadProgressWithCurrentTile() async throws {
    let currentTile = TileCoordinate(x: 50, y: 75, zoom: 12)
    let progress = DownloadProgress(totalTiles: 50, downloadedTiles: 10, failedTiles: 2, currentTile: currentTile)
    
    #expect(abs(progress.percentage - 20.0) < 0.001)
    #expect(progress.currentTile != nil)
    #expect(progress.currentTile! == currentTile)
}

@Test func testDownloadResultSuccessRate() async throws {
    let result = DownloadResult(
        totalTiles: 100,
        successfulTiles: 85,
        failedTiles: 15,
        downloadTime: 30.5,
        averageDownloadSpeed: 2.78
    )
    
    #expect(abs(result.successRate - 0.85) < 0.001)
    #expect(result.totalTiles == 100)
    #expect(result.successfulTiles == 85)
    #expect(result.failedTiles == 15)
}

@Test func testTileCalculatorBasicFunctionality() async throws {
    let calculator = TileCalculator()
    
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
        southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    let tiles = calculator.calculateTiles(for: bounds, zoomRange: zoomRange)
    
    #expect(tiles.count > 0)
    
    for tile in tiles {
        #expect(tile.zoom >= 10)
        #expect(tile.zoom <= 12)
        #expect(tile.x >= 0)
        #expect(tile.y >= 0)
    }
}

@Test func testCoordinateToTileConversion() async throws {
    let calculator = TileCalculator()
    
    let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    let tile10 = calculator.coordinateToTile(coordinate: sanFrancisco, zoom: 10)
    #expect(tile10.x > 0)
    #expect(tile10.y > 0)
    #expect(tile10.zoom == 10)
    
    let tile15 = calculator.coordinateToTile(coordinate: sanFrancisco, zoom: 15)
    #expect(tile15.x > tile10.x)
    #expect(tile15.y > tile10.y)
    #expect(tile15.zoom == 15)
}

@Test func testTileToCoordinateConversion() async throws {
    let calculator = TileCalculator()
    
    let tile = TileCoordinate(x: 163, y: 395, zoom: 10)
    let coordinate = calculator.tileToCoordinate(tile: tile)
    
    #expect(coordinate.latitude > -90)
    #expect(coordinate.latitude < 90)
    #expect(coordinate.longitude > -180)
    #expect(coordinate.longitude < 180)
}

@Test func testRoundTripConversion() async throws {
    let calculator = TileCalculator()
    
    let originalCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let tile = calculator.coordinateToTile(coordinate: originalCoordinate, zoom: 10)
    let convertedCoordinate = calculator.tileToCoordinate(tile: tile)
    
    #expect(abs(convertedCoordinate.latitude - originalCoordinate.latitude) < 0.5)
    #expect(abs(convertedCoordinate.longitude - originalCoordinate.longitude) < 0.5)
}

@Test func testOfflineMapTilesInitialization() async throws {
    _ = try OfflineMapTiles()
    // Test passes if initialization doesn't throw
}

@Test func testCustomTileServerInitialization() async throws {
    let customServer = "https://example.com/{z}/{x}/{y}.png"
    _ = try OfflineMapTiles(tileServerURL: customServer)
    // Test passes if initialization doesn't throw
}

@Test func testInvalidBoundsError() async throws {
    let mapTiles = try OfflineMapTiles()
    
    let invalidBounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4078),
        southWest: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4194)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    
    do {
        _ = try await mapTiles.downloadTiles(for: invalidBounds, zoomRange: zoomRange)
        #expect(Bool(false), "Should throw invalidBounds error")
    } catch OfflineMapTilesError.invalidBounds {
        // Expected error - test passes
    } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
    }
}

@Test func testAsyncSemaphore() async throws {
    let semaphore = AsyncSemaphore(value: 2)
    
    let completedTasks = await withTaskGroup(of: Int.self, returning: Int.self) { group in
        for _ in 0..<5 {
            group.addTask {
                await semaphore.wait()
                
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                await semaphore.signal()
                return 1
            }
        }
        
        var count = 0
        for await task in group {
            count += task
        }
        return count
    }
    
    #expect(completedTasks == 5)
}

@Test func testTileServerConfigDefaults() async throws {
    let osmConfig = TileServerConfig.openStreetMap
    #expect(osmConfig.name == "OpenStreetMap")
    #expect(osmConfig.format == .png)
    #expect(osmConfig.maxZoom == 19)
    #expect(osmConfig.attribution?.contains("OpenStreetMap") == true)
}

@Test func testTileURLGeneration() async throws {
    let config = TileServerConfig.openStreetMap
    let tile = TileCoordinate(x: 1234, y: 5678, zoom: 12)
    
    let url = config.tileURL(for: tile)
    #expect(url.contains("1234"))
    #expect(url.contains("5678"))
    #expect(url.contains("12"))
}

@Test func testSubdomainRotation() async throws {
    let config = TileServerConfig(
        name: "Test",
        baseURL: "https://{s}.example.com/{z}/{x}/{y}.png"
    )
    
    let tile1 = TileCoordinate(x: 0, y: 0, zoom: 10)
    let tile2 = TileCoordinate(x: 1, y: 0, zoom: 10)
    
    let url1 = config.tileURL(for: tile1)
    let url2 = config.tileURL(for: tile2)
    
    #expect(url1.contains("a.example.com"))
    #expect(url2.contains("b.example.com"))
}

@Test func testQuadkeyGeneration() async throws {
    let config = TileServerConfig(
        name: "Bing Test",
        baseURL: "https://example.com/tiles/{quadkey}.jpeg"
    )
    
    let tile = TileCoordinate(x: 1, y: 1, zoom: 2)
    let url = config.tileURL(for: tile)
    
    #expect(url.contains("03")) // Quadkey for tile (1,1) at zoom 2
}

@Test func testTMSYCoordinate() async throws {
    let config = TileServerConfig(
        name: "TMS Test",
        baseURL: "https://example.com/{z}/{x}/{-y}.png"
    )
    
    let tile = TileCoordinate(x: 1, y: 1, zoom: 2)
    let url = config.tileURL(for: tile)
    
    // For zoom 2, y=1 becomes -y=2 (4-1-1=2)
    #expect(url.contains("/2/1/2.png"))
}

@Test func testMapboxConfiguration() async throws {
    let config = TileServerConfig.mapbox(style: "streets-v11", apiKey: "test-key")
    
    #expect(config.name.contains("Mapbox"))
    #expect(config.apiKey == "test-key")
    #expect(config.maxZoom == 22)
    
    let tile = TileCoordinate(x: 100, y: 200, zoom: 10)
    let url = config.tileURL(for: tile)
    
    #expect(url.contains("streets-v11"))
    #expect(url.contains("test-key"))
}

@Test func testDifferentTileFormats() async throws {
    let pngConfig = TileServerConfig(name: "PNG", baseURL: "https://example.com/{z}/{x}/{y}.png", format: .png)
    let jpgConfig = TileServerConfig(name: "JPG", baseURL: "https://example.com/{z}/{x}/{y}.jpg", format: .jpg)
    
    #expect(pngConfig.format == .png)
    #expect(jpgConfig.format == .jpg)
}

@Test func testRetryPolicyConfiguration() async throws {
    let aggressivePolicy = RetryPolicy.aggressive
    let conservativePolicy = RetryPolicy.conservative
    
    #expect(aggressivePolicy.maxAttempts == 5)
    #expect(aggressivePolicy.baseDelay == 0.5)
    
    #expect(conservativePolicy.maxAttempts == 2)
    #expect(conservativePolicy.baseDelay == 2.0)
}

@Test func testOfflineMapTilesWithCustomConfig() async throws {
    let customConfig = TileServerConfig(
        name: "Custom Server",
        baseURL: "https://custom.example.com/{z}/{x}/{y}.png",
        format: .png,
        maxZoom: 15
    )
    
    let mapTiles = try OfflineMapTiles(tileServerConfig: customConfig)
    #expect(mapTiles.serverInfo.name == "Custom Server")
    #expect(mapTiles.serverInfo.maxZoom == 15)
}

@Test func testBackwardCompatibilityInit() async throws {
    let mapTiles = try OfflineMapTiles(tileServerURL: "https://example.com/{z}/{x}/{y}.jpg")
    #expect(mapTiles.serverInfo.format == .jpg)
    #expect(mapTiles.serverInfo.name == "Custom")
}

@Test func testTileSizeEstimation() async throws {
    let config = TileServerConfig.openStreetMap
    let mapTiles = try OfflineMapTiles(tileServerConfig: config)
    
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.4078),
        southWest: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    
    let estimation = try mapTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    
    #expect(estimation.totalTiles > 0)
    #expect(estimation.estimatedSizeBytes > 0)
    #expect(estimation.estimatedSizeMB > 0)
    #expect(estimation.tileFormat == .png)
    #expect(estimation.zoomLevels.count == 3) // zoom levels 10, 11, 12
    #expect(estimation.averageTileSize > 0)
}

@Test func testSizeEstimationFormatDifferences() async throws {
    let pngConfig = TileServerConfig(name: "PNG", baseURL: "https://example.com/{z}/{x}/{y}.png", format: .png)
    let jpgConfig = TileServerConfig(name: "JPG", baseURL: "https://example.com/{z}/{x}/{y}.jpg", format: .jpg)
    let webpConfig = TileServerConfig(name: "WebP", baseURL: "https://example.com/{z}/{x}/{y}.webp", format: .webp)
    
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
        southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
    )
    
    let zoomRange = ZoomRange(minZoom: 12, maxZoom: 14)
    
    let pngTiles = try OfflineMapTiles(tileServerConfig: pngConfig)
    let jpgTiles = try OfflineMapTiles(tileServerConfig: jpgConfig)
    let webpTiles = try OfflineMapTiles(tileServerConfig: webpConfig)
    
    let pngEstimation = try pngTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    let jpgEstimation = try jpgTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    let webpEstimation = try webpTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    
    #expect(pngEstimation.totalTiles == jpgEstimation.totalTiles) // Same tile count
    #expect(pngEstimation.totalTiles == webpEstimation.totalTiles) // Same tile count
    
    // Different formats should have different size estimates
    #expect(pngEstimation.estimatedSizeBytes != jpgEstimation.estimatedSizeBytes)
    #expect(jpgEstimation.estimatedSizeBytes != webpEstimation.estimatedSizeBytes)
    
    // WebP should generally be smaller than PNG/JPEG
    #expect(webpEstimation.estimatedSizeBytes < pngEstimation.estimatedSizeBytes)
}

@Test func testDownloadSizeValidationWithinLimit() async throws {
    let mapTiles = try OfflineMapTiles()
    
    // Small area should be well within 600MB limit
    let smallBounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
        southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
    )
    
    let smallZoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    
    // This should not throw
    let estimation = try mapTiles.estimateDownloadSize(for: smallBounds, zoomRange: smallZoomRange)
    #expect(estimation.isWithinRecommendedLimit == true)
}

@Test func testDownloadSizeValidationExceedsLimit() async throws {
    let mapTiles = try OfflineMapTiles()
    
    // Large area with high zoom should exceed 600MB limit
    let largeBounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 40.0, longitude: -120.0),
        southWest: CLLocationCoordinate2D(latitude: 35.0, longitude: -125.0)
    )
    
    let highZoomRange = ZoomRange(minZoom: 10, maxZoom: 18)
    
    do {
        let estimation = try mapTiles.estimateDownloadSize(for: largeBounds, zoomRange: highZoomRange)
        #expect(estimation.isWithinRecommendedLimit == false)
        
        // This should throw when trying to download
        _ = try await mapTiles.downloadTiles(for: largeBounds, zoomRange: highZoomRange)
        #expect(Bool(false), "Should have thrown size limit error")
    } catch OfflineMapTilesError.downloadSizeExceedsLimit {
        // Expected error
    } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
    }
}

@Test func testCustomDownloadSizeLimit() async throws {
    let mapTiles = try OfflineMapTiles()
    
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.4),
        southWest: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.5)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 14)
    
    // Try with very small custom limit (1MB)
    do {
        _ = try await mapTiles.downloadTiles(for: bounds, zoomRange: zoomRange, maxDownloadSizeMB: 1)
        #expect(Bool(false), "Should have thrown size limit error with 1MB limit")
    } catch OfflineMapTilesError.downloadSizeExceedsLimit {
        // Expected error
    } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
    }
}

@Test func testSkipSizeValidation() async throws {
    let mapTiles = try OfflineMapTiles()
    
    // Large area that would normally fail validation
    let largeBounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.9, longitude: -122.3),
        southWest: CLLocationCoordinate2D(latitude: 37.6, longitude: -122.6)
    )
    
    let highZoomRange = ZoomRange(minZoom: 10, maxZoom: 16)
    
    // This should not throw when skipping validation
    // Note: We're not actually downloading, just testing the validation skip
    do {
        _ = try await mapTiles.downloadTiles(for: largeBounds, zoomRange: highZoomRange, skipSizeValidation: true)
        // The download might fail due to network issues in tests, but size validation should be skipped
    } catch OfflineMapTilesError.downloadSizeExceedsLimit {
        #expect(Bool(false), "Size validation should have been skipped")
    } catch {
        // Other errors (like network errors) are acceptable for this test
    }
}

@Test func testSizeEstimationFormattedOutput() async throws {
    let mapTiles = try OfflineMapTiles()
    
    let bounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
        southWest: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    
    let estimation = try mapTiles.estimateDownloadSize(for: bounds, zoomRange: zoomRange)
    
    #expect(estimation.formattedSize.contains("B")) // Should contain bytes unit
    #expect(estimation.estimatedSizeMB > 0)
}

@Test func testInvalidBoundsForEstimation() async throws {
    let mapTiles = try OfflineMapTiles()
    
    // Invalid bounds (north < south)
    let invalidBounds = MapBounds(
        northEast: CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4),
        southWest: CLLocationCoordinate2D(latitude: 37.8, longitude: -122.5)
    )
    
    let zoomRange = ZoomRange(minZoom: 10, maxZoom: 12)
    
    do {
        _ = try mapTiles.estimateDownloadSize(for: invalidBounds, zoomRange: zoomRange)
        #expect(Bool(false), "Should throw invalid bounds error")
    } catch {
        // Expected error (either from bounds validation or size estimation)
    }
}
