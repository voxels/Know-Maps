//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlaceTipsView: View {
    public var chatModel:ChatResultViewModel
    var modelController:DefaultModelController // This is fine
    @State private var isPresentingShareSheet:Bool = false
    
    var body: some View {
        if let resultId = modelController.selectedPlaceChatResultFsqId, let placeChatResult = modelController.placeChatResult(with: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let tips = placeDetailsResponse.tipsResponses {
            List(tips){ tip in
                Text(tip.text)
                    .padding()
            }
        } else {
            ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
        }
    }
}
