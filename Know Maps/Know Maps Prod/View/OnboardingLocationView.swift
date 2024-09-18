//
//  OnboardingLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif


struct OnboardingLocationView: View {
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var isAuthorized:Bool
    @Binding public var selectedTab:Int
    var body: some View {
        VStack{
            Spacer()
            Text("Location Authorization").bold().padding()
            Image(systemName: "map.circle")
                .resizable()
                .scaledToFit()
                .frame(width:100 , height: 100)
            Text("Know Maps uses your current location to suggest places nearby.")
                .multilineTextAlignment(.leading)
                .padding()
            Button("Authorize Location Tracking") {
                locationProvider.authorize()
                selectedTab = 3
            }.padding()
                .alert("Location Settings", isPresented: $isAuthorized, actions:                 {
                    Button("Open System Preferences") {
                        openLocationPreferences()
                    }
                }, message: {
                    Text("Please open the location settings system preferences to allow Know Maps to access your location.")
                })
            Spacer()
        }
    }
    
#if os(macOS)
public func openLocationPreferences() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
        NSWorkspace.shared.open(url)
    }
}
#endif
}

#Preview {
    let locationProvider = LocationProvider()
    OnboardingLocationView(locationProvider: locationProvider, isAuthorized: .constant(false), selectedTab: .constant(2))
}
