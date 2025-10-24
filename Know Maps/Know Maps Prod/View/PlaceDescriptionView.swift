//
//  PlaceDescriptionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/23/24.
//

import SwiftUI

struct PlaceDescriptionView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding var modelController:DefaultModelController
    
    var body: some View {
        if let resultId = modelController.selectedPlaceChatResultFsqId, let placeChatResult = modelController.placeChatResult(with: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let _ = placeDetailsResponse.tipsResponses {
            if let description = placeDetailsResponse.description, !description.isEmpty {
                    Text(description)
                    .padding()
#if !os(visionOS)
                            .glassEffect(.regular, in: .rect(cornerRadius: 32))
#else
                            .background(.ultraThinMaterial)
#endif
            }
        }
    }
}

