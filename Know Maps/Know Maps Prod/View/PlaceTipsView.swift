//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI

struct PlaceTipsView: View {
    @Binding public var chatModel:ChatResultViewModel
    @Binding var modelController:DefaultModelController
    @State private var isPresentingShareSheet:Bool = false
    
    var body: some View {
        
        if let resultId = modelController.selectedPlaceChatResult, let placeChatResult = modelController.placeChatResult(for: resultId), let placeDetailsResponse = placeChatResult.placeDetailsResponse, let tips = placeDetailsResponse.tipsResponses {
            List(tips){ tip in
                ZStack() {
                    Rectangle()
                        .cornerRadius(32)
                        .glassEffect()
                    Text(tip.text).padding()
                }.padding()
            }
        } else {
            ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
        }
    }
}
