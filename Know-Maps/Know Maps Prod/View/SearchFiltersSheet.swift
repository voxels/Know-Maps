import SwiftUI
import MapKit

public struct SearchFiltersSheet: View {
    @Binding var searchRadius: Double
    @Binding var locationQuery: String
    var modelController: DefaultModelController
    @Environment(\.dismiss) private var dismiss
    
    public init(searchRadius: Binding<Double>, locationQuery: Binding<String>, modelController: DefaultModelController) {
        self._searchRadius = searchRadius
        self._locationQuery = locationQuery
        self.modelController = modelController
    }
    
    // Local state for address autocomplete results if we wanted to get fancy,
    // but for now we'll stick to the existing logic which does the lookup on submit/apply.
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Distance") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Search Radius")
                            Spacer()
                            Text("\(Int(searchRadius)) km")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $searchRadius, in: 1...200, step: 1) {
                            Text("Radius")
                        } minimumValueLabel: {
                            Image(systemName: "circle.dotted")
                        } maximumValueLabel: {
                            Image(systemName: "circle")
                        }
                    }
                }
                
                Section("Search Center") {
                    HStack {
                        TextField("City, neighborhood, or place...", text: $locationQuery)
                            .submitLabel(.search)
                            .onSubmit {
                                updateSearchCenter()
                            }
                        
                        if !locationQuery.isEmpty {
                            Button {
                                locationQuery = ""
                                resetSearchCenter()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button {
                        updateSearchCenter()
                    } label: {
                        Text("Update Search Center")
                    }
                    .disabled(locationQuery.isEmpty)
                    
                    Button(role: .destructive) {
                        resetSearchCenter()
                    } label: {
                        Text("Reset to Current Location")
                    }
                }
                
                Section {
                    Text("Adjusting the radius will visually update the map search area.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateSearchCenter() {
        Task {
            do {
                if let placemark = try await modelController.locationService.lookUpLocationName(name: locationQuery).first,
                   let location = placemark.location {
                    await MainActor.run {
                        modelController.selectedDestinationLocationChatResult = LocationResult(
                            locationName: placemark.name ?? locationQuery,
                            location: location,
                            formattedAddress: placemark.locality
                        )
                    }
                }
            } catch {
                print("Location lookup failed: \(error)")
            }
        }
    }
    
    private func resetSearchCenter() {
        locationQuery = ""
        modelController.selectedDestinationLocationChatResult = LocationResult(
            locationName: "Current Location",
            location: modelController.locationService.currentLocation()
        )
    }
}
