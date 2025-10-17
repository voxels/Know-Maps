//
//  SearchView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI

struct SearchView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding public var searchSavedViewModel:SearchSavedViewModel
    @Binding public var searchMode:SearchMode
    @Binding public var columnVisibility: NavigationSplitViewVisibility
    @Binding public var preferredCompactColumn: NavigationSplitViewColumn
    
    var body: some View {
        SavedListView(searchSavedViewModel: $searchSavedViewModel, cacheManager: $cacheManager, modelController: $modelController, section:$modelController.section, searchMode: $searchMode, columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn)
    }
}

