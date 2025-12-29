# Model Interfaces Documentation for Know Maps

*This document is intended to be copied into Google Docs.*

---

## Table of Contents
1. [Model Objects](#model-objects)
2. [Protocols](#protocols)
3. [Architecture Overview](#architecture-overview)

---

## Model Objects {#model-objects}

The **Model** layer lives under `Model/Models` and defines the data structures used throughout the app. Below is a brief description of each struct/class and its role in the overall design.

| File | Type | Description |
|------|------|-------------|
| `AssistiveChatHostIntent.swift` | `class AssistiveChatHostIntent` | Represents a user intent for the Assistive Chat Host. Holds caption, intent enum, selected place/search results, destination location, and optional query parameters. Used by the `ModelController` to drive chat flows.
| `AssistiveChatHostQueryParameters.swift` | `struct AssistiveChatHostQueryParameters` | Encapsulates parameters for a chat query (e.g., filters, location). Stored in `queryParametersHistory` for analytics and repeat queries.
| `CategoryResult.swift` | `struct CategoryResult` | Represents a category (industry or taste) returned from the recommender service. Contains an ID, title, and associated metadata.
| `ChatResult.swift` | `struct ChatResult` | Core representation of a chat message/result, including place information, categories, and UI state flags.
| `ChatRouteResult.swift` | `struct ChatRouteResult` | Holds routing information for a chat flow (e.g., next intent, navigation target).
| `ConfiguredSearchSession.swift` | `struct ConfiguredSearchSession` | Stores configuration for a search session, such as selected filters and pagination state.
| `LanguageGeneratorRequest.swift` | `struct LanguageGeneratorRequest` | Payload sent to the language generation service to produce natural‑language responses.
| `LocationResult.swift` | `struct LocationResult` | Represents a geographic location with latitude/longitude, name, and optional address details. Used by map‑related features.
| `PersonalizedSearchSection.swift` | `struct PersonalizedSearchSection` | Defines a personalized search section (e.g., "Nearby", "Favorites") used to group results.
| `PlaceDetailsRequest.swift` | `struct PlaceDetailsRequest` | Request model for fetching detailed information about a place from the backend.
| `PlaceDetailsResponse.swift` | `struct PlaceDetailsResponse` | Response model containing full place details (photos, hours, ratings, etc.).
| `PlacePhotoResponse.swift` | `struct PlacePhotoResponse` | Holds image data or URL for a place photo.
| `PlaceResponseFormatter.swift` | `class PlaceResponseFormatter` | Utility that formats raw API responses into the app's `PlaceSearchResponse` model.
| `PlaceSearchRequest.swift` | `struct PlaceSearchRequest` | Request payload for a place search (query string, location bias, filters).
| `PlaceSearchResponse.swift` | `struct PlaceSearchResponse` | Primary data model for a place search result. Includes ID, name, categories, coordinates, address, and related IDs. Now also used for recommendations (via relevance sorting) and includes optional `tastes`.
| `PlaceTipsResponse.swift` | `struct PlaceTipsResponse` | Represents tips or recommendations attached to a place.
| `RecommendationData.swift` | `struct RecommendationData` | Stores recommendation metadata used by the recommender service.
| `RecommendedPlaceSearchRequest.swift` | `struct RecommendedPlaceSearchRequest` | Request model for fetching recommended places based on user context.
| `UserCachedRecord.swift` | `struct UserCachedRecord` | Simple cache entry for user‑specific data (e.g., recent searches, favorites).

---

## Protocols {#protocols}

Protocols define the contracts that concrete controllers and services must fulfill. They live under `Model/Protocols`.

| File | Protocol | Purpose |
|------|----------|---------|
| `AnalyticsService.swift` | `AnalyticsService` | Provides methods for logging events and user interactions.
| `AssistiveChatHost.swift` | `AssistiveChatHost` | Core delegate for the Assistive Chat Host UI.
| `AssistiveChatHostMessagesDelegate.swift` | `AssistiveChatHostMessagesDelegate` | Handles incoming/outgoing chat messages.
| `AssistiveChatHostStreamResponseDelegate.swift` | `AssistiveChatHostStreamResponseDelegate` | Receives streaming responses from the language model.
| `Authentication.swift` | `Authentication` | Abstracts authentication flows (Apple, custom).
| `CacheManager.swift` | `CacheManager` | Manages in‑memory and persistent caching of model objects.
| `CloudCache.swift` | `CloudCache` | Interface for remote cache synchronization (e.g., Supabase).
| `FeatureFlag.swift` | `FeatureFlag` | Toggles experimental features at runtime.
| `LanguageGenerator.swift` | `LanguageGenerator` | Generates natural language text from `LanguageGeneratorRequest`.
| `LocationService.swift` | `LocationService` | Provides current location and geocoding utilities.
| `ModelController.swift` | `ModelController` | **Central hub** – aggregates all domain services (search, analytics, cache, recommender, etc.) and publishes UI‑state properties used by SwiftUI views.
| `PlaceSearchService.swift` | `PlaceSearchService` | Executes place search queries and returns `PlaceSearchResponse` arrays.
| `RecommenderService.swift` | `RecommenderService` | Produces personalized recommendations based on user context and history.

---

## Architecture Overview {#architecture-overview}

The following **Mermaid** diagram visualises the high‑level architecture of the Model layer and its interactions with the rest of the app.

```mermaid
flowchart TD
    subgraph UI[SwiftUI Views]
        ViewA[MainView]
        ViewB[ChatView]
        ViewC[MapView]
    end

    subgraph ModelLayer[Model Layer]
        MC[ModelController (protocol)]
        subgraph Services
            AS[AssistiveChatHost]
            LS[LocationService]
            PSS[PlaceSearchService]
            RS[RecommenderService]
            CS[CacheManager]
            ASvc[AnalyticsService]
        end
        subgraph DataModels
            Intent[AssistiveChatHostIntent]
            Place[PlaceSearchResponse]
            Chat[ChatResult]
            Location[LocationResult]
        end
    end

    ViewA -->|binds| MC
    ViewB -->|binds| MC
    ViewC -->|binds| MC
    MC -->|uses| AS
    MC -->|uses| LS
    MC -->|uses| PSS
    MC -->|uses| RS
    MC -->|uses| CS
    MC -->|uses| ASvc
    AS -->|produces| Intent
    PSS -->|returns| Place
    RS -->|returns| Chat
    LS -->|provides| Location
    CS -->|caches| Intent & Place & Chat & Location
```

*The diagram shows:* 
- **UI** layers bind to the central `ModelController`.
- `ModelController` orchestrates **services** (search, recommendation, location, analytics, cache).
- Data flows from services into **data model structs** (`Intent`, `PlaceSearchResponse`, `ChatResult`, `LocationResult`).
- The cache layer stores and retrieves these objects to minimise network calls.

---

## How to Use the Interfaces

1. **Instantiate a concrete `ModelController`** (e.g., `DefaultModelController`).
2. Access published properties (e.g., `selectedPlaceChatResultFsqId`, `placeResults`) from SwiftUI views using `@StateObject` or `@ObservedObject`.
3. Call service methods via the controller, such as:
   ```swift
   await modelController.placeSearchService.search(request: PlaceSearchRequest(query: "coffee", location: currentLocation))
   ```
4. Listen for updates through the `@Published` properties on the controller – the UI will automatically refresh.
5. Use the `CacheManager` to persist results across app launches:
   ```swift
   try await modelController.cacheManager.save(key: "lastSearch", value: results)
   ```

---

*End of document.*
