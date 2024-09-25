import SwiftUI

struct PlacePhotosView: View {
    @ObservedObject public var chatHost: AssistiveChatHost
    @ObservedObject public var chatModel: ChatResultViewModel
    @ObservedObject public var locationProvider: LocationProvider
    @Binding public var resultId: ChatResult.ID?
    @State private var position: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let resultId = resultId, let placeChatResult = chatModel.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let photoResponses = placeDetailsResponse.photoResponses {
                    if photoResponses.count > 0 {
                        ScrollView(.vertical) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) { // Two-column grid
                                ForEach(photoResponses) { response in
                                    if let url = response.photoUrl() {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .cornerRadius(16)
                                                .clipped()
                                        } placeholder: {
                                            Rectangle()
                                                .foregroundColor(.gray)
                                                .cornerRadius(16)
                                        }
                                        
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    ContentUnavailableView("No photos found for this location", systemImage: "x.circle.fill")
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

    return PlacePhotosView(chatHost: chatHost, chatModel: chatModel, locationProvider: locationProvider, resultId: .constant(nil))
}
