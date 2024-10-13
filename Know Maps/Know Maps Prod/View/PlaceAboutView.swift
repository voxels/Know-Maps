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
    
    @Namespace var topID
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        if let resultId = modelController.selectedPlaceChatResult, let result = modelController.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                            
                            // Title and Map
                            let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                            let title = placeResponse.name
                            
                            
                            Text(title)
                                .font(.title)
                                .padding()
                                .id(topID)
                            
                            if let aspectRatio = result.placeDetailsResponse?.photoResponses?.first?.aspectRatio, let url = result.placeDetailsResponse?.photoResponses?.first?.photoUrl() {
                                if modelController.isRefreshingPlaces {
                                    Image(systemName: "photo").aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                        .scaledToFit()
                                        .cornerRadius(16)
                                        .frame(width: geo.size.width - 32, height:geo.size.width - 32)
                                } else {
                                    withAnimation {
                                        
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Image(systemName: "photo").aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                    .scaledToFit()
                                                    .cornerRadius(16)
                                                    .frame(width: geo.size.width - 32, height:geo.size.width - 32)
                                            case .success(let image):
                                                
                                                image.resizable()
                                                    .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                    .scaledToFit()
                                                    .cornerRadius(16)
                                                
                                            case .failure:
                                                EmptyView()
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }.frame(maxWidth: geo.size.width - 32, maxHeight:geo.size.width - 32)
                                    }
                                }
                            }
                            
                            
                            // Address and Categories
                            ZStack(alignment: .leading) {
                                VStack {
                                    Text(placeResponse.categories.joined(separator: ", ")).italic()
                                        .padding(PlaceAboutView.defaultPadding)
                                    
                                    if let description = placeDetailsResponse.description, !description.isEmpty {
                                        Text(description).padding(PlaceAboutView.defaultPadding)
                                    }
                                    
                                    Label(placeResponse.formattedAddress, systemImage: "mappin")
                                        .multilineTextAlignment(.center)
                                        .padding()
                                        .labelStyle(.titleOnly)
                                        .padding(PlaceAboutView.defaultPadding)
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
                                    if sizeClass == .compact {
                                        Label(isSaved ? "Delete" : "Add to List", systemImage: isSaved ? "minus.circle" : "plus.circle")
                                            .labelStyle( .iconOnly )
                                    } else {
                                        Label(isSaved ? "Delete" : "Add to List", systemImage: isSaved ? "minus.circle" : "plus.circle")
                                            .labelStyle(.titleAndIcon)
                                    }
                                    
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
                                        
                                        if sizeClass == .compact {
                                            Label(tel, systemImage: "phone")
                                                .labelStyle(.iconOnly)
                                            
                                        } else {
                                            Label(tel, systemImage: "phone")
                                                .labelStyle(.titleAndIcon)
                                        }
                                        
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
                                        
                                        if sizeClass == .compact {
                                            Label("Visit website", systemImage: "link")
                                                .labelStyle(.iconOnly)
                                        } else {
                                            Label("Visit website", systemImage: "link")
                                                .labelStyle(.titleAndIcon)
                                        }
                                        
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
                                    if sizeClass == .compact {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                            .labelStyle(.iconOnly)
                                    } else {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                            .labelStyle(.titleAndIcon)
                                    }
                                }
                                .padding(PlaceAboutView.defaultPadding)
                                .onTapGesture {
                                    presentingPopover.toggle()
                                }
                                .sheet(isPresented:$presentingPopover) {
                                    if let result = modelController.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                                        let items:[Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
                                        ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)
                                            .presentationDetents([.medium])
                                            .presentationDragIndicator(.visible)
                                            .presentationCompactAdaptation(.sheet)
                                    }
                                }
#endif
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                            // Related Places Section
                            Section {
                                if modelController.relatedPlaceResults.count == 0 {
                                    ProgressView("Personalizing Related Places")
                                        .padding(.vertical, 24)
                                } else {
                                    ScrollView(.horizontal) {
                                        HStack {
                                            ForEach(modelController.relatedPlaceResults) { relatedPlace in
                                                VStack {
                                                    Text(relatedPlace.title).bold().padding(8)
                                                    if let neighborhood = relatedPlace.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                        Text(neighborhood).italic().padding(8)
                                                    } else if let locality = relatedPlace.placeResponse?.locality {
                                                        Text(locality).italic().padding(8)
                                                    }
                                                }
                                                .padding(PlaceAboutView.defaultPadding)
                                                .background(RoundedRectangle(cornerRadius: 16)
                                                    .strokeBorder())
                                                .onTapGesture {
                                                    Task(priority:.userInitiated) {
                                                        withAnimation {
                                                            proxy.scrollTo(topID)
                                                        }
                                                        do {
                                                            try await chatModel.didTap(placeChatResult: relatedPlace,filters:[:], cacheManager: cacheManager, modelController: modelController)
                                                        } catch {
                                                            modelController.analyticsManager.trackError(error:error, additionalInfo: nil)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                    }
                                }
                            } header: {
                                Text("Related Places").font(.headline)
                            }.padding(.horizontal,16)
                                .padding(.vertical, 24)
                            
                            // Tastes Section
                            if let tastes = placeDetailsResponse.tastes, !tastes.isEmpty {
                                Section {
                                    let gridItems = Array(repeating: GridItem(.flexible(), spacing: PlaceAboutView.defaultPadding), count: sizeClass == .compact ? 2 : 3)
                                    
                                    LazyVGrid(columns: gridItems, alignment: .leading, spacing: 8) {
                                        ForEach($mutableTastes, id: \.self) { taste in
                                            let isSaved = cacheManager.cachedTastes(contains: taste.wrappedValue)
                                            HStack {
                                                Label("Save", systemImage: isSaved ? "minus.circle" : "plus.circle")
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
                                } header: {
                                    Text("Items").font(.headline)
                                }
                                .padding(.horizontal,16)
                                .padding(.vertical, 24)
                                .task {
                                    if let tastes = placeDetailsResponse.tastes {
                                        mutableTastes = tastes
                                    }
                                }
                                
                                Section {
                                    Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000), interactionModes: [.zoom, .rotate]) {
                                        Marker(title, coordinate: placeCoordinate.coordinate)
                                    }
                                    .mapStyle(.hybrid)
                                    .frame(minHeight: geo.size.height / 2.0)
                                    .cornerRadius(16)
                                } header: {
                                    Text("Location").font(.headline)
                                }
                                .padding(.horizontal,16)
                                .padding(.vertical, 24)
                            }
                        } else {
                            // Loading view
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                Spacer()
                            }
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
