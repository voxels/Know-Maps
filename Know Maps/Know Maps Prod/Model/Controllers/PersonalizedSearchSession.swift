//
//  PersonalizedSearchSession.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 1/10/24.
//

import Foundation
import CloudKit
import NaturalLanguage

public enum PersonalizedSearchSessionError : Error {
    case UnsupportedRequest
    case ServerErrorMessage
    case NoUserFound
    case NoTokenFound
    case NoTasteFound
}

public enum PersonalizedSearchSection : String, Hashable, CaseIterable {
    case food = "Food"
    case drinks = "Drinks"
    case coffee = "Coffee"
    case shops = "Shopping"
    case arts = "Art"
    case outdoors = "Outdoors"
    case sights = "Sightseeing"
    case trending = "Trending places"
    case nextVenues = "Where to go next"
    case topPicks = "Popular places"
    case none = "All categories"
    
    public func key()->String {
        switch self {
        case .food:
            return "food"
        case .drinks:
            return "drinks"
        case .coffee:
            return "coffee"
        case .shops:
            return "shops"
        case .arts:
            return "arts"
        case .outdoors:
            return "outdoors"
        case .sights:
            return "sights"
        case .trending:
            return "trending"
        case .nextVenues:
            return "nextVenues"
        case .topPicks:
            return "topPicks"
        default:
            return "none"
        }
    }
    
    public func categoryResult()->CategoryResult {
        let chatResult = ChatResult(title: rawValue, placeResponse: nil, recommendedPlaceResponse: nil)
        let categoryResult = CategoryResult(parentCategory: rawValue, categoricalChatResults: [chatResult], section:self)
        return categoryResult
    }
}

open class PersonalizedSearchSession {
    public let cloudCache:CloudCache
    public var fsqIdentity:String?
    public var fsqAccessToken:String?
    private var fsqServiceAPIKey:String?
    let keysContainer = CKContainer(identifier:"iCloud.com.secretatomics.knowmaps.Keys")
    private var searchSession:URLSession?
    static let serverUrl = "https://api.foursquare.com/"
    static let userManagementAPIUrl = "v2/usermanagement"
    static let userManagementCreationPath = "/createuser"
    static let tasteSuggestionsAPIUrl = "v2/tastes/suggestions"
    static let venueRecommendationsAPIUrl = "v2/search/recommendations"
    static let autocompleteAPIUrl = "v2/search/autocomplete"
    static let autocompleteTastesAPIUrl = "v2/tastes/autocomplete"
    static let relatedVenueAPIUrl = "v2/venues/"
    static let relatedVenuePath = "/related"
    static let foursquareVersionDate = "20240101"
    
    public init(cloudCache: CloudCache, searchSession:URLSession? = nil) {
        self.cloudCache = cloudCache
        self.searchSession = searchSession
    }
    
    @discardableResult
    public func fetchManagedUserIdentity() async throws ->String? {
        let cloudFsqIdentity = try await cloudCache.fetchFsqIdentity()
        
        if cloudFsqIdentity.isEmpty {
            try await addFoursquareManagedUserIdentity()
            return try await fetchManagedUserIdentity()
        }
        
        fsqIdentity = cloudFsqIdentity
        
        return fsqIdentity
    }
    
    @discardableResult
    public func fetchManagedUserAccessToken() async throws ->String {
        guard cloudCache.hasPrivateCloudAccess else {
            return ""
        }
        
        if fsqIdentity == nil, cloudCache.hasPrivateCloudAccess {
            try await fetchManagedUserIdentity()
        }
        
        guard let fsqIdentity = fsqIdentity, !fsqIdentity.isEmpty else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
        
        let cloudToken = try await cloudCache.fetchToken(for: fsqIdentity)
        fsqAccessToken = cloudToken
        
        guard let token = fsqAccessToken, !token.isEmpty else {
            throw PersonalizedSearchSessionError.NoTokenFound
        }
        
        return token
    }
    
    @discardableResult
    public func addFoursquareManagedUserIdentity() async throws -> Bool {
        let apiKey = try await fetchFoursquareServiceAPIKey()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard let apiKey = apiKey, searchSession != nil else {
            return false
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.userManagementAPIUrl)\(PersonalizedSearchSession.userManagementCreationPath)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let userCreationResponse = try await fetch(url: url, apiKey: apiKey, httpMethod: "POST")
        
        guard let response = userCreationResponse as? [String:Any] else {
            return false
        }
        
        var identity:String? = nil
        var token:String? = nil
        
        if let responseDict = response["response"] as? NSDictionary {
            if let userId = responseDict["userId"] as? Int {
                identity = "\(userId)"
            }
            if let accessToken = responseDict["access_token"] as? String {
                token = accessToken
            }
        }
        
        guard let identity = identity, let token = token else {
            throw PersonalizedSearchSessionError.NoUserFound
        }
                
        cloudCache.storeFoursquareIdentityAndToken(for: identity, oauthToken: token)
        
        return true
    }

    public func autocompleteTastes(caption:String, parameters:[String:Any]?) async throws -> [String:Any] {
        
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        var limit = 50
        var nameString:String = ""
        
        if let parameters = parameters, let rawQuery = parameters["query"] as? String {
            nameString = rawQuery
        }
        
        if let parameters = parameters, let rawParameters = parameters["parameters"] as? NSDictionary {
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
        }
        
        var queryComponents = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.autocompleteTastesAPIUrl)")
        queryComponents?.queryItems = [URLQueryItem]()

        if nameString.count > 0 {
            let queryUrlItem = URLQueryItem(name: "query", value: nameString.trimmingCharacters(in: .whitespacesAndNewlines))
            queryComponents?.queryItems?.append(queryUrlItem)
        } else {
            let queryUrlItem = URLQueryItem(name: "query", value: caption)
            queryComponents?.queryItems?.append(queryUrlItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(limit)")
        queryComponents?.queryItems?.append(limitQueryItem)

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let tastesAutocompleteResponse = try await fetch(url: url, apiKey: apiKey, urlQueryItems: queryComponents?.queryItems)
        
        guard let response = tastesAutocompleteResponse as? [String:Any] else {
            return [String:Any]()
        }
                
        var retval = [String:Any]()
        if let responseDict = response["response"] as? [String:Any] {
            print(responseDict)
            retval = responseDict
        }

        return retval
    }
    
    public func autocomplete(caption:String, parameters:[String:Any]?, location:CLLocation) async throws -> [String:Any] {
        
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        let ll = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        var limit = 50
        var nameString:String = ""
        
        if let parameters = parameters, let rawQuery = parameters["query"] as? String {
            nameString = rawQuery
        } else {
            let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
            tagger.string = caption

            let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
            let tags: [NLTag] = [.personalName, .placeName, .organizationName, .noun, .adjective]


            tagger.enumerateTags(in: caption.startIndex..<caption.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
                // Get the most likely tag, and print it if it's a named entity.
                if let tag = tag, tags.contains(tag) {
                    print("\(caption[tokenRange]): \(tag.rawValue)")
                    nameString.append("\(caption[tokenRange]) ")
                }
                    
                // Get multiple possible tags with their associated confidence scores.
                let (hypotheses, _) = tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: .nameTypeOrLexicalClass, maximumCount: 1)
                print(hypotheses)
                    
               return true
            }
        }
        
        if let parameters = parameters, let rawParameters = parameters["parameters"] as? NSDictionary {
            
            if let rawLimit = rawParameters["limit"] as? Int {
                limit = rawLimit
            }
        }
        
        var queryComponents = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.autocompleteAPIUrl)")
        queryComponents?.queryItems = [URLQueryItem]()

        if nameString.count > 0 {
            let queryUrlItem = URLQueryItem(name: "query", value: nameString.trimmingCharacters(in: .whitespacesAndNewlines))
            queryComponents?.queryItems?.append(queryUrlItem)
        } else {
            let queryUrlItem = URLQueryItem(name: "query", value: caption)
            queryComponents?.queryItems?.append(queryUrlItem)
        }
        
        if ll.count > 0 {
            let locationQueryItem = URLQueryItem(name: "ll", value: ll)
            queryComponents?.queryItems?.append(locationQueryItem)
            
            var value = 2000
            if caption.contains("near") {
                value = 100000
            }
            let radiusQueryItem = URLQueryItem(name: "radius", value:"\(value)")
            queryComponents?.queryItems?.append(radiusQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(limit)")
        queryComponents?.queryItems?.append(limitQueryItem)

        guard let url = queryComponents?.url else {
            throw PlaceSearchSessionError.UnsupportedRequest
        }
        
        let placeSearchResponse = try await fetch(url: url, apiKey: apiKey, urlQueryItems: queryComponents?.queryItems)
        
        guard let response = placeSearchResponse as? [String:Any] else {
            return [String:Any]()
        }
                
        var retval = [String:Any]()
        if let responseDict = response["response"] as? [String:Any] {
            print(responseDict)
            retval = responseDict
        }

        return retval
    }
    
    public func fetchRecommendedVenues(with request:RecommendedPlaceSearchRequest, location:CLLocation?) async throws -> [String:Any]{
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard !apiKey.isEmpty, searchSession != nil else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        var components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.venueRecommendationsAPIUrl)")
        
        components?.queryItems = [URLQueryItem]()
        if request.query.count > 0 {
            let queryItem = URLQueryItem(name: "query", value: request.query)
            components?.queryItems?.append(queryItem)
        }
        
        if let location = location, request.nearLocation == nil {
            let rawLocation = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            let radius = request.radius
            let radiusQueryItem = URLQueryItem(name: "radius", value: "\(radius)")
            components?.queryItems?.append(radiusQueryItem)
            
            let locationQueryItem = URLQueryItem(name: "ll", value: rawLocation)
            components?.queryItems?.append(locationQueryItem)
        } else if let rawLocation = request.ll {
            let locationQueryItem = URLQueryItem(name: "ll", value: rawLocation)
            components?.queryItems?.append(locationQueryItem)
        }
        
        var value = request.radius
        if let nearLocation = request.nearLocation, !nearLocation.isEmpty {
            value = 25000
        }
        
        if let ll = request.ll, !ll.isEmpty {
            value = 25000
        }
        
        let radiusQueryItem = URLQueryItem(name: "radius", value: "\(value)")
        components?.queryItems?.append(radiusQueryItem)
        
        if let categories = request.categories {
            let categoriesQueryItem = URLQueryItem(name:"categoryId", value:categories)
            components?.queryItems?.append(categoriesQueryItem)
        }
        
        if request.minPrice > 1 {
            let minPriceQueryItem = URLQueryItem(name: "price", value: "\(request.minPrice)")
            components?.queryItems?.append(minPriceQueryItem)
        }

        if request.maxPrice < 4 {
            let maxPriceQueryItem = URLQueryItem(name: "price", value: "\(request.maxPrice)")
            components?.queryItems?.append(maxPriceQueryItem)

        }
        
        if request.openNow == true {
            let openNowQueryItem = URLQueryItem(name: "open_now", value: "true")
            components?.queryItems?.append(openNowQueryItem)
        }
        
        let limitQueryItem = URLQueryItem(name: "limit", value: "\(request.limit)")
        components?.queryItems?.append(limitQueryItem)
        
        let offsetQueryItem = URLQueryItem(name: "offset", value: "\(request.offset)")
        components?.queryItems?.append(offsetQueryItem)
        
        if request.section != .none {
            let sectionQueryItem = URLQueryItem(name: "section", value: request.section.key())
            components?.queryItems?.append(sectionQueryItem)
        }
        
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let response = try await fetch(url: url, apiKey: apiKey, urlQueryItems: components?.queryItems)
        
        guard let response = response as? [String:Any] else {
            throw PersonalizedSearchSessionError.NoTasteFound
        }
                        
        var retval = [String:Any]()
        if let responseDict = response["response"] as? [String:Any] {
            print(responseDict)
            retval = responseDict
        }

        return retval
    }
    
    public func fetchTastes(page:Int) async throws -> [String] {
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard !apiKey.isEmpty, searchSession != nil else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.tasteSuggestionsAPIUrl)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let intentQueryItem = URLQueryItem(name: "intent", value: "onboarding")
        let limitQueryItem = URLQueryItem(name: "limit", value: "50")
        let offsetQueryItem = URLQueryItem(name: "offset", value:"\(page)")
        let response = try await fetch(url: url, apiKey: apiKey, urlQueryItems: [intentQueryItem, limitQueryItem, offsetQueryItem])
        
        guard let response = response as? [String:Any] else {
            throw PersonalizedSearchSessionError.NoTasteFound
        }
                        
        var retval = [String]()
        if let responseDict = response["response"] as? NSDictionary {
            if let tastesArray = responseDict["tastes"] as? [NSDictionary] {
                for taste in tastesArray {
                    if let text = taste["text"] as? String {
                        retval.append(text)
                    }
                }
            }
        }

        return retval
    }
    
    public func fetchRelatedVenues(for fsqID:String) async throws -> [String:Any] {
        let apiKey = try await fetchManagedUserAccessToken()
        
        if searchSession == nil {
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            searchSession = session
        }
        
        guard !apiKey.isEmpty, searchSession != nil else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let components = URLComponents(string:"\(PersonalizedSearchSession.serverUrl)\(PersonalizedSearchSession.relatedVenueAPIUrl)\(fsqID)\(PersonalizedSearchSession.relatedVenuePath)")
        guard let url = components?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }
        
        let response = try await fetch(url: url, apiKey: apiKey)
        
        guard let response = response as? [String:Any] else {
            throw PersonalizedSearchSessionError.NoTasteFound
        }
                        
        var retval = [String:Any]()
        if let responseDict = response["response"] as? [String:Any] {
            retval = responseDict
        }

        return retval
    }

    private func fetchFoursquareServiceAPIKey() async throws -> String? {
        let task = Task.init { () -> Bool in
            let predicate = NSPredicate(format: "service == %@", "foursquareService")
            let query = CKQuery(recordType: "KeyString", predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.desiredKeys = ["value", "service"]
            operation.resultsLimit = 1
            operation.recordMatchedBlock = { [weak self] recordId, result in
                guard let strongSelf = self else { return }

                do {
                    let record = try result.get()
                    if let apiKey = record["value"] as? String {
                        print("\(String(describing: record["service"]))")
                        strongSelf.fsqServiceAPIKey = apiKey
                    } else {
                        print("Did not find API Key")
                    }
                } catch {
                    print(error)
                }
            }
            
            let success = try await withCheckedThrowingContinuation { checkedContinuation in
                operation.queryResultBlock = { result in
                    if self.fsqServiceAPIKey == nil {
                        checkedContinuation.resume(with: .success(false))
                    } else if let apiKey = self.fsqServiceAPIKey, !apiKey.isEmpty {
                        checkedContinuation.resume(with: .success(true))
                    } else {
                        checkedContinuation.resume(with: .success(false))
                    }
                }
                
                keysContainer.publicCloudDatabase.add(operation)
            }
            
            return success
        }
        
        
        let _ = try await task.value
        return fsqServiceAPIKey
    }
    
    internal func fetch(url:URL, apiKey:String, urlQueryItems:[URLQueryItem]? = nil, httpMethod:String = "GET") async throws -> Any {
        print("Requesting URL: \(url)")
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        let urlQueryItem = URLQueryItem(name: "v", value: PersonalizedSearchSession.foursquareVersionDate)
        var allQueryItems = [urlQueryItem]
        
        if let urlQueryItems = urlQueryItems {
            allQueryItems.append(contentsOf: urlQueryItems)
        }
        urlComponents?.queryItems = allQueryItems
        
        guard let queryUrl = urlComponents?.url else {
            throw PersonalizedSearchSessionError.UnsupportedRequest
        }

        var request = URLRequest(url:queryUrl)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = httpMethod
        
        let responseAny:Any = try await withCheckedThrowingContinuation({checkedContinuation in
            let dataTask = searchSession?.dataTask(with: request, completionHandler: { data, response, error in
                if let e = error {
                    print(e)
                    checkedContinuation.resume(throwing:e)
                } else {
                    if let d = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])
                            if let checkDict = json as? NSDictionary, let message = checkDict["message"] as? String, message.hasPrefix("Foursquare servers")  {
                                print("Message from server:")
                                print(message)
                                checkedContinuation.resume(throwing: PersonalizedSearchSessionError.ServerErrorMessage)
                            } else {
                                checkedContinuation.resume(returning:json)
                            }
                        } catch {
                            print(error)
                            let returnedString = String(data: d, encoding: String.Encoding.utf8) ?? ""
                            print(returnedString)
                            checkedContinuation.resume(throwing: PersonalizedSearchSessionError.ServerErrorMessage)
                        }
                    }
                }
            })
            
            dataTask?.resume()
        })
        
        return responseAny
    }
}
