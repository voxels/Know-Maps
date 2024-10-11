import SwiftUI
import CoreLocation
import MapKit
import CallKit

struct PlaceAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) var sizeClass
    @Binding public var chatModel:ChatResultViewModel
    @Binding public var cacheManager:CloudCacheManager
    @Binding public var modelController:DefaultModelController
    @Binding  var tabItem: Int
    @State var mutableTastes: [String] = []
    @State private var presentingPopover: Bool = false
    @State private var isPresentingShareSheet:Bool = false
    static let defaultPadding: CGFloat = 8
    static let mapFrameConstraint: Double = 50000
    static let buttonHeight: Double = 44
    
    var viewModel: PlaceAboutViewModel = .init()
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    if let resultId = modelController.selectedPlaceChatResult, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        
                        // Title and Map
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        let title = placeResponse.name
                        
                        Text(title)
                            .font(.headline)
                            .padding()
                        
                        Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000), interactionModes: [.zoom, .rotate]) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                        }
                        .mapStyle(.hybrid)
                        .frame(minHeight: geo.size.height / 2.0)
                        .cornerRadius(16)
                        .padding()
                        
                        // Address and Categories
                        ZStack(alignment: .leading) {
                            VStack {
                                Text(placeResponse.categories.joined(separator: ", ")).italic()
                                    .padding(PlaceAboutView.defaultPadding)
                                
                                Label(placeResponse.formattedAddress, systemImage: "mappin")
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .labelStyle(.titleOnly)
                                    .onTapGesture {
                                        tabItem = 1
                                    }
                            }
                        }
                        .padding()
                        
                        // Action buttons
                        HStack {
                            Spacer()
                            // Save/Unsave button
                            ZStack {
                                Capsule()
                                    .foregroundStyle(.accent)
                                    .frame(height: PlaceAboutView.buttonHeight)
                                let isSaved = cacheManager.cachedPlaces(contains: title)
                                Label(isSaved ? "Delete" : "Add to List", systemImage: isSaved ? "minus.circle" : "square.and.arrow.down")
                                    
                            }.onTapGesture {
                                Task(priority:.userInitiated) {
                                    await viewModel.toggleSavePlace(resultId: resultId, cacheManager: cacheManager, modelController:modelController)
                                }
                            }
                            
                            // Phone button
                            if let tel = placeDetailsResponse.tel {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Label(tel, systemImage: "phone")
                                        
                                }.onTapGesture {
                                    if let url = viewModel.getCallURL(tel: tel) {
                                        openURL(url)
                                    }
                                }
                            }
                            
                            // Website button
                            if let website = placeDetailsResponse.website, let url = viewModel.getWebsiteURL(website: website) {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Label("Visit website", systemImage: "link")
                                        
                                }.onTapGesture {
                                    openURL(url)
                                }
                            }
                            Spacer()
                        }.padding(.horizontal, 16)
                        HStack{
                            Spacer()
                            // Rating button
                            if placeDetailsResponse.rating > 0 {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Label(PlacesList.formatter.string(from: NSNumber(value: placeDetailsResponse.rating)) ?? "0", systemImage: "star.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .onTapGesture {
                                    tabItem = 3
                                }
                                .padding(PlaceAboutView.defaultPadding)
                            }
                        
                            
                            // Price button
                            if let price = placeDetailsResponse.price {
                                ZStack {
                                    Capsule()
                                        .foregroundStyle(.accent)
                                        .frame(height: PlaceAboutView.buttonHeight)
                                    
                                    Text(priceToString(price: price))
                                }
                                .padding(PlaceAboutView.defaultPadding)
                            }
                            #if os(iOS) || os(visionOS)
                            // Share button
                            ZStack {
                                Capsule()
                                    .foregroundStyle(.accent)
                                    .frame(height: PlaceAboutView.buttonHeight)
                                
                                Image(systemName: "square.and.arrow.up")
                            }
                            .padding(PlaceAboutView.defaultPadding)
                            .onTapGesture {
                                presentingPopover.toggle()
                            }
                            .sheet(isPresented:$presentingPopover) {
                                if let result = modelController.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                                    let items:[Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
                                    ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)
                                        .presentationCompactAdaptation(.popover)
                                }
                            }
                            #endif
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        // Tastes Section
                        if let tastes = placeDetailsResponse.tastes, !tastes.isEmpty {
                            Section {
                                let gridItems = Array(repeating: GridItem(.flexible(), spacing: PlaceAboutView.defaultPadding), count: sizeClass == .compact ? 2 : 3)
                                
                                LazyVGrid(columns: gridItems, alignment: .leading, spacing: 8) {
                                    ForEach($mutableTastes, id: \.self) { taste in
                                        let isSaved = cacheManager.cachedTastes(contains: taste.wrappedValue)
                                        HStack {
                                            Label("Save", systemImage: isSaved ? "minus.circle" : "square.and.arrow.down")
                                                .labelStyle(.iconOnly)
                                                .padding(PlaceAboutView.defaultPadding)
                                                
                                            Text(taste.wrappedValue)
                                            Spacer()
                                        }.onTapGesture {
                                            if isSaved {
                                                if let cachedTasteResult = modelController.cachedTasteResult(title: taste.wrappedValue, cacheManager: cacheManager) {
                                                    Task(priority:.userInitiated) {
                                                        await viewModel.removeTaste(parent: cachedTasteResult, cacheManager:cacheManager, modelController: modelController)
                                                    }
                                                }
                                            } else {
                                                Task(priority:.userInitiated) {
                                                    await viewModel.addTaste(title: taste.wrappedValue, cacheManager: cacheManager, modelController:modelController)
                                                }
                                            }
                                        }
                                    }
                                }
                            }.padding(.horizontal, 16)
                                .task {
                                    if let tastes = placeDetailsResponse.tastes {
                                        mutableTastes = tastes
                                    }
                                }
                        }
                        
                        // Related Places Section
                        if !modelController.relatedPlaceResults.isEmpty {
                            Section("Related Places") {
                                ScrollView(.horizontal) {
                                    HStack {
                                        ForEach(modelController.relatedPlaceResults) { relatedPlace in
                                            VStack {
                                                Text(relatedPlace.title).bold().padding(8)
                                                if let neighborhood = relatedPlace.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                    Text(neighborhood).italic()
                                                } else if let locality = relatedPlace.placeResponse?.locality {
                                                    Text(locality).italic()
                                                }
                                            }
                                            .padding(PlaceAboutView.defaultPadding)
                                            .background(RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder())
                                        }
                                    }
                                }.padding(.horizontal, 16)
                            }.padding(.vertical, 16)
                        }
                    } else {
                        // Loading view
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    // Helper to convert price into a string
    func priceToString(price: Int) -> String {
        switch price {
        case 1:
            return "$"
        case 2:
            return "$$"
        case 3:
            return "$$$"
        case 4:
            return "$$$$"
        default:
            return "\(price)"
        }
    }
}
