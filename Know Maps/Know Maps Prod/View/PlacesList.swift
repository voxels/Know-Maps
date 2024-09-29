//
//  PlacesList.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/15/23.
//

import SwiftUI
import CoreLocation
import MapKit

struct PlacesList: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @StateObject public var placeDirectionsChatViewModel = PlaceDirectionsViewModel(rawLocationIdent: "")
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @State private var showingPopover:Bool = false
    @State private var cameraPosition:MapCameraPosition = .automatic
    @State private var selectedItem: String?
    @State private var showMapsResultViewSheet:Bool = false
    @State private var showNavigationLocationSheet:Bool = false
    @State private var showPlaceViewSheet:Bool = false
    @State private var searchText:String = ""
    
    static var formatter:NumberFormatter {
        let retval = NumberFormatter()
        retval.maximumFractionDigits = 1
        return retval
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView{
                if !chatModel.filteredRecommendedPlaceResults.isEmpty {
                    let sizeWidth:CGFloat = sizeClass == .compact ? 1 : 2
                    let columns = Array(repeating: GridItem(.adaptive(minimum: geo.size.width / sizeWidth)),  count:Int(sizeWidth))
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(chatModel.filteredRecommendedPlaceResults){ result in
                            VStack(alignment:.leading, content: {
                                ZStack {
                                    VStack(alignment: .leading) {
                                        if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                            
                                            Text(result.title).bold()
                                            Text(neighborhood).italic()
                                            
                                        } else{
                                            Text(result.title).bold()
                                        }
                                        if let placeResponse = result.recommendedPlaceResponse, !placeResponse.address.isEmpty {
                                            Text(placeResponse.address)
                                            Text(placeResponse.city)
                                        }
                                    }.padding()
                                }
                                if let photo = result.recommendedPlaceResponse?.photo, !photo.isEmpty, let url = URL(string: photo) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .clipped()
                                        case .failure:
                                            EmptyView()
                                        @unknown default:
                                            // Since the AsyncImagePhase enum isn't frozen,
                                            // we need to add this currently unused fallback
                                            // to handle any new cases that might be added
                                            // in the future:
                                            EmptyView()
                                        }
                                    }
                                } else if let response = result.placeDetailsResponse, let photoResponses = response.photoResponses, let photo = photoResponses.first, let url = photo.photoUrl() {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image.resizable()
                                                .aspectRatio(contentMode: .fit)
                                        case .failure:
                                            Image(systemName: "photo")
                                        @unknown default:
                                            // Since the AsyncImagePhase enum isn't frozen,
                                            // we need to add this currently unused fallback
                                            // to handle any new cases that might be added
                                            // in the future:
                                            EmptyView()
                                        }
                                    }
                                }
                            })
                            .background(.thinMaterial)
                            .cornerRadius(16)
                            .onTapGesture {
                                chatModel.selectedPlaceChatResult = result.id
                            }
                        }
                    }
                } else {
                    Text("No results found")
                }
            }
            .onChange(of: chatModel.selectedPlaceChatResult, { oldValue, newValue in
                showMapsResultViewSheet = false
                showNavigationLocationSheet = false
                if let _ = newValue {
                    showPlaceViewSheet = true
                } else {
                    showPlaceViewSheet = false
                }
            })
            .sheet(isPresented: $showMapsResultViewSheet) {
                    MapResultsView(chatHost: chatHost, model: chatModel, locationProvider: locationProvider, selectedMapItem: $selectedItem, cameraPosition:$cameraPosition)
                        .onChange(of: selectedItem) { oldValue, newValue in
                            if let newValue, let placeResponse = chatModel.filteredPlaceResults.first(where: { $0.placeResponse?.fsqID == newValue }) {
                                chatModel.selectedPlaceChatResult = placeResponse.id
                            }
                        }
                        .toolbar(content: {
                            ToolbarItem {
                                Button(action:{
                                    showMapsResultViewSheet.toggle()
                                }, label:{
                                    Label("List", systemImage: "list.bullet")
                                })
                            }
                        })
                        .frame(width: geo.size.width, height: geo.size.height)
            }
            .sheet(isPresented: $showPlaceViewSheet, content: {
                PlaceView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, placeDirectionsViewModel: placeDirectionsChatViewModel, resultId: $resultId)
                    .frame(minWidth:0, maxWidth: .infinity, idealHeight: geo.size.height, maxHeight: .infinity)
            })
            .sheet(isPresented:$showNavigationLocationSheet) {
                VStack {
                    HStack {
                        Button(action: {
                            showNavigationLocationSheet.toggle()
                        }, label: {
                            Label("Done", systemImage: "chevron.backward").labelStyle(.iconOnly)
                        })
                        
                        TextField("New York, NY", text: $searchText)
                            .padding()
                            .onSubmit {
                                search()
                            }
                        
                        Button("Current Location", systemImage:"location") {
                            Task {
                                do {
                                    if let currentLocationName = try await chatModel.currentLocationName() {
                                        try await chatModel.didSearch(caption:currentLocationName, selectedDestinationChatResultID:nil, intent:.Location)
                                    } else {
                                        showNavigationLocationSheet.toggle()
                                    }
                                } catch {
                                    chatModel.analytics?.track(name: "error \(error)")
                                    print(error)
                                }
                            }
                        }.labelStyle(.iconOnly)
                        
                        if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                           let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                        {
                            
                            let isSaved = chatModel.cachedLocation(contains:parent.locationName)
                            if isSaved {
                                Button("Delete", systemImage:"minus.circle") {
                                    if let location = parent.location, let cachedLocationResults = chatModel.cachedResults(for: "Location", identity:chatModel.cachedLocationIdentity(for: location)) {
                                        Task {
                                            for cachedLocationResult in cachedLocationResults {
                                                try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedLocationResult)
                                            }
                                            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }
                            } else {
                                Button("Save", systemImage:"square.and.arrow.down") {
                                    Task(priority: .userInitiated) {
                                        if let location = parent.location {
                                            var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list: nil)
                                            let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                            userRecord.setRecordId(to:record)
                                            chatModel.appendCachedLocation(with: userRecord)
                                            try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding()
                    NavigationLocationView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider)
                }.frame(maxWidth: geo.size.width / 2, minHeight:geo.size.height, maxHeight: .infinity)
            }
            .padding()
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        showMapsResultViewSheet.toggle()
                    } label: {
                        Label("Show Map", systemImage: "map")
                    }
                    Button("Search Location", systemImage:"location.magnifyingglass") {
                        chatModel.locationSearchText.removeAll()
                        showNavigationLocationSheet.toggle()
                    }
                }
            }
            
        }
    }
    
    func search() {
        if !searchText.isEmpty {
            Task {
                do {
                    try await chatModel.didSearch(caption:searchText, selectedDestinationChatResultID:nil, intent:.Location)
                    if let selectedDestinationLocationChatResult = chatModel.selectedDestinationLocationChatResult,
                       let parent = chatModel.locationChatResult(for: selectedDestinationLocationChatResult)
                    {
                        
                        Task(priority: .userInitiated) {
                            if let location = parent.location {
                                var userRecord = UserCachedRecord(recordId: "", group: "Location", identity: chatModel.cachedLocationIdentity(for: location), title: parent.locationName, icons: "", list: nil)
                                let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                userRecord.setRecordId(to:record)
                                chatModel.appendCachedLocation(with: userRecord)
                                try await chatModel.refreshCachedLocations(cloudCache: chatModel.cloudCache)
                            }
                        }
                    }
                } catch {
                    chatModel.analytics?.track(name: "error \(error)")
                    print(error)
                }
            }
        }
    }
}

#Preview {
    
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlacesList(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
