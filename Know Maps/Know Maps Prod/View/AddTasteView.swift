//
//  AddTasteView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddTasteView: View {
    @Binding public var viewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<UUID>
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @State private var multiSelectionArray: [UUID] = []

    var body: some View {
        List() {
            ForEach(multiSelectionArray, id:\.self) { identifier in
                if let tasteResult = modelController.tasteCategoryResult(for: identifier) {
                    VStack {
                        Text(tasteResult.parentCategory)
                            .font(.headline)
                    }.padding()
                    
                    
                    Button(action: {
                        Task(priority: .userInitiated) {
                            await viewModel.addTaste(parent: tasteResult.id, rating:0, cacheManager: cacheManager, modelController:   modelController)
                            multiSelection.remove(tasteResult.id)
                        }
                    }) {
                        Label("Recommend rarely", systemImage: "circle.slash")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task(priority: .userInitiated) {
                            await viewModel.addTaste(parent: tasteResult.id,rating:2, cacheManager: cacheManager, modelController:   modelController)
                            multiSelection.remove(tasteResult.id)
                        }
                    }) {
                        Label("Recommend occasionally", systemImage: "circle")
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        Task(priority: .userInitiated) {
                            await viewModel.addTaste(parent: tasteResult.id,rating:3, cacheManager: cacheManager, modelController:   modelController)
                            multiSelection.remove(tasteResult.id)
                        }
                    }) {
                        Label("Recommend often", systemImage: "circle.fill")
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .onAppear() {
            multiSelectionArray = Array(multiSelection)
        }
    }
}
