import SwiftUI
import UniformTypeIdentifiers

struct PromptRankingView: View {
    @EnvironmentObject var cloudCache: CloudCache
    @ObservedObject var chatHost: AssistiveChatHost
    @ObservedObject var chatModel: ChatResultViewModel
    @ObservedObject var locationProvider: LocationProvider
    
    @Binding var contentViewDetail: ContentDetailView
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 64) {
                // Second ScrollView (Drag Source)
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: geometry.size.width / 4)),
                            GridItem(.adaptive(minimum: geometry.size.width / 4))
                        ],
                        alignment: .leading,
                        spacing: 32
                    ) {
                        ForEach(chatModel.allCachedResults) { result in
                            Text(result.parentCategory)
                                .padding()
                                .font(.title3)
                                // Enable dragging
                                .onDrag {
                                    let itemProvider = NSItemProvider(object: result.id.uuidString as NSString)
                                    return itemProvider
                                }
                        }
                    }
                }
                
                // First ScrollView (Drop Destination)
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.fixed(geometry.size.width / 2))],
                        alignment: .center,
                        spacing: 32
                    ) {
                        ForEach(chatModel.cachedListResults) { result in
                            VStack(spacing: 8) {
                                HStack {
                                    Spacer()
                                    Text(result.parentCategory)
                                        .padding()
                                        .font(.title)
                                    Spacer()
                                }
                                .foregroundStyle(.primary)
                                // Enable dropping onto each cachedListResult
                               
                                
                                ForEach(result.children) { categoryResult in
                                    ForEach(categoryResult.categoricalChatResults) { chatResult in
                                        if chatResult.placeResponse != nil {
                                            Text(chatResult.title)
                                                .foregroundStyle(.secondary)
                                                .font(.title2)
                                        }
                                    }
                                }
                            }.onDrop(of: [UTType.text], isTargeted: nil) { providers in
                                handleDrop(providers: providers, onto: result)
                            }
                        }
                    }
                }
                
            }
        }
    }
    
    // Drop handler function
    func handleDrop(providers: [NSItemProvider], onto targetCategoryResult: CategoryResult) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { (object, error) in
                    if let idString = object as? String,
                       let uuid = UUID(uuidString: idString) {
                        Task(priority:.userInitiated) { @MainActor in
                            if let index = chatModel.cachedTasteResults.firstIndex(where: { $0.id == uuid }) {
                                let draggedCategoryResult = chatModel.cachedTasteResults[index]
                                
//                                if let cachedTasteResults = chatModel.cachedResults(for: "Taste", identity: draggedCategoryResult.parentCategory) {
//                                    for cachedTasteResult in cachedTasteResults {
//                                        do {
//                                            try await chatModel.cloudCache.deleteUserCachedRecord(for: cachedTasteResult)
//                                        } catch {
//                                            chatModel.analytics?.track(name: "error \(error)")
//                                            print(error)
//                                        }
//                                    }
//                                }
                                
                                do {
                                    var userRecord = UserCachedRecord(recordId: "", group: "Taste", identity:draggedCategoryResult.parentCategory, title:draggedCategoryResult.parentCategory, icons: "", list:targetCategoryResult.parentCategory)
                                    let record = try await chatModel.cloudCache.storeUserCachedRecord(for: userRecord.group, identity: userRecord.identity, title: userRecord.title, list:userRecord.list)
                                    userRecord.setRecordId(to: record)
                                    try await chatModel.refreshCache(cloudCache: cloudCache )
                                }
                                catch {
                                    print(error)
                                }
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}