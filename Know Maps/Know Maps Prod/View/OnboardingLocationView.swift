//
//  OnboardingLocationView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 2/6/24.
//

import SwiftUI

struct OnboardingLocationView: View {
    @ObservedObject public var locationProvider:LocationProvider
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
            Spacer()
        }
    }
}

#Preview {
    let locationProvider = LocationProvider()
    return OnboardingLocationView(locationProvider: locationProvider, selectedTab: .constant(2))
}
