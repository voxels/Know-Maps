import SwiftUI
import NukeUI

struct PlacePhotosView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Binding public var chatModel: ChatResultViewModel
    @Binding var modelController:DefaultModelController
    @State private var position: Int?

    var body: some View {
        GeometryReader { geo in
            if let resultId = modelController.selectedPlaceChatResult, let placeChatResult = modelController.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let photoResponses = placeDetailsResponse.photoResponses {
                if photoResponses.count > 0 {
                    ScrollView(.vertical) {
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geo.size.height)),  count:sizeClass == .compact ? 1 : 2)
                        LazyVGrid(columns: columns, alignment:.leading, spacing: 16) {
                            ForEach(photoResponses) { response in
                                let aspectRatio = response.aspectRatio
                                if let url = response.photoUrl() {
                                    LazyImage(url: url) { state in
                                        if let image = state.image {
                                               image.resizable()
                                                .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                .scaledToFit()
                                           } else if state.error != nil {
                                               Image(systemName: "photo")
                                           } else {
                                               ProgressView()
                                                   .padding()
                                                   .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                           }
                                    }
                                } else {
                                    EmptyView()
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
