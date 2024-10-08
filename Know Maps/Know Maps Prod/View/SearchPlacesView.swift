//
//  SearchPlacesView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/22/24.
//


import SwiftUI

struct SearchPlacesView: View {
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var cacheManager:CloudCacheManager
    @ObservedObject public var modelController:DefaultModelController
    var body: some View {
        Text("Hello world")
    }
}
