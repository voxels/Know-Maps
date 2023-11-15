//
//  MapResultsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct MapResultsView: View {
    var body: some View {
        Map {

            }
            .mapControls {
                MapPitchToggle()
                MapUserLocationButton()
                MapCompass()
              }
            .mapStyle(.hybrid(elevation: .realistic,
                               pointsOfInterest: .including([.publicTransport]),
                               showsTraffic: true))
    }
}

#Preview {
    MapResultsView()
}
