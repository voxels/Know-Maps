//
//  PlaceContantView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import CoreLocation
import MapKit
import CallKit

struct PlaceAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject public var chatHost:AssistiveChatHost
    @ObservedObject public var chatModel:ChatResultViewModel
    @ObservedObject public var locationProvider:LocationProvider
    @Binding public var resultId:ChatResult.ID?
    @Binding public var sectionSelection:Int
    @State private var presentingPopover:Bool = false
    
#if os(visionOS) || os(iOS)
    @State private var callController = CXCallController()
#endif
    @State private var isPresentingShareSheet:Bool = false
    static let defaultPadding:CGFloat = 8
    static let mapFrameConstraint:Double = 50000
    static let buttonHeight:Double = 44
    
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack {
                    if let resultId = resultId, let result = chatModel.placeChatResult(for: resultId), let placeResponse = result.placeResponse, let placeDetailsResponse = result.placeDetailsResponse {
                        let placeCoordinate = CLLocation(latitude: placeResponse.latitude, longitude: placeResponse.longitude)
                        
                        let title = placeResponse.name
                        Map(initialPosition: .automatic, bounds: MapCameraBounds(minimumDistance: 5000, maximumDistance: 250000)) {
                            Marker(title, coordinate: placeCoordinate.coordinate)
                        }
                        .mapControls {
                            MapPitchToggle()
                            MapUserLocationButton()
                            MapCompass()
                        }
                        .mapStyle(.hybrid)
                        .frame(minHeight: geo.size.height / 2.0)
                        .padding(EdgeInsets(top: 0, leading: PlaceAboutView.defaultPadding * 2, bottom: PlaceAboutView.defaultPadding, trailing: PlaceAboutView.defaultPadding * 2))
                        
                        ZStack(alignment: .leading) {
                            Rectangle().foregroundStyle(.thinMaterial)
                            VStack(){
                                ZStack {
                                    Rectangle().foregroundStyle(.thickMaterial)
                                    VStack{
                                        Text(placeResponse.categories.joined(separator: ", ")).italic()
                                    }
                                    .padding(PlaceAboutView.defaultPadding)
                                }
                                .padding(PlaceAboutView.defaultPadding)
                                
                                
                                ZStack {
                                    Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center)
#if os(macOS)
                                        .foregroundStyle(.background)
#else
                                        .foregroundColor(Color(uiColor:.systemFill))
#endif
                                    
                                    Label(placeResponse.formattedAddress, systemImage: "mappin").foregroundStyle(.primary)
                                    
                                }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif                                
                            .padding(PlaceAboutView.defaultPadding)
                                .onTapGesture {
                                    sectionSelection = 1
                                }
                                
                                HStack {
                                    if chatModel.cloudCache.hasPrivateCloudAccess {
                                        ZStack {
                                        Capsule().frame(height: PlaceAboutView.buttonHeight, alignment: .center)
#if os(macOS)
                                            .foregroundStyle(.background)
#else
                                            .foregroundColor(Color(uiColor:.systemFill))
#endif
                                        
                                        Label("Add to List", systemImage: "star")
#if os(iOS) || os(visionOS)
                                            .labelStyle(.iconOnly).foregroundStyle(.primary)
#endif
                                    }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                            .onTapGesture {
                                        presentingPopover.toggle()
                                    }
                                        .popover(isPresented: $presentingPopover) {
                                        AddListItemView(chatModel: chatModel, presentingPopover:$presentingPopover)
                                            .frame(width:300, height:600)
                                            .presentationCompactAdaptation(.automatic)
                                    }
                                }
                                    
                                    if let tel = placeDetailsResponse.tel {
                                        ZStack {
                                            Capsule()
#if os(macOS)
                                                .foregroundStyle(.background)
#else
                                                .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            if sizeClass == .compact {
                                                Label("\(tel)", systemImage: "phone")
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(.primary)
                                                    .labelStyle( .iconOnly )
                                            } else {
                                                Label("\(tel)", systemImage: "phone")
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(.primary)
                                                    .labelStyle( .titleOnly)
                                            }
                                        }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                                            .onTapGesture {
#if os(visionOS) || os(iOS)
                                            if let url = URL(string: "tel://\(tel)") {
                                                openURL(url)
                                            }
#endif
                                        }
                                    }
                                    
                                    
                                    
                                    if let website = placeDetailsResponse.website, let url = URL(string: website) {
                                        ZStack {
                                            Capsule()
                                                .onTapGesture {
                                                    openURL(url)
                                                }
#if os(macOS)
                                                .foregroundStyle(.background)
#else
                                                .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            Link(destination: url) {
                                                Label("Visit website", systemImage: "link")
                                                    .foregroundStyle(.primary)
#if os(iOS) || os(visionOS)
                                                    .labelStyle(.iconOnly)
                                                    .tint(Color.primary)
#endif
                                            }.foregroundColor(Color.primary)
                                        }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                                    }
                                    
                                    
                                    let rating = placeDetailsResponse.rating
                                    if rating > 0 {
                                        ZStack {
                                            Capsule()
#if os(macOS)
                                                .foregroundStyle(.background)
#else
                                                .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            Label(PlacesList.formatter.string(from: NSNumber(value: rating)) ?? "0", systemImage: "quote.bubble").foregroundStyle(.primary)
#if os(iOS)
                                                .labelStyle(.titleOnly)
#endif
                                            
                                        }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                                        .onTapGesture {
                                            sectionSelection = 3
                                        }
                                    }
                                    
#if os(iOS) || os(visionOS)
                                    if let price = placeDetailsResponse.price {
                                        ZStack {
                                            Capsule()
#if os(macOS)
                                                .foregroundStyle(.background)
#else
                                                .foregroundColor(Color(uiColor:.systemFill))
#endif
                                                .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                            switch price {
                                            case 1:
                                                Text("$").foregroundStyle(.primary)
                                            case 2:
                                                Text("$$").foregroundStyle(.primary)
                                            case 3:
                                                Text("$$$").foregroundStyle(.primary)
                                            case 4:
                                                Text("$$$$").foregroundStyle(.primary)
                                            default:
                                                Text("\(price)").foregroundStyle(.primary)
                                            }
                                        }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                                    }
                                    
                                    ZStack {
                                        Capsule()
#if os(macOS)
                                            .foregroundStyle(.background)
#else
                                            .foregroundColor(Color(uiColor:.systemFill))
#endif
                                            .frame(height: PlaceAboutView.buttonHeight, alignment: .center)
                                        
                                        Image(systemName: "square.and.arrow.up").foregroundStyle(.primary)
                                    }
#if os(iOS) || os(visionOS)
                            .hoverEffect(.lift)
#endif
                                    .onTapGesture {
                                        self.isPresentingShareSheet.toggle()
                                    }
#endif
                                    
                                    Spacer()
                                }.padding(PlaceAboutView.defaultPadding)
                            }
                        }.padding(EdgeInsets(top: 0, leading: PlaceAboutView.defaultPadding * 2, bottom: 0, trailing: PlaceAboutView.defaultPadding * 2))
                            .popover(isPresented: $isPresentingShareSheet) {
                                if let result = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = result.placeDetailsResponse  {
                                    let items:[Any] = [placeDetailsResponse.website ?? placeDetailsResponse.searchResponse.address]
#if os(visionOS) || os(iOS)
                                    ActivityViewController(activityItems:items, applicationActivities:[UIActivity](), isPresentingShareSheet: $isPresentingShareSheet)
#endif
                                }
                            }
                        
                        if chatModel.cloudCache.hasPrivateCloudAccess, chatModel.featureFlags.owns(flag: .hasPremiumSubscription) {
                            PlaceDescriptionView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: $resultId).padding(PlaceAboutView.defaultPadding * 2)
                        }
                        if chatModel.featureFlags.owns(flag: .hasPremiumSubscription), chatModel.cloudCache.hasPrivateCloudAccess {
                        if let tastes = placeDetailsResponse.tastes, tastes.count > 0 {
                            let gridItems = Array(repeating: GridItem(), count: sizeClass == .compact ? 2 : 3)
                            Section("Features") {
                                
                                LazyVGrid(columns:gridItems, alignment:.leading, spacing:8 ){
                                ForEach(tastes, id: \.self) { taste in
                                    HStack {
                                        let isSaved = chatModel.cachedTastes(contains: taste)
                                        Button("Save", systemImage: isSaved ? "minus" : "plus") {
                                            let isSaved = chatModel.cachedTastes(contains: taste)
                                            if isSaved {
                                                if let cachedTasteResults = chatModel.cachedTasteResults(for: "Taste", identity: taste) {
                                                    for cachedTasteResult in cachedTasteResults {
                                                        Task {
                                                            do {
                                                                try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
                                                                try await chatModel.refreshCache(cloudCache: chatModel.cloudCache)
                                                            } catch {
                                                                chatModel.analytics?.track(name: "error \(error)")
                                                                print(error)
                                                            }
                                                            
                                                        }
                                                    }
                                                }
                                            } else {
                                                Task {
                                                    do {
                                                        var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity: taste, title: taste, icons: "", list: nil)
                                                        let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title)
                                                        if let resultName = record.saveResults.keys.first?.recordName {
                                                            userRecord.setRecordId(to:resultName)
                                                        }
                                                        chatModel.appendCachedTaste(with: userRecord)
                                                        try await chatModel.refreshTastes(page:chatModel.lastFetchedTastePage)
                                                    } catch {
                                                        chatModel.analytics?.track(name: "error \(error)")
                                                        print(error)
                                                    }
                                                }
                                            }
                                        }
                                        .labelStyle(.iconOnly)
                                        

#if os(macOS)
                                                .foregroundStyle(.background)
                                                .frame(minWidth: 44, minHeight:44)
                                                .padding(16)
#else
                                                .foregroundColor(Color(uiColor:.systemFill))
                                                .frame(minWidth: 44, minHeight:44 )
                                                .padding(16)
                                                .hoverEffect(.lift)
#endif
                                        Text(taste)
                                        Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        

                            if chatModel.relatedPlaceResults.count > 0 {
                                Section("Related Places") {
                                    
                             ScrollView(.horizontal) {
                                    
                                    HStack{
                                        ForEach(chatModel.relatedPlaceResults){ result in
                                            
                                            
                                            
                                            ZStack(alignment: .center, content: {
                                                
                                                RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)).frame(width: geo.size.width-48, height: (geo.size.width) / 4).foregroundStyle(.regularMaterial)
                                                VStack {
                                                    Text(result.title).bold().lineLimit(1).padding(8)
                                                    if let neighborhood = result.recommendedPlaceResponse?.neighborhood, !neighborhood.isEmpty {
                                                        
                                                        Text(neighborhood).italic()
                                                    } else{
                                                        Text("")
                                                    }
                                                    HStack {
                                                        if let placeResponse = result.recommendedPlaceResponse {
                                                            Text(!placeResponse.address.isEmpty ?
                                                                 placeResponse.address : placeResponse.formattedAddress )
                                                            .lineLimit(1)
                                                            .italic()
                                                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                                        }
                                                    }
                                                }
                                                
                                            })
                                            .frame(maxWidth: 300, maxHeight: 130 )
                                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 16, height: 16)))
                                            .cornerRadius(16)
                                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                                        }
                                    }
                                }
                                }
                            }
                        }
                        
                    } else {
                        ZStack(alignment: .center) {
                            ProgressView().progressViewStyle(.circular)
                        }.frame(width: geo.size.width, height:geo.size.width)
                    }
                }
            }
        }
    }
    
    
#if os(visionOS) || os(iOS)
    func call(tel:String) {
        let uuid = UUID()
        let digits = tel.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: " ", with: "")
        let handle = CXHandle(type: .phoneNumber, value: digits)
        
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        
        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
#endif
}

#Preview {
    
    let locationProvider = LocationProvider()
    
    let chatHost = AssistiveChatHost()
    let cloudCache = CloudCache()
    let featureFlags = FeatureFlags()
    
    let chatModel = ChatResultViewModel(locationProvider: locationProvider, cloudCache: cloudCache, featureFlags: featureFlags)
    
    chatModel.assistiveHostDelegate = chatHost
    chatHost.messagesDelegate = chatModel
    
    return PlaceAboutView(chatHost:chatHost,chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil), sectionSelection:.constant(0))
}
