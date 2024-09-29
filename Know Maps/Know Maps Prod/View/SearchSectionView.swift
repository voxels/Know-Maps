//
//  SearchSectionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/28/24.
//

import SwiftUI

struct SearchSectionView: View {
    @ObservedObject public var chatModel: ChatResultViewModel

    var body: some View {
        List(selection:$chatModel.selectedPersonalizedSearchSection) {
            ForEach(PersonalizedSearchSection.allCases.sorted(by: {$0.rawValue < $1.rawValue}), id:\.self) { section in
                Text(section.rawValue)
            }
        }
        .listStyle(.sidebar)
    }
}
