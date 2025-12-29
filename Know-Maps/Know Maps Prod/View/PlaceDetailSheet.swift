import SwiftUI
import MapKit
import CoreLocation

struct PlaceDetailSheet: View {
    let result: ChatResult
    var modelController: DefaultModelController
    var cacheManager: CloudCacheManager
    @Environment(\.dismiss) private var dismiss
    @State private var heartPulsing = false
    @State private var userRating: Int = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Photo Gallery / Hero Header
                ZStack(alignment: .bottomLeading) {
                    if let photos = result.placeDetailsResponse?.photoResponses, !photos.isEmpty {
                        TabView {
                            ForEach(photos, id: \.ident) { photo in
                                AsyncImage(url: photo.photoUrl()) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color.secondary.opacity(0.2))
                                }
                            }
                        }
                        .frame(height: 350)
                        .tabViewStyle(.page)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 250)
                            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                    }
                    
                    // Gradient Overlay for Title
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.6)]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 100)
                    
                    // Pulse Heart Button Overlay
                    HStack {
                        Spacer()
                        Button {
                            toggleFavorite()
                        } label: {
                            Image(systemName: cacheManager.cachedPlaces(contains: result.title) ? "heart.fill" : "heart")
                                .font(.title)
                                .foregroundStyle(cacheManager.cachedPlaces(contains: result.title) ? .red : .white)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .scaleEffect(heartPulsing ? 1.4 : 1.0)
                                .shadow(radius: 10)
                        }
                        .padding()
                    }
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.system(.largeTitle, design: .rounded).bold())
                            if let categories = result.placeResponse?.categories.joined(separator: ", "), !categories.isEmpty {
                                Text(categories)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    
                    // Interactive User Rating
                    VStack(alignment: .leading, spacing: 8) {
                        Text("My Rating")
                            .font(.headline)
                        InteractiveRatingView(rating: $userRating) { newRating in
                            Task {
                                await SearchSavedViewModel.shared.addPlace(parent: result.id, rating: Double(newRating), cacheManager: cacheManager, modelController: modelController)
                                pulseHeart()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if let rating = result.placeDetailsResponse?.rating {
                        RatingView(rating: rating)
                    }
                    
                    // Quick Action Capsule
                    HStack(spacing: 12) {
                        ActionButton(icon: "phone.fill", label: "Call") {
                            if let tel = result.placeDetailsResponse?.tel {
                                let telUrl = "tel://" + tel.replacingOccurrences(of: " ", with: "")
                                if let url = URL(string: telUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        ActionButton(icon: "safari.fill", label: "Website") {
                            if let website = result.placeDetailsResponse?.website, let url = URL(string: website) {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        Menu {
                            Button { openInMaps(mode: MKLaunchOptionsDirectionsModeDriving) } label: { Label("Driving", systemImage: "car.fill") }
                            Button { openInMaps(mode: MKLaunchOptionsDirectionsModeWalking) } label: { Label("Walking", systemImage: "figure.walk") }
                            Button { openInMaps(mode: MKLaunchOptionsDirectionsModeTransit) } label: { Label("Transit", systemImage: "bus.fill") }
                        } label: {
                            ActionButton(icon: "arrow.triangle.turn.up.right.diamond.fill", label: "Directions", active: false) {}
                        }
                    }
                    
                    Divider()
                    
                    // Details
                    DetailRow(icon: "mappin.and.ellipse", text: result.placeResponse?.formattedAddress ?? "No address available")
                    
                    if let hours = result.placeDetailsResponse?.hours {
                        DetailRow(icon: "clock", text: hours)
                    }
                    
                    if let price = result.placeDetailsResponse?.price {
                        DetailRow(icon: "dollarsign.circle", text: String(repeating: "$", count: price))
                    }
                    
                    // Tastes & Features (Adoption)
                    if let tastes = result.placeDetailsResponse?.tastes, !tastes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tastes")
                                .font(.headline)
                            FlowLayout(items: tastes) { taste in
                                Button {
                                    Task {
                                        await SearchSavedViewModel.shared.addTaste(title: taste, rating: 1.0, cacheManager: cacheManager, modelController: modelController)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: cacheManager.cachedTastes(contains: taste) ? "checkmark.circle.fill" : "plus.circle")
                                            .font(.subheadline)
                                        Text(taste)
                                            .font(.subheadline.bold())
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(cacheManager.cachedTastes(contains: taste) ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .foregroundStyle(cacheManager.cachedTastes(contains: taste) ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Related Places
                    if !modelController.relatedPlaceResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Related Places")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(modelController.relatedPlaceResults) { related in
                                        NavigationLink(value: related) {
                                            RelatedPlaceCard(result: related)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    // Tips
                    if let tips = result.placeDetailsResponse?.tipsResponses, !tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tips")
                                .font(.headline)
                            ForEach(tips.prefix(5), id: \.ident) { tip in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tip.text)
                                        .font(.subheadline)
                                    Text(tip.createdAt)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ChatResult.self) { related in
            PlaceDetailSheet(result: related, modelController: modelController, cacheManager: cacheManager)
        }
        .task {
            if result.placeDetailsResponse == nil {
                try? await modelController.fetchPlaceDetails(for: result)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func openInMaps(mode: String) {
        let coordinate = CLLocationCoordinate2D(latitude: result.placeResponse?.latitude ?? 0, longitude: result.placeResponse?.longitude ?? 0)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = result.title
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: mode])
    }
    
    private func toggleFavorite() {
        Task {
            if cacheManager.cachedPlaces(contains: result.title) {
                try? await SearchSavedViewModel.shared.removeSelectedItem(selectedSavedResult: result.id, cacheManager: cacheManager, modelController: modelController)
            } else {
                await SearchSavedViewModel.shared.addPlace(parent: result.id, rating: 5.0, cacheManager: cacheManager, modelController: modelController)
                pulseHeart()
            }
        }
    }
    
    private func pulseHeart() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            heartPulsing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) {
                heartPulsing = false
            }
        }
    }
}

struct InteractiveRatingView: View {
    @Binding var rating: Int
    let onRatingChanged: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(index <= rating ? .yellow : .secondary.opacity(0.5))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            rating = index
                        }
                        onRatingChanged(index)
                    }
            }
        }
    }
}

struct RelatedPlaceCard: View {
    let result: ChatResult
    var body: some View {
        VStack(alignment: .leading) {
            if let firstPhoto = result.placeDetailsResponse?.photoResponses?.first {
                AsyncImage(url: firstPhoto.photoUrl()) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.secondary.opacity(0.1))
                }
                .frame(width: 140, height: 90)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 140, height: 90)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            
            Text(result.title)
                .font(.caption.bold())
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        .frame(width: 140)
    }
}

struct RatingView: View {
    let rating: Float
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(.headline)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.yellow.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    var active: Bool = true
    let action: () -> Void
    
    var body: some View {
        Group {
            if active {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
            Text(label)
                .font(.caption2.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .foregroundStyle(.primary)
    }
}

struct DetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FlowLayout<T: Hashable, V: View>: View {
    let items: [T]
    let view: (T) -> V
    @State private var totalHeight = CGFloat.zero
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                self.view(item)
                    .padding([.horizontal, .vertical], 4)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}
