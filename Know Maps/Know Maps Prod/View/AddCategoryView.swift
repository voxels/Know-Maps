//
//  AddCategoryView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//

import SwiftUI

struct AddCategoryView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    public var viewModel:SearchSavedViewModel
    public var chatModel:ChatResultViewModel
    public var cacheManager:CloudCacheManager
    public var modelController:DefaultModelController
    @Binding public var multiSelection: Set<String>
    @State private var multiSelectionArray: [String] = []
    
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(spacing:16) {
                    ForEach(multiSelectionArray, id:\.self) { identifier in
                        if let industryResult = modelController.industryCategoryResult(for: identifier) {
                            VStack(spacing:16) {
                                Group {
                                    Text(industryResult.parentCategory)
                                        .font(.headline)
                                        .padding()
                                    Button(action: {
                                        Task(priority: .userInitiated) {
                                            await viewModel.addCategory(parent: industryResult.id, rating:0, cacheManager: cacheManager, modelController:   modelController)
                                        }
                                    }) {
                                        Label("Rarely", systemImage: "circle.slash")
                                    }.padding(16)
                                    
                                    Button(action: {
                                        Task(priority: .userInitiated) {
                                            await viewModel.addCategory(parent: industryResult.id,rating:2, cacheManager: cacheManager, modelController:   modelController)
                                        }
                                    }) {
                                        Label("Occasionally", systemImage: "circle")
                                    }.padding(16)
                                    
                                    Button(action: {
                                        Task(priority: .userInitiated) {
                                            await viewModel.addCategory(parent: industryResult.id,rating:3, cacheManager: cacheManager, modelController:   modelController)
                                            
                                        }
                                    }) {
                                        Label("Often", systemImage: "circle.fill")
                                    }.padding(16)
                                }
                            }
                       }
                    }
                }
                .onChange(of: multiSelection, { oldValue, newValue in
                    multiSelectionArray = Array(newValue)
                })
            }
        }
    }
}
