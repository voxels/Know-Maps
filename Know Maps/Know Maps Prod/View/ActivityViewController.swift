//
//  ActivityViewController.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/28/23.
//

import SwiftUI

#if os(iOS) || os(visionOS)

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]
    @Environment(\.dismiss) var dismissAction
    @Binding  public var isPresentingShareSheet:Bool

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


#elseif os(macOS)

struct ActivityViewController: NSViewControllerRepresentable {
    
    var activityItems: [Any]
    @Binding  public var isPresentingShareSheet: Bool

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ActivityViewController

        init(_ parent: ActivityViewController) {
            self.parent = parent
        }

        func share() {
            guard let window = NSApplication.shared.windows.first else { return }
            let picker = NSSharingServicePicker(items: parent.activityItems)
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
            parent.isPresentingShareSheet.toggle()
        }
    }
}

extension ActivityViewController {
    func share() {
        makeCoordinator().share()
    }
}

#endif
