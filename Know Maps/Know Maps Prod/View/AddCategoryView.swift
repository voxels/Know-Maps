//
//  AddCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddCategoryView: View {
    @Binding public var viewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var multiSelection: Set<UUID>
    @State private var multiSelectionArray: [UUID] = []

    
    var body: some View {
        List() {
            ForEach(multiSelectionArray, id:\.self) { identifier in
                if let industryResult = modelController.industryCategoryResult(for: identifier) {
                    VStack {
                        Text(industryResult.parentCategory)
                            .font(.headline)
                            .padding()
                        
                        Button(action: {
                            Task(priority: .userInitiated) {
                                await viewModel.addCategory(parent: industryResult.id, rating:0, cacheManager: cacheManager, modelController:   modelController)
                                multiSelection.remove(industryResult.id)
                            }
                        }) {
                            Label("Recommend rarely", systemImage: "circle.slash")
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: {
                            Task(priority: .userInitiated) {
                                await viewModel.addCategory(parent: industryResult.id,rating:2, cacheManager: cacheManager, modelController:   modelController)
                                multiSelection.remove(industryResult.id)
                            }
                        }) {
                            Label("Recommend occasionally", systemImage: "circle")
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }.buttonStyle(.borderless)

                        
                        Button(action: {
                            Task(priority: .userInitiated) {
                                await viewModel.addCategory(parent: industryResult.id,rating:3, cacheManager: cacheManager, modelController:   modelController)
                                
                                multiSelection.remove(industryResult.id)
                            }
                        }) {
                            Label("Recommend often", systemImage: "circle.fill")
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .onChange(of: multiSelection, { oldValue, newValue in
            multiSelectionArray = Array(newValue)
        })
    }
}
