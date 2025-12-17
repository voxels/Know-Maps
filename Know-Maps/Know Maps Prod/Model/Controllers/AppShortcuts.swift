//
//  AppShortcuts.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//

import Foundation
import AppIntents
import SwiftUI

/*
struct KnowMapsShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: ShowMoodResultsIntent(),
                phrases: [
                    "I'm in the mood for \(.applicationName).",
                    "Ask \(.applicationName) to find a place for \(\.$mood).",
                    "Tell \(.applicationName), \"I'm' in the mood for \(\.$mood).\"",
                ],
                shortTitle: "Find a place for my mood",
                systemImageName: "magnifyingglass",
                parameterPresentation: ParameterPresentation(
                    for: \.$mood,
                    summary: Summary("Go to a place for \(\.$mood)"),
                    optionsCollections: {
                        OptionsCollection(PersonalizedSearchSectionOptionsProvider(), title: "Moods", systemImageName: "cloud.rainbow.half")
                    }
                )
            )
    }
}

struct ShowMoodResultsIntent: AppIntent { 
    static var title: LocalizedStringResource = "Find a story for my mood"
    
    @Parameter(title: "Mood", description: "The type of mood you're in right now.")
    var mood: PersonalizedSearchSection
    static var openAppWhenRun = true
    
    @Dependency var modelController: DefaultModelController
    @Dependency var cacheManager:CloudCacheManager
    @Dependency var chatModel: ChatResultViewModel
    @Dependency var resultIndexer: ResultIndexServiceV2 // Add this line

    @MainActor
    func perform() async throws -> some IntentResult {
        // 1. Jump UI focus to the main places/results surface.
        // Assumption: modelController.section == 0 is the "browse/search results" pane.
        withAnimation {
            modelController.section = 0
        }

        // 2. Derive the text we want to search for from the chosen mood.
        // PersonalizedSearchSection is a RawRepresentable (String), so we can use rawValue.
        // Example: "Date night", "Brunch", "Live music", etc.
        let moodQueryText = mood.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Build the same style of AssistiveChatHostIntent we use in SearchPlacesView.onSubmit,
        // but feed it the mood instead of manual search text.
        // We also pass through the user's currently selected destination so recs get biased
        // around that anchor location.
        let chatIntent = AssistiveChatHostIntent(
            caption: moodQueryText,
            intent: .Search,
            selectedPlaceSearchResponse: nil,
            selectedPlaceSearchDetails: nil,
            placeSearchResponses: [],
            selectedDestinationLocation: modelController.selectedDestinationLocationChatResult,
            placeDetailsResponses: nil,
            // queryParameters lets downstream know this was a mood-driven / personalized search.
            queryParameters: [
                "source": "AppShortcut.mood",
                "section": mood.rawValue
            ]
        )

        // 4. Actually trigger the pipeline. This will:
        // - call into modelController.searchIntent(...)
        // - which will run PersonalizedSearchSession.fetchRecommendedVenues(...)
        // - which will eventually fill modelController.recommendedPlaceResults /
        //   modelController.placeResults and update fetchMessage.
        do {
            try await modelController.searchIntent(intent: chatIntent)
        } catch {
            // We don't want to fail the Siri intent just because search failed,
            // but we DO want telemetry on that failure.
            modelController.analyticsManager.trackError(
                error: error,
                additionalInfo: [
                    "phase": "ShowMoodResultsIntent.perform",
                    "mood": mood.rawValue
                ]
            )
        }

        // 5. Tell App Shortcuts/Siri we're done. The app should now already be
        // showing the mood-personalized results list.
        return .result()
    }
}

*/
