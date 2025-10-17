//
//  AddTasteView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/12/24.
//
import SwiftUI

struct AddTasteView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @Binding public var viewModel: SearchSavedViewModel
    @Binding public var chatModel: ChatResultViewModel
    @Binding public var cacheManager: CloudCacheManager
    @Binding public var modelController: DefaultModelController
    @Binding public var multiSelection: Set<String>
    @State private var multiSelectionArray: [String] = []
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                ForEach(multiSelectionArray, id: \.self) { identifier in
                    if let tasteResult = modelController.tasteCategoryResult(for: identifier) {
                            VStack(spacing:16) {
                                Text(tasteResult.parentCategory)
                                    .font(.headline)
                                    .padding()
                                Button(action: {
                                    Task(priority: .userInitiated) {
                                        await viewModel.addTaste(parent: tasteResult.id, rating: 0, cacheManager: cacheManager, modelController: modelController)
                                        multiSelection.remove(tasteResult.id)
                                    }
                                }) {
                                    Label("Recommend rarely", systemImage: "star.slash")
                                        .labelStyle(.titleAndIcon)
                                }.padding(16)
                                Button(action: {
                                    Task(priority: .userInitiated) {
                                        await viewModel.addTaste(parent: tasteResult.id, rating: 2, cacheManager: cacheManager, modelController: modelController)
                                        multiSelection.remove(tasteResult.id)
                                    }
                                }) {
                                    Label("Recommend occasionally", systemImage: "star.leadinghalf.filled")
                                        .labelStyle(.titleAndIcon)
                                }.padding(16)
                                Button(action: {
                                    Task(priority: .userInitiated) {
                                        await viewModel.addTaste(parent: tasteResult.id, rating: 3, cacheManager: cacheManager, modelController: modelController)
                                        multiSelection.remove(tasteResult.id)
                                    }
                                }) {
                                    Label("Recommend often", systemImage: "star.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .padding(16)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .onChange(of: multiSelection, { oldValue, newValue in
                multiSelectionArray = Array(newValue)
            })
        }
    }
}
