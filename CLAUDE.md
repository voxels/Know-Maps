# CLAUDE.md - Know Maps Development Guidelines

## Build Commands
- Open in Xcode: `open "Know-Maps/Know Maps.xcodeproj"`
- Build (iOS simulator): `xcodebuild -project "Know-Maps/Know Maps.xcodeproj" -scheme "knowmaps" -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Build (macOS): `xcodebuild -project "Know-Maps/Know Maps.xcodeproj" -scheme "knowmaps" -destination 'platform=macOS' build`
- Build (visionOS): `xcodebuild -project "Know-Maps/Know Maps.xcodeproj" -scheme "knowmaps" -destination 'platform=visionOS Simulator' build`

## Test Commands
- Run all tests: `xcodebuild test -project "Know-Maps/Know Maps.xcodeproj" -scheme "knowmapsTests" -destination 'platform=iOS Simulator,name=iPhone 15'`
- Run specific test class: `xcodebuild test -project "Know-Maps/Know Maps.xcodeproj" -scheme "knowmapsTests" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:knowmapsTests/DefaultModelControllerTests`

## Coding Style & Naming Conventions
- **Architecture**: Follow SwiftUI + MVVM. Views in `View/`, state/logic in `Model/ViewModels/`, coordination in `Model/Controllers/`.
- **Indentation**: 4 spaces.
- **Naming**: `UpperCamelCase` for types, `lowerCamelCase` for members. File names should match primary type (e.g., `PlaceAboutView.swift`).
- **Tests**: Located in `Know-Maps/knowmapsTests/` using Swift Testing (`import Testing`).
- **Concurrency**: Use `async/await`, `Task`, and `Actor` pattern. Use `@MainActor` for UI-bound types.
- **Data**: Uses SwiftData for persistence and CoreML for on-device machine learning.
