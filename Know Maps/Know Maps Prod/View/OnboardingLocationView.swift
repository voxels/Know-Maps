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
    @ObservedObject public var settingsModel:AppleAuthenticationService
    @Binding public var chatModel:ChatResultViewModel
    @Binding var modelController:DefaultModelController
    @Binding public var showOnboarding:Bool
    @Binding public var locationIsAuthorized:Bool
    @State private var alertPopverIsPresented:Bool = false
    
    
    var body: some View {
        VStack{
            Spacer()
            Text("Location Authorization").bold().padding()
            Text("2. Know Maps uses your current location to suggest places to go near you.")
                .multilineTextAlignment(.leading)
                .padding()
            Button("Continue") {
                Task {
                    modelController.locationProvider.authorize()
                    await MainActor.run {
                        Task {
                            try? await setCurrentLocationAsDestination()
                        }
                        showOnboarding = false
                    }
                }
            }
            .popover(isPresented: $alertPopverIsPresented) {
                VStack {
                    Text("Please open the location settings system preferences to allow Know Maps to find your location.")
                    Button("Open System Preferences") {
                        openLocationPreferences()
                    }
                }.padding()
            }
            .padding()
            Spacer()
        }
        .onAppear {
            locationIsAuthorized = modelController.locationProvider.isAuthorized()
        }
        
    }
    
    // Helper method to set current location as destination
    private func setCurrentLocationAsDestination() async throws {
        // Ensure we have a valid current location
        if modelController.currentlySelectedLocationResult.location == nil {
            // Try to get current location if not available
            let currentLocation = modelController.locationService.currentLocation()
            let name = try await modelController.locationService.currentLocationName()
            modelController.currentlySelectedLocationResult = LocationResult(
                locationName: name ?? "Current Location",
                location: currentLocation
            )
        }
        
        // Set the selected destination to current location
        await MainActor.run {
            modelController.selectedDestinationLocationChatResult = modelController.currentlySelectedLocationResult.id
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
