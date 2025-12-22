import SwiftUI

extension View {
    @ViewBuilder
    func knowMapsTabBarOnlyIfAvailable() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self.tabViewStyle(.tabBarOnly)
        } else {
            self
        }
        #else
        self.tabViewStyle(.tabBarOnly)
        #endif
    }

    @ViewBuilder
    func knowMapsPresentationSizingFittedIfAvailable() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func knowMapsToolbarBackgroundVisibilityIfAvailable(_ visibility: Visibility) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self.toolbarBackgroundVisibility(visibility)
        } else {
            self
        }
        #else
        self.toolbarBackgroundVisibility(visibility)
        #endif
    }
}
