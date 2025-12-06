//
//  RatingButton.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/14/24.
//

import SwiftUI

struct RatingButton: View {
    let result: CategoryResult
    let rating: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .frame(width: 44, height: 44)
        .buttonStyle(.borderless)
        .labelStyle(.iconOnly)
    }

    @ViewBuilder
    private var label: some View {
        if let rating = rating {
            switch rating {
            case ..<1:
                Label("Recommend rarely", systemImage: "star.slash")
                    .foregroundColor(.red)
            case 1..<3:
                Label("Recommend occasionally", systemImage: "star.leadinghalf.filled")
                    .foregroundColor(.accentColor)
            case 3...:
                Label("Recommend often", systemImage: "star.fill")
                    .foregroundColor(.green)
            default:
                // Default case for unexpected rating values
                Label("Recommend rarely", systemImage: "star.slash")
                    .foregroundColor(.red)
            }
        } else {
            // Default state for an item that is not yet saved/rated
            Label("Recommend rarely", systemImage: "star.slash")
                .foregroundColor(.red)
        }
    }
}
