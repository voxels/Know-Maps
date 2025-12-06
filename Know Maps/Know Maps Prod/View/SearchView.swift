//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
struct SearchView: View {
     var chatModel:ChatResultViewModel // Not used directly
     var cacheManager:CloudCacheManager // Not used directly
    var modelController:DefaultModelController
    var searchSavedViewModel:SearchSavedViewModel
    @Binding public var searchMode:SearchMode
    
    var body: some View {
        SavedListView(searchSavedViewModel: searchSavedViewModel, cacheManager: cacheManager, modelController: modelController, section: .constant(modelController.section), searchMode: $searchMode)
    }
}
