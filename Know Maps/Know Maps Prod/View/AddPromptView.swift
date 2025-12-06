 //
//  AddPromptView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI
struct AddPromptView: View {
    public var chatModel: ChatResultViewModel
    public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<String>
    
    var body: some View {
        Text("Hello world")
    }
}

struct AddPromptToolbarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    public var viewModel: SearchSavedViewModel
    public var chatModel:ChatResultViewModel
    var cacheManager: CloudCacheManager
    public var modelController: DefaultModelController
    @Binding public var section: Int
    @Binding public var multiSelection: Set<String>
    @Binding public var searchMode:SearchMode
    
    var body: some View {
        if searchMode == .places, let selectedPlaceChatResult = modelController.selectedPlaceChatResultFsqId,let placeChatResult = modelController.placeChatResult(with: selectedPlaceChatResult), !cacheManager.cachedPlaces(contains:placeChatResult.title){
            Button(action: {
                Task(priority:.userInitiated) {
                    await viewModel.addPlace(parent: selectedPlaceChatResult, rating: 3, cacheManager: cacheManager, modelController: modelController)
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(modelController.selectedPlaceChatResultFsqId == nil)
            .labelStyle(.titleAndIcon)
        }
        else if searchMode == .industries {
            Button(action: {
                Task(priority:.userInitiated) {
                    // Perform a single batched operation
                    await viewModel.addCategories(
                        parents: Array(multiSelection), rating: 2,
                        cacheManager: cacheManager, modelController: modelController
                    )
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        } else if searchMode == .features {
            Button(action: {
                Task(priority:.userInitiated) {
                    // Perform a single batched operation
                    await viewModel.addTastes(
                        parents: Array(multiSelection), rating: 2,
                        cacheManager: cacheManager, modelController: modelController
                    )
                }
            }) {
                Label("Save", systemImage: "plus.circle")
            }
            .disabled(multiSelection.count == 0)
            .labelStyle(.titleAndIcon)
        }
    }
}
