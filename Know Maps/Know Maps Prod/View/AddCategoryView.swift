//
//  AddCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddCategoryView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @Binding public var viewModel:SearchSavedViewModel
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @Binding public var multiSelection: Set<UUID>
    @State private var multiSelectionArray: [UUID] = []
    
    
    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(multiSelectionArray, id:\.self) { identifier in
                    if let industryResult = modelController.industryCategoryResult(for: identifier) {
                        VStack(alignment:.leading) {
                            Text(industryResult.parentCategory)
                                .font(.headline)
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addCategory(parent: industryResult.id, rating:0, cacheManager: cacheManager, modelController:   modelController)
                                    multiSelection.remove(industryResult.id)
                                }
                            }) {
                                Label("Rarely", systemImage: "circle.slash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addCategory(parent: industryResult.id,rating:2, cacheManager: cacheManager, modelController:   modelController)
                                    multiSelection.remove(industryResult.id)
                                }
                            }) {
                                Label("Occasionally", systemImage: "circle")
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            
                            
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addCategory(parent: industryResult.id,rating:3, cacheManager: cacheManager, modelController:   modelController)
                                    
                                    multiSelection.remove(industryResult.id)
                                }
                            }) {
                                Label("Often", systemImage: "circle.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }                    
                }
            }
            #if !os(macOS)
            .listStyle(.insetGrouped)
            #endif
        }
        .onChange(of: multiSelection, { oldValue, newValue in
            multiSelectionArray = Array(newValue)
        })
        
    }
}

