# Repository Guidelines

## Project Structure & Module Organization

- `Know-Maps/Know Maps.xcodeproj`: Xcode project (iOS, macOS, visionOS targets).
- `Know-Maps/Know Maps Prod/`: main app source.
  - `View/`: SwiftUI views (UI layer).
  - `Model/`: app logic (controllers, services, view models, networking, ML assets).
  - `Assets.xcassets/` and `Preview Content/`: images, icons, preview assets.
- `Know-Maps/knowmaps/`: shared module + DocC (`Know-Maps/knowmaps/knowmaps.docc`).
- `Know-Maps/knowmapsTests/`: test target(s).

## Build, Test, and Development Commands

Run from `Know-Maps/` (paths contain spaces; keep quotes):

- Open in Xcode: `open "Know Maps.xcodeproj"`
- Build (iOS simulator example):  
  `xcodebuild -project "Know Maps.xcodeproj" -scheme "Know Maps" -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Test (iOS simulator example):  
  `xcodebuild test -project "Know Maps.xcodeproj" -scheme "Know MapsTests" -destination 'platform=iOS Simulator,name=iPhone 15'`

If you’re unsure about schemes/destinations, open the project in Xcode and use Product → Build/Test.

## Coding Style & Naming Conventions

- Follow existing SwiftUI + MVVM layering: Views in `View/`, state/logic in `Model/ViewModels/`, coordination in `Model/Controllers/`.
- Indentation: 4 spaces; keep formatting consistent with surrounding files.
- Naming: `UpperCamelCase` for types, `lowerCamelCase` for members; keep file names aligned with primary type (e.g., `PlaceAboutView.swift`).

## Testing Guidelines

- Tests live in `Know-Maps/knowmapsTests/` and currently use Swift Testing (`import Testing`).
- Prefer small, deterministic tests; name test functions for behavior (e.g., `testRefreshModelSanitizesQuery`).

## Commit & Pull Request Guidelines

- Commit messages are mixed; prefer a short imperative summary. Conventional-commit style is welcome when applicable (e.g., `fix(xcode): configure test targets`).
- PRs should include: a clear description, linked issues (if any), and screenshots/screen recordings for UI changes (iOS/macOS/visionOS as relevant).
- Avoid committing secrets or generated artifacts (API keys, local caches, `.DS_Store`).

## Configuration & Security Notes

- App requires CloudKit + Sign in with Apple and an external Places provider key (see `README.md` prerequisites).
- Keep credentials out of source control; document setup steps in the PR when configuration changes.
