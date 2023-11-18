//
//  AssistiveChatHost.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/21/23.
//

import UIKit
import NaturalLanguage
import CoreLocation
import CoreML

typealias AssistiveChatHostTaggedWord = [String: [String]]

public protocol ChatHostingViewControllerDelegate : AnyObject {
    func didTap(chatResult:ChatResult)
}

public protocol AssistiveChatHostStreamResponseDelegate {
    func didReceiveStreamingResult(with string:String, for result:ChatResult)
}

public class AssistiveChatHostIntent : Equatable {
    public let uuid = UUID()
    public let caption:String
    public let intent:AssistiveChatHost.Intent
    public var selectedPlaceSearchResponse:PlaceSearchResponse?
    public var selectedPlaceSearchDetails:PlaceDetailsResponse?
    public var placeSearchResponses:[PlaceSearchResponse]
    
    public var placeDetailsResponses:[PlaceDetailsResponse]?
    public let queryParameters:[String:Any]?
    
    public init(caption: String, intent: AssistiveChatHost.Intent, selectedPlaceSearchResponse: PlaceSearchResponse?, selectedPlaceSearchDetails: PlaceDetailsResponse?, placeSearchResponses: [PlaceSearchResponse], placeDetailsResponses:[PlaceDetailsResponse]?, queryParameters: [String : Any]?) {
        self.caption = caption
        self.intent = intent
        self.selectedPlaceSearchResponse = selectedPlaceSearchResponse
        self.selectedPlaceSearchDetails = selectedPlaceSearchDetails
        self.placeSearchResponses = placeSearchResponses
        self.placeDetailsResponses = placeDetailsResponses
        self.queryParameters = queryParameters
    }
    
    public static func == (lhs: AssistiveChatHostIntent, rhs: AssistiveChatHostIntent) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

public protocol AssistiveChatHostMessagesDelegate : AnyObject {
    func didTap(chatResult:ChatResult, selectedPlaceSearchResponse:PlaceSearchResponse?, selectedPlaceSearchDetails:PlaceDetailsResponse?)
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, nearLocation:CLLocation) async throws
    func didUpdateQuery(with parameters:AssistiveChatHostQueryParameters, nearLocation:CLLocation)
}

open class AssistiveChatHost : AssistiveChatHostDelegate, ChatHostingViewControllerDelegate, ObservableObject {
    
    public enum Intent : String {
        case Unsupported
        case SearchDefault
        case TellDefault
        case SearchQuery
        case TellPlace
        case ShareResult
    }
    
    weak public var messagesDelegate:AssistiveChatHostMessagesDelegate?
    public var languageDelegate:LanguageGeneratorDelegate = LanguageGenerator()
    public var placeSearchSession = PlaceSearchSession()
    @Published public var queryIntentParameters = AssistiveChatHostQueryParameters()
    public var categoryCodes:[String:String] = [String:String]()
    
    required public init(delegate:AssistiveChatHostMessagesDelegate? = nil) {
        self.messagesDelegate = delegate
        
        _ = Task.init{
            do {
                try organizeCategoryCodeList()
            } catch {
                print(error)
            }
        }
    }
    
    internal func organizeCategoryCodeList() throws {
        if let path = Bundle.main.path(forResource: "integrated_category_taxonomy", ofType: "json")
        {
            let url = URL(filePath: path)
            let data = try Data(contentsOf: url)
            let result = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            if let dict = result as? NSDictionary {
                for key in dict.allKeys {
                    if let valueDict = dict[key] as? NSDictionary {
                        if let labelsDict = valueDict["labels"] as? NSDictionary, let englishLabel = labelsDict["en"] as? String, let keyString = key as? String {
                            categoryCodes[englishLabel.lowercased()] = keyString
                        }
                    }
                }
            }
        }
    }
    
    public func didTap(chatResult: ChatResult) {
        print("Did tap result:\(chatResult.title) for place:")
        messagesDelegate?.didTap(chatResult: chatResult, selectedPlaceSearchResponse: chatResult.placeResponse, selectedPlaceSearchDetails:chatResult.placeDetailsResponse)
    }
    
    
    public func determineIntent(for caption:String, placeSearchResponse:PlaceSearchResponse?) throws -> Intent
    {
        if caption == "Where can I find" {
            return .SearchDefault
        }
        
        if caption == "Tell me about" {
            return .TellDefault
        }
        
        
        let mlModel = try LocalMapsQueryClassifier(configuration: MLModelConfiguration()).model
        let predictor = try NLModel(mlModel: mlModel)
        var predictedLabel:Intent = .Unsupported
        if let label = predictor.predictedLabel(for: caption), let intent = Intent(rawValue: label) {
            predictedLabel = intent
        }
        
        return predictedLabel
    }
    
    public func defaultParameters(for query:String) async throws -> [String:Any]? {
        let emptyParameters =
                """
                    {
                        "query":"",
                        "parameters":
                        {
                             "radius":3000,
                             "sort":"distance",
                             "limit":20,
                        }
                    }
                """
        
        guard let data = emptyParameters.data(using: .utf8) else {
            print("Empty parameters could not be encoded into json: \(emptyParameters)")
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            if let encodedEmptyParameters = json as? [String:Any] {
                var encodedParameters = encodedEmptyParameters
                
                guard var rawParameters = encodedParameters["parameters"] as? [String:Any] else {
                    return encodedParameters
                }
                
                let tags = try tags(for: query)
                
                if let radius = radius(for: query) {
                    rawParameters["radius"] = radius
                }
                
                if let minPrice = minPrice(for: query) {
                    rawParameters["min_price"] = minPrice
                }
                
                if let maxPrice = maxPrice(for: query) {
                    rawParameters["max_price"] = maxPrice
                }
                
                if let nearLocation = nearLocation(for: query, tags: tags) {
                    rawParameters["near"] = nearLocation
                }
                
                if let openAt = openAt(for: query) {
                    rawParameters["open_at"] = openAt
                }
                
                if let openNow = openNow(for: query) {
                    rawParameters["open_now"] = openNow
                }
                
                if let categories = categories(for: query, tags: tags) {
                    rawParameters["categories"] = categories
                }
                                
                encodedParameters["query"] = parsedQuery(for: query, tags: tags)
                encodedParameters["parameters"] = rawParameters
                print("Parsed Default Parameters:")
                print(encodedParameters)
                return encodedParameters
            } else {
                print("Found non-dictionary object when attemting to refresh parameters:\(json)")
                return nil
            }
        } catch {
            print(error)
            return nil
        }
    }
    
    public func appendIntentParameters(intent:AssistiveChatHostIntent) {
        queryIntentParameters.queryIntents.append(intent)
    }
    
    public func resetIntentParameters() {
        queryIntentParameters.queryIntents = [AssistiveChatHostIntent]()
    }
    
    public func receiveMessage(caption:String, isLocalParticipant:Bool, nearLocation:CLLocation ) async throws {
        try await messagesDelegate?.addReceivedMessage(caption: caption, parameters: queryIntentParameters, isLocalParticipant: isLocalParticipant, nearLocation: nearLocation)
        messagesDelegate?.didUpdateQuery(with:queryIntentParameters, nearLocation: nearLocation)
    }
}

extension AssistiveChatHost {
    public func searchQueryDescription(nearLocation:CLLocation) async throws -> String {
        return try await languageDelegate.searchQueryDescription(nearLocation:nearLocation)
    }
    
    public func placeDescription(searchResponse:PlaceSearchResponse, detailsResponse:PlaceDetailsResponse, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        try await languageDelegate.placeDescription(searchResponse: searchResponse, detailsResponse: detailsResponse, delegate: delegate)
    }
    
    public func placeDescription(chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        try await languageDelegate.placeDescription(chatResult: chatResult, delegate: delegate)
    }
}

extension AssistiveChatHost {
    
    internal func tags(for rawQuery:String) throws ->AssistiveChatHostTaggedWord? {
        var retval:AssistiveChatHostTaggedWord = AssistiveChatHostTaggedWord()
        let mlModel = try LocalMapsQueryTagger(configuration: MLModelConfiguration()).model
        let customModel = try NLModel(mlModel: mlModel)
        let customTagScheme = NLTagScheme("LocalMapsQueryTagger")
        let customTagger = NLTagger(tagSchemes: [customTagScheme])
        customTagger.string = rawQuery
        customTagger.setModels([customModel], forTagScheme: customTagScheme)
        customTagger.enumerateTags(in: rawQuery.startIndex..<rawQuery.endIndex, unit: .word, scheme: customTagScheme, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            if let tag = tag {
                let key = String(rawQuery[tokenRange])
                if retval.keys.contains(key) {
                    var oldValues = retval[key]
                    oldValues?.append(tag.rawValue)
                    if let newValues = oldValues {
                        retval[key] = newValues
                    }
                } else {
                    retval[key] = [tag.rawValue]
                }
                print("\(rawQuery[tokenRange]): \(tag.rawValue)")
            }
            return true
        }
        
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = rawQuery
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let allowedTags: [NLTag] = [.personalName, .placeName, .organizationName, .noun, .adjective]
        
        tagger.enumerateTags(in: rawQuery.startIndex..<rawQuery.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, allowedTags.contains(tag) {
                let key = String(rawQuery[tokenRange])
                if retval.keys.contains(key) {
                    var oldValues = retval[key]
                    oldValues?.append(tag.rawValue)
                    if let newValues = oldValues {
                        retval[key] = newValues
                    }
                } else {
                    retval[key] = [tag.rawValue]
                }
                print("\(rawQuery[tokenRange]): \(tag.rawValue)")
            }

            return true
        }

        
        if retval.count > 0 {
            return retval
        }
        
        return nil
    }
    
    internal func parsedQuery(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil)->String {
        guard let tags = tags else { return rawQuery }
        
        var revisedQuery = ""
        var includedWords = Set<String>()
        
        for taggedWord in tags.keys {
            if let taggedValues = tags[taggedWord] {
                if taggedValues.contains("NONE"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }

                if taggedValues.contains("TASTE"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }

                if taggedValues.contains("CATEGORY"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }
                
                if taggedValues.contains("PLACE"), !taggedValues.contains("PlaceName"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }
                
                if taggedValues.contains("Noun"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }
                
                if taggedValues.contains("Adjective"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                    revisedQuery.append(" ")
                }
            }
        }
        print("Revised query")
        if revisedQuery.count == 0 {
            revisedQuery = rawQuery
        }
        revisedQuery = revisedQuery.trimmingCharacters(in: .whitespaces)
        print(revisedQuery)
        return revisedQuery
    }
    
    internal func radius(for rawQuery:String)->Int? {
        if rawQuery.contains("nearby") || rawQuery.contains("near me") {
            return 1000
        }
        
        return nil
    }
    
    internal func minPrice(for rawQuery:String)->Int? {
        if !rawQuery.contains("not expensive") && !rawQuery.contains("not that expensive") && rawQuery.contains("expensive") {
            return 3
        }
        
        return nil
    }
    
    internal func maxPrice(for rawQuery:String)->Int? {
        if rawQuery.contains("cheap") {
            return 2
        }
        
        if rawQuery.contains("not expensive") || rawQuery.contains("not that expensive") {
            return 3
        }
        
        return nil
    }
    
    internal func nearLocation(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil)->String? {
        return nil
    }
    
    internal func openAt(for rawQuery:String)->String? {
        return nil
    }
    
    internal func openNow(for rawQuery:String)->Bool? {
        if rawQuery.contains("open now") {
            return true
        }
        return nil
    }
        
    internal func categories(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil)->[String]? {
        
        guard let naicsCode = categoryCodes[rawQuery] else {
            return nil
        }
        
        return [naicsCode]
    }
}
