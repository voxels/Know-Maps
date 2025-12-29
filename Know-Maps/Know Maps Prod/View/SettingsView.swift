import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var authService: AppleAuthenticationService
    var cacheManager: CloudCacheManager
    var modelController: DefaultModelController
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAccountAlert = false
    @State private var showingClearStorageAlert = false
    
    public init(cacheManager: CloudCacheManager, modelController: DefaultModelController) {
        self.cacheManager = cacheManager
        self.modelController = modelController
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(authService.fullName.isEmpty ? "Signed In with Apple" : authService.fullName)
                                .font(.headline)
                            Text(authService.appleUserId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                        dismiss()
                    }
                }
                
                Section("Privacy & Sovereignty") {
                    Button {
                        showingClearStorageAlert = true
                    } label: {
                        Label("Clear All Search History", systemImage: "trash")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        Label("Delete Know Maps Account", systemImage: "person.badge.minus")
                    }
                }
                
                Section("AI Tuning") {
                    NavigationLink {
                        TasteTuningView(cacheManager: cacheManager, modelController: modelController)
                    } label: {
                        Label("Manage Discover Tastes", systemImage: "slider.horizontal.2.square.on.square")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0 (Preservation)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Clear All Search History?", isPresented: $showingClearStorageAlert) {
                Button("Clear", role: .destructive) {
                    Task {
                        try? await cacheManager.cloudCacheService.deleteAllUserCachedGroups()
                        try? await cacheManager.refreshCache()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all your saved places, categories, and tastes. This action cannot be undone.")
            }
            .alert("Delete Know Maps Account?", isPresented: $showingDeleteAccountAlert) {
                Button("Delete Everything", role: .destructive) {
                    Task {
                        try? await cacheManager.cloudCacheService.deleteAllUserCachedGroups()
                        authService.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your data will be permanently deleted from iCloud and you will be signed out. This is irreversible.")
            }
        }
    }
}

struct TasteTuningView: View {
    var cacheManager: CloudCacheManager
    var modelController: DefaultModelController
    
    var body: some View {
        List {
            Section {
                ForEach(cacheManager.allCachedTastes, id: \.id) { taste in
                    HStack {
                        Text(taste.title)
                            .font(.body)
                        Spacer()
                        Picker("Weight", selection: Binding(
                            get: { Int(taste.rating) },
                            set: { newValue in
                                updateWeight(for: taste, weight: newValue)
                            }
                        )) {
                            Text("Rarely").tag(1)
                            Text("Occasionally").tag(2)
                            Text("Often").tag(3)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .tint(.accentColor)
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            let taste = cacheManager.allCachedTastes[index]
                            try? await SearchSavedViewModel.shared.removeSelectedItem(selectedSavedResult: taste.recordId, cacheManager: cacheManager, modelController: modelController)
                        }
                    }
                }
            } header: {
                Text("My Tastes")
            } footer: {
                Text("Influence how the discovery engine ranks results based on your preferences.")
            }
        }
        .navigationTitle("Taste Tuning")
    }
    
    private func updateWeight(for taste: UserCachedRecord, weight: Int) {
        Task {
            do {
                _ = try await cacheManager.cloudCacheService.storeUserCachedRecord(
                    recordId: taste.recordId,
                    group: taste.group,
                    identity: taste.identity,
                    title: taste.title,
                    icons: taste.icons,
                    list: taste.list,
                    section: taste.section,
                    rating: Double(weight)
                )
                try? await cacheManager.refreshCache()
            } catch {
                print("Failed to update weight: \(error)")
            }
        }
    }
}
