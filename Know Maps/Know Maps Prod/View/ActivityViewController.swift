//
//  ActivityViewController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import SwiftUI

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]
    @Environment(\.dismiss) var dismissAction
    @Binding public var isPresentingShareSheet:Bool

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            isPresentingShareSheet.toggle()
            dismissAction()
        }
        return controller   
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}

}
