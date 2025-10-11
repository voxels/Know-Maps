//
//  AppShortcuts.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/10/24.
//

import Foundation
import AppIntents
import SwiftUI

struct KnowMapsShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
            AppShortcut(
                intent: ShowMoodResultsIntent(),
                phrases: [
                    "I'm in the mood for food from \(.applicationName).",
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
    
    @Parameter(title: "Mood", description: "The type of mood you're looking for.")
    var mood: PersonalizedSearchSection
    static var openAppWhenRun = true
    
    @Dependency var modelController: DefaultModelController
    @Dependency var cacheManager:CloudCacheManager
    @Dependency var chatModel: ChatResultViewModel

    @MainActor
    func perform() async throws -> some IntentResult{
        withAnimation {
            modelController.section = 0
            modelController.selectedPlaceChatResult = nil
        }

        try await modelController.resetPlaceModel()

        withAnimation {
            modelController.selectedSavedResult = cacheManager.cachedDefaultResults.first(where: { $0.section == mood })?.id
        }

        if let savedResult = modelController.selectedSavedResult, let chatResult = modelController.cachedChatResult(for:savedResult, cacheManager: cacheManager) {
            await chatModel.didTap(chatResult:chatResult, selectedDestinationChatResultID: modelController.selectedDestinationLocationChatResult ?? modelController.currentlySelectedLocationResult.id, filters: [:], cacheManager: cacheManager, modelController: modelController)
        }
        
        
        // Provide feedback to the user
        return .result()
    }
}
