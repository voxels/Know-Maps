//
//  SearchSectionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/28/24.
//

import SwiftUI

struct SearchSectionView: View {
    @ObservedObject public var chatModel: ChatResultViewModel
    @State private var selectedPersonalizedSearchSection: PersonalizedSearchSection?

    var body: some View {
        List(selection:$selectedPersonalizedSearchSection){
            ForEach(PersonalizedSearchSection.allCases.sorted(by: {$0.rawValue < $1.rawValue}), id:\.self) { section in
                Text(section.rawValue)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedPersonalizedSearchSection) { oldValue, newValue in
            guard let newValue = newValue else {
                return
            }
            chatModel.modelController.selectedPersonalizedSearchSection = newValue
            
        }
    }
}
