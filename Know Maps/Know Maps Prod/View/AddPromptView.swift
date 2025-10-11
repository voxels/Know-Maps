//
//  AddPromptView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddPromptView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    
    var body: some View {
        Text("Hello world")
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var section: Int
    @Binding public var multiSelection: Set<UUID>
    @Binding public var searchMode:SearchMode
    
    var body: some View {
        if searchMode == .places, let selectedPlaceChatResult = modelController.selectedPlaceChatResult,let placeChatResult = modelController.placeChatResult(for: selectedPlaceChatResult), !cacheManager.cachedPlaces(contains:placeChatResult.title){
            Button(action: {
                Task(priority:.userInitiated) {
                    await viewModel.addPlace(parent: selectedPlaceChatResult, rating: 3, cacheManager: cacheManager, modelController: modelController)
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(modelController.selectedPlaceChatResult == nil)
            .labelStyle(.titleAndIcon)
        }
        else if searchMode == .industries {
            Button(action: {
                Task(priority:.userInitiated) {
                    for parent in multiSelection {
                        await viewModel.addCategory(
                            parent: parent, rating:2,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    }
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        } else if searchMode == .features {
            Button(action: {
                Task(priority:.userInitiated) {
                    for parent in multiSelection {
                        await viewModel.addTaste(
                            parent: parent, rating:2,
                            cacheManager: cacheManager,
                            modelController: modelController
                        )
                    }
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        }
    }
}
