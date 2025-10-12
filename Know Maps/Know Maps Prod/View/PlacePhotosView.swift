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
                        let columns = Array(repeating: GridItem(.adaptive(minimum: geo.size.width - 32)),  count:sizeClass == .compact ? 1 : 2)
                        LazyVGrid(columns: columns, alignment:.leading, spacing: 16) {
                            ForEach(photoResponses) { response in
                                let aspectRatio = response.aspectRatio
                                if let url = response.photoUrl() {
                                    VStack(alignment: .leading, spacing: 0) {
                                        LazyImage(url: url) { state in
                                            if let image = state.image {
                                                image
                                                    .resizable()
                                                    .aspectRatio(CGFloat(aspectRatio), contentMode: .fit)
                                                    .scaledToFit()
                                                    .clipShape(.rect(cornerRadius: 32))
                                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                            } else if state.error != nil {
                                                Image(systemName: "photo")
                                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                            } else {
                                                ProgressView()
                                                    .padding()
                                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .gridCellAnchor(.topLeading)
                                } else {
                                    EmptyView()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("No photos found for this location", systemImage: "x.circle.fill")
            }
        }
    }
}
