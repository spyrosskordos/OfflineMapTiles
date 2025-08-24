# OfflineMapTiles Architecture

This document describes the organized layered architecture of the OfflineMapTiles library.

## 📁 Directory Structure

```
Sources/OfflineMapTiles/
├── OfflineMapTiles.swift          # Main public API class
├── Configuration/                  # Configuration and settings
│   └── TileServerConfig.swift     # Tile server configurations, presets, and URL patterns
├── Models/                        # Data models and types
│   ├── MapBounds.swift            # Geographic boundaries
│   ├── ZoomRange.swift            # Zoom level range definition
│   ├── TileCoordinate.swift       # Individual tile coordinates
│   ├── DownloadProgress.swift     # Progress tracking data
│   ├── DownloadResult.swift       # Download completion results
│   ├── TileSizeEstimation.swift   # Size estimation results
│   ├── OfflineMapTilesError.swift # Main error types
│   ├── SizeEstimationError.swift  # Size estimation specific errors
│   └── OfflineMapTilesDelegate.swift # Delegate protocol
├── Core/                          # Core business logic
│   ├── TileCalculator.swift       # Tile coordinate calculations
│   └── TileSizeEstimator.swift    # Download size estimation logic
├── Networking/                    # Network operations
│   └── TileDownloadManager.swift  # HTTP tile downloading with retry logic
├── Storage/                       # Persistence layer
│   └── TileStorageManager.swift   # File system storage operations
├── Utilities/                     # Helper utilities
│   ├── AsyncSemaphore.swift       # Concurrency control utility
│   └── ProtectedSet.swift         # Thread-safe collections
└── Examples/                      # Usage examples and demonstrations
    └── ExampleUsage.swift         # Comprehensive usage examples
```

## 🏗️ Layered Architecture

### 1. **Models Layer** (`Models/`)
- **Purpose**: Data structures and type definitions
- **Dependencies**: Foundation, CoreLocation (minimal)
- **Contents**: All public and internal data types
- **Principles**: Pure data structures, no business logic

### 2. **Core Layer** (`Core/`)
- **Purpose**: Business logic and calculations
- **Dependencies**: Models, Foundation
- **Contents**: Tile calculations, size estimations
- **Principles**: Stateless operations, pure functions where possible

### 3. **Configuration Layer** (`Configuration/`)
- **Purpose**: External configurations and settings
- **Dependencies**: Models, Foundation  
- **Contents**: Server configurations, URL patterns, presets
- **Principles**: Externalized configuration, preset management

### 4. **Networking Layer** (`Networking/`)
- **Purpose**: External communications
- **Dependencies**: Models, Utilities, Foundation
- **Contents**: HTTP operations, retry logic, request management
- **Principles**: Network abstraction, error handling

### 5. **Storage Layer** (`Storage/`)
- **Purpose**: Data persistence
- **Dependencies**: Models, Configuration, Foundation
- **Contents**: File system operations, cache management
- **Principles**: Storage abstraction, automatic cleanup

### 6. **Utilities Layer** (`Utilities/`)
- **Purpose**: Shared helper functionality
- **Dependencies**: Foundation (minimal)
- **Contents**: Concurrency tools, thread-safe collections
- **Principles**: Reusable components, minimal dependencies

### 7. **Examples Layer** (`Examples/`)
- **Purpose**: Usage demonstrations and documentation
- **Dependencies**: All layers (for comprehensive examples)
- **Contents**: Real-world usage patterns, best practices
- **Principles**: Educational, practical demonstrations

## 🔄 Dependency Flow

```
Main API (OfflineMapTiles.swift)
    ↓
┌─── Core ←── Configuration
│     ↓
├─── Networking ←── Utilities
│     ↓
├─── Storage ←── Models
│     ↓
└─── Examples (references all)
```

## 🎯 Design Principles

### **Separation of Concerns**
- Each layer has a single, well-defined responsibility
- Cross-layer communication through clear interfaces
- Minimal coupling between layers

### **Dependency Inversion**
- Higher-level modules don't depend on lower-level modules
- Both depend on abstractions (protocols)
- Details depend on abstractions, not vice versa

### **Single Responsibility**
- Each file has one primary responsibility
- Models contain only data and validation
- Business logic separated from I/O operations

### **Open/Closed Principle**
- Open for extension through protocols and configuration
- Closed for modification through stable interfaces
- New tile servers can be added without changing core logic

## 📦 Benefits of This Architecture

### **Maintainability**
- Easy to locate and modify specific functionality
- Clear boundaries between different concerns
- Reduced risk of unintended side effects

### **Testability**
- Each layer can be tested independently
- Mock implementations easy to create
- Clear dependencies make testing straightforward

### **Scalability**
- New features can be added to appropriate layers
- Existing functionality remains stable
- Easy to extend without breaking changes

### **Readability**
- Code organization matches logical structure
- New developers can quickly understand the system
- Documentation aligns with code structure

## 🔧 Adding New Features

### **New Tile Server Type**
Add to: `Configuration/TileServerConfig.swift`

### **New Data Model**
Add to: `Models/` directory

### **New Calculation Logic**
Add to: `Core/` directory  

### **New Network Protocol**
Add to: `Networking/` directory

### **New Storage Backend**
Add to: `Storage/` directory

### **New Utility Function**
Add to: `Utilities/` directory

This architecture supports the library's growth while maintaining clean separation of concerns and clear dependency management.