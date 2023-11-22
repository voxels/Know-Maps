//
//  Know_MapsApp.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/14/23.
//

import SwiftUI

@main
struct Know_MapsApp: App {
    private var locationProvider = LocationProvider()
    
    var body: some Scene {
        WindowGroup {
            ContentView(chatModel: ChatResultViewModel(locationProvider: locationProvider), locationProvider: locationProvider)
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
