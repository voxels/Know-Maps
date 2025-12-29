import SwiftUI

struct MainUI: View {
    @EnvironmentObject var authService: AppleAuthenticationService
    var modelController: DefaultModelController
    var cacheManager: CloudCacheManager
    
    var body: some View {
        UnifiedSearchView(modelController: modelController, cacheManager: cacheManager)
            .navigationTitle("Know Maps")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        authService.signOut()
                    }
                }
            }
    }
}
