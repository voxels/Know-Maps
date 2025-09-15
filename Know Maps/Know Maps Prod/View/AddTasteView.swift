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
    @Binding public var multiSelection: Set<UUID>
    @Binding public var preferredColumn: NavigationSplitViewColumn
    @State private var multiSelectionArray: [UUID] = []
    
    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(multiSelectionArray, id: \.self) { identifier in
                    if let tasteResult = modelController.tasteCategoryResult(for: identifier) {
                        VStack(alignment: .leading) {
                            Text(tasteResult.parentCategory)
                                .font(.headline)
                            
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addTaste(parent: tasteResult.id, rating: 0, cacheManager: cacheManager, modelController: modelController)
                                    multiSelection.remove(tasteResult.id)
                                }
                            }) {
                                Label("Recommend rarely", systemImage: "circle.slash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addTaste(parent: tasteResult.id, rating: 2, cacheManager: cacheManager, modelController: modelController)
                                    multiSelection.remove(tasteResult.id)
                                }
                            }) {
                                Label("Recommend occasionally", systemImage: "circle")
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            
                            Button(action: {
                                Task(priority: .userInitiated) {
                                    await viewModel.addTaste(parent: tasteResult.id, rating: 3, cacheManager: cacheManager, modelController: modelController)
                                    multiSelection.remove(tasteResult.id)
                                }
                            }) {
                                Label("Recommend often", systemImage: "circle.fill")
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

            .frame(idealHeight:geometry.size.height / 3)
            .onChange(of: multiSelection, { oldValue, newValue in
                multiSelectionArray = Array(newValue)
            })
        }
    }
}
