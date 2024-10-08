import SwiftUI

struct PlacePhotosView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject public var chatModel: ChatResultViewModel
    @Binding public var resultId: ChatResult.ID?
    @State private var position: Int?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let resultId = resultId, let placeChatResult = chatModel.modelController.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let photoResponses = placeDetailsResponse.photoResponses {
                    if photoResponses.count > 0 {
                        ScrollView(.vertical) {
                           
                            let columns = Array(repeating: GridItem(.adaptive(minimum: geo.size.width)),  count:sizeClass == .compact ? 1 : 2)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(photoResponses) { response in
                                    if let url = response.photoUrl() {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                HStack {
                                                    Spacer()
                                                    ProgressView()
                                                    Spacer()
                                                }
                                            case .success(let image):
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .cornerRadius(16)
                                                    .scaledToFit()
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
