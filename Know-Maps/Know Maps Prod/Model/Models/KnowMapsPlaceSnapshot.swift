import Foundation

public struct KnowMapsPlaceSnapshot: Sendable, Hashable {
    public struct LocationContext: Sendable, Hashable {
        public let neighborhood: String?
        public let dma: String?
        public let locality: String?
        public let regionCode: String?
        public let countryCode: String?
        public let formattedAddress: String?
    }
    
    public let fsqID: String
    public let title: String
    public let referenceID: String
    public let concept: String?
    
    public let latitude: Double?
    public let longitude: Double?
    public let location: LocationContext
    
    public let summary: String?
    public let hoursText: String?
    public let tastes: [String]
    public let rating: Double?
    public let priceTier: Int?
    
    public let heroPhotoURL: String?
    public let photoURLs: [String]
    public let photoAspectRatio: Double?
    
    public init(
        fsqID: String,
        title: String,
        referenceID: String,
        concept: String?,
        latitude: Double?,
        longitude: Double?,
        location: LocationContext,
        summary: String?,
        hoursText: String?,
        tastes: [String],
        rating: Double?,
        priceTier: Int?,
        heroPhotoURL: String?,
        photoURLs: [String],
        photoAspectRatio: Double?
    ) {
        self.fsqID = fsqID
        self.title = title
        self.referenceID = referenceID
        self.concept = concept
        self.latitude = latitude
        self.longitude = longitude
        self.location = location
        self.summary = summary
        self.hoursText = hoursText
        self.tastes = tastes
        self.rating = rating
        self.priceTier = priceTier
        self.heroPhotoURL = heroPhotoURL
        self.photoURLs = photoURLs
        self.photoAspectRatio = photoAspectRatio
    }
}

public extension CategoryResult {
    var exportedParentCategory: String {
        parentCategory
    }
}

public extension ChatResult {
    func makePlaceSnapshot(concept: String?) -> KnowMapsPlaceSnapshot? {
        let fsqID = placeResponse?.fsqID
            ?? recommendedPlaceResponse?.fsqID
            ?? placeDetailsResponse?.fsqID
        
        guard let fsqID else { return nil }
        
        let resolvedTitle = placeResponse?.name
            ?? recommendedPlaceResponse?.name
            ?? title
        
        let latitude = placeResponse?.latitude ?? recommendedPlaceResponse?.latitude
        let longitude = placeResponse?.longitude ?? recommendedPlaceResponse?.longitude
        
        let location = KnowMapsPlaceSnapshot.LocationContext(
            neighborhood: recommendedPlaceResponse?.neighborhood,
            dma: placeResponse?.dma,
            locality: placeResponse?.locality ?? recommendedPlaceResponse?.city,
            regionCode: placeResponse?.region ?? recommendedPlaceResponse?.state,
            countryCode: placeResponse?.country ?? recommendedPlaceResponse?.country,
            formattedAddress: placeResponse?.formattedAddress ?? recommendedPlaceResponse?.formattedAddress
        )
        
        let summary = placeDetailsResponse?.description
            ?? placeResponse?.formattedAddress
            ?? recommendedPlaceResponse?.formattedAddress
        
        let hoursText = placeDetailsResponse?.hours
        let tastes = placeDetailsResponse?.tastes
            ?? recommendedPlaceResponse?.tastes
            ?? []
        
        let ratingValue: Double?
        if let detailsRating = placeDetailsResponse?.rating {
            ratingValue = Double(detailsRating)
        } else {
            ratingValue = rating
        }
        
        let heroPhoto = recommendedPlaceResponse?.photo
        let photos = recommendedPlaceResponse?.photos ?? []
        
        return KnowMapsPlaceSnapshot(
            fsqID: fsqID,
            title: resolvedTitle,
            referenceID: identity,
            concept: concept,
            latitude: latitude,
            longitude: longitude,
            location: location,
            summary: summary,
            hoursText: hoursText,
            tastes: tastes,
            rating: ratingValue,
            priceTier: placeDetailsResponse?.price,
            heroPhotoURL: heroPhoto,
            photoURLs: photos,
            photoAspectRatio: recommendedPlaceResponse?.aspectRatio.map { Double($0) }
        )
    }
}
