# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Know Maps** is a multi-platform (iOS, macOS, visionOS) location discovery application built with SwiftUI and SwiftData. Unlike traditional mapping apps, it focuses on contextual exploration and personalized recommendations using on-device Machine Learning (CoreML) and a conversational AI interface. The app acts as a "smart concierge" for finding businesses, restaurants, and points of interest based on natural language queries.

## Architecture

### Core Pattern: MVVM with Centralized Controller

The app follows **Model-View-ViewModel (MVVM)** with a centralized controller pattern:

- **View Layer**: Pure SwiftUI with declarative, reactive views
- **ViewModel Layer**: Specialized ViewModels handle view-specific logic (e.g., `ChatResultViewModel`, `SearchSavedViewModel`)
- **Controller Layer**: `DefaultModelController` acts as the central "brain," coordinating services, data models, and UI state

### Key Architectural Components

#### DefaultModelController (`Model/Controllers/DefaultModelController.swift`)
The central state manager that:
- Manages search results (`placeResults`, `recommendedPlaceResults`)
- Orchestrates location services and user positioning
- Coordinates data flow between network, cache, and UI
- Manages Assistive Chat state and intent resolution

#### AssistiveChatHostService (`Model/Controllers/AssistiveChatHostService.swift`)
Handles natural language query processing:
- Uses on-device CoreML models to classify user intent
- Converts natural language into structured search parameters
- Integrates with Foundation Models for embeddings and intent classification
- Maps Foursquare category taxonomy to internal representation

#### ContentView
Root view using `NavigationSplitView` for adaptive 2/3-column layouts across device types (iPhone/iPad/Mac/Vision Pro). Manages high-level navigation between search modes: Favorites (❤️), Industries (🏭), Tastes (✨), and Places (📍).

### Data Layer: Local-First with Cloud Sync

- **SwiftData**: Local persistence for `UserCachedRecord` and `RecommendationData` (stored in shared `ModelContainer`)
- **CloudKit**: Private iCloud sync via `CloudCacheManager` and `CloudCacheService`
- **Network**: Foursquare API for place data, Supabase for backend configuration

### Machine Learning

On-device CoreML models in `Model/ML/`:
- `LocalMapsQueryClassifier.mlmodel`: Classifies natural language query intent
- `LocalMapsQueryTagger.mlmodel`: Extracts structured entities from queries (cuisine types, locations, etc.)
- `FoundationModelsIntentClassifier`: Wraps ML models and provides intent classification logic
- `VectorEmbeddingService`: Handles semantic embeddings for search

Training data is stored alongside models in JSON format.

## Development Commands

### Building
```bash
# Build for iOS
xcodebuild -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for macOS
xcodebuild -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=macOS' build

# Build for visionOS
xcodebuild -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=visionOS Simulator' build
```

### Testing
```bash
# Run all tests
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know MapsTests" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know MapsTests" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Know_MapsTests/DefaultModelControllerTests

# Run single test method
xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know MapsTests" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Know_MapsTests/DefaultModelControllerTests/testRefreshModelSanitizesQuery
```

Test infrastructure:
- Main test suite: `Know MapsTests/`
- Mocks directory: `Know MapsTests/Mocks/` (contains mock services for testing)
- Test fixtures: `Know MapsTests/TestFixtures.swift`
- Controller tests: `DefaultModelControllerTests.swift`, `DefaultModelControllerStateTests.swift`

### Opening in Xcode
```bash
open "Know Maps.xcodeproj"
```

## Project Structure

```
Know Maps Prod/
├── Model/
│   ├── Controllers/         # Services and controllers (DefaultModelController, AssistiveChatHostService, etc.)
│   ├── Models/              # Data models and response types
│   ├── Network/             # Network session handlers (PlaceSearchSession, CloudCacheService)
│   ├── ViewModels/          # View-specific logic
│   ├── ML/                  # CoreML models and training data
│   ├── Protocols/           # Protocol definitions
│   └── Audio/               # Audio-related utilities
├── View/                    # SwiftUI views
├── Assets.xcassets/         # Images and assets
└── Know_MapsApp.swift       # App entry point with ModelContainer setup

Know MapsTests/              # Unit tests
├── Mocks/                   # Mock implementations for testing
├── TestFixtures.swift       # Shared test data
└── DefaultModelController*.swift  # Controller tests
```

## Key Technologies

- **SwiftUI**: All UI implementation
- **SwiftData**: Local data persistence with CloudKit sync
- **CloudKit**: Private iCloud database for user data
- **CoreML**: On-device ML for intent classification and query parsing
- **Swift Concurrency**: Extensive use of `async/await`, `Task`, `Actor` patterns
- **CoreLocation**: Location services integration
- **Segment Analytics**: Privacy-focused analytics (`SegmentAnalyticsService`)

### External Dependencies (Swift Package Manager)
- Nuke: Image loading and caching
- Segment: Analytics SDK
- Supabase: Backend services
- swift-clocks, swift-concurrency-extras: Testing utilities

## Multi-Platform Considerations

95%+ code is shared across platforms. Platform-specific code uses conditionals:
- `#if os(iOS)` / `#if os(macOS)` / `#if os(visionOS)`
- Platform-adaptive layouts via `NavigationSplitView`
- Vision Pro: Includes `ImmersiveSpace` for immersive experiences

## Concurrency & Performance

- **Actor Pattern**: `DetailFetchLimiter` actor throttles concurrent API requests
- **MainActor**: `DefaultModelController` and ViewModels are `@MainActor` bound
- **Task Management**: Startup uses coordinated async tasks with timeout handling
- **Dependency Injection**: Dependencies injected into `DefaultModelController` for testability

## Authentication & Security

- **Sign in with Apple**: Managed by `AppleAuthenticationService`
- **CloudKit**: Private database ensures user data stays in their iCloud account
- **Access Token Management**: Startup flow ensures valid access tokens before network operations

## App Lifecycle

Initialization sequence in `Know_MapsApp.swift`:
1. Create `ModelContainer` with SwiftData schema and CloudKit configuration
2. Initialize services (`CloudCacheService`, `CacheManager`, `DefaultModelController`)
3. Register dependencies with `AppDependencyManager`
4. Update App Shortcuts and configure TipKit
5. Startup flow:
   - Validate Apple ID authentication
   - Ensure location authorization
   - Retrieve Foursquare user
   - Load cached data with timeout (10s)
   - Refresh CloudKit cache
   - Enter main UI

## Navigation & Search Modes

Four primary search modes (enum `SearchMode`):
- **Favorites**: Saved places and preferences
- **Industries**: Category-based browsing
- **Tastes/Features**: Vibe-based exploration
- **Places**: Map-based discovery

Navigation state managed through `ContentView` with `NavigationSplitView` providing adaptive layouts.

## Important Files

- `Know_MapsApp.swift`: App entry point, dependency setup, startup flow
- `Model/Controllers/DefaultModelController.swift`: Central state management
- `Model/Controllers/AssistiveChatHostService.swift`: Natural language processing
- `Model/Controllers/CloudCacheManager.swift`: CloudKit sync orchestration
- `Model/Controllers/DefaultPlaceSearchService.swift`: Foursquare API integration
- `Model/Models/AssistiveChatHostIntent.swift`: Intent data structures
- `View/ContentView.swift`: Root navigation structure

## Testing Strategy

- Use mocks in `Know MapsTests/Mocks/` for isolating components
- `TestFixtures.swift` provides reusable test data
- Test `DefaultModelController` state transitions and data flow
- Test async operations with proper await patterns
