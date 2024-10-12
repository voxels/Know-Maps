//
//  SearchSectionView.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 9/28/24.
//

import SwiftUI

struct SearchSectionView: View {
    @Binding public var chatModel: ChatResultViewModel
    @Binding var modelController:DefaultModelController

    var body: some View {
        List(selection:$modelController.selectedPersonalizedSearchSection){
            ForEach(PersonalizedSearchSection.allCases.sorted(by: {$0.rawValue < $1.rawValue}), id:\.self) { section in
                Text(section.rawValue)
            }
        }
        .listStyle(.sidebar)
#if os(iOS) || os(visionOS)
        .toolbarBackground(.visible, for: .navigationBar)
#endif

    }
}
