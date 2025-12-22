//
//  PlaceReviewsView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/21/23.
//

import SwiftUI
import Foundation

struct PlaceTipsView: View {
    public var chatModel:ChatResultViewModel
    var modelController:DefaultModelController // This is fine
    @State private var isPresentingShareSheet:Bool = false
    
    var body: some View {
        if let resultId = modelController.selectedPlaceChatResultFsqId,
           let placeChatResult = modelController.placeChatResult(with: resultId) {
            let tips = placeChatResult.placeDetailsResponse?.tipsResponses ?? []

            if tips.isEmpty {
                ContentUnavailableView("No tips found for \(placeChatResult.title)", systemImage: "x.circle.fill")
            } else {
                List(tips) { tip in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tip.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let dateText = formattedDateString(tip.createdAt) {
                            Text(dateText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } else {
            ContentUnavailableView("No tips found for this location", systemImage: "x.circle.fill")
        }
    }

    private func formattedDateString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: trimmed) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }

        return trimmed
    }
}
