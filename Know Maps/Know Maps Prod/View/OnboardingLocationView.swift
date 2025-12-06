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
    var modelController:DefaultModelController
    @Binding public var showOnboarding:Bool
    @Binding public var locationIsAuthorized:Bool
    @State private var alertPopverIsPresented:Bool = false
    
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            VStack(spacing: 6) {
                Text("Location Authorization")
                    .bold()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Text("2. Know Maps uses your current location to suggest places to go near you.")
                    .multilineTextAlignment(.leading)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            Button("Continue") {
                Task {
                    modelController.locationService.locationProvider.authorize()
                    modelController.setSelectedLocation(nil)
                    if modelController.locationService.locationProvider.isAuthorized() {
                        showOnboarding = false
                    } else {
                        // If not authorized, show guidance popover
                        alertPopverIsPresented = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .popover(isPresented: $alertPopverIsPresented) {
                VStack(spacing: 12) {
                    Text("Please open the location settings system preferences to allow Know Maps to find your location.")
                        .multilineTextAlignment(.leading)
                    Button("Open System Preferences") {
                        openLocationPreferences()
                    }
                }
                .padding()
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .onAppear {
            locationIsAuthorized = modelController.locationService.locationProvider.isAuthorized()
        }
    }
    
    // Opens the system location settings for the current platform
    private func openLocationPreferences() {
        #if os(macOS)
        // Attempt to open Location Services in System Settings on macOS
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
        #else
        // On iOS/iPadOS, navigate to the app's settings page
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }
}
