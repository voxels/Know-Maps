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
    @Binding public var chatModel:ChatResultViewModel
    @Binding var modelController:DefaultModelController
    @Binding  public var showOnboarding:Bool
    @Binding  public var selectedTab:String
    @State private var isAuthorized:Bool = false

    var body: some View {
        VStack{
            Spacer()
            Text("Location Authorization").bold().padding()
            Image("logo_macOS_512")
                .resizable()
                .scaledToFit()
                .frame(width:100 , height: 100)
            Text("Know Maps uses your current location to suggest places nearby.")
                .multilineTextAlignment(.leading)
                .padding()
            Button("Authorize Location Tracking") {
                modelController.locationProvider.authorize()
                showOnboarding = false
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
#else
func openLocationPreferences() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
#endif
}
