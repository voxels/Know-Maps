//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    var chatModel:ChatResultViewModel
    var cacheManager:CloudCacheManager
    var modelController:DefaultModelController
    var searchSavedViewModel:SearchSavedViewModel
    @Binding public var searchMode:SearchMode
    
    var body: some View {
        SavedListView(searchSavedViewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, section:$modelController.section, searchMode: $searchMode)
    }
}
