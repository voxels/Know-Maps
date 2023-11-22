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


public typealias AssistiveChatHostTaggedWord = [String: [String]]

public protocol ChatHostingViewControllerDelegate : AnyObject {
    func didTap(chatResult:ChatResult) async
}

public protocol AssistiveChatHostStreamResponseDelegate {
    func willReceiveStreamingResult(for chatResultID:ChatResult.ID) async
    func didReceiveStreamingResult(with string:String, for result:ChatResult) async
    func didFinishStreamingResult() async
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
    func didSearch(caption:String) async throws
    func didTap(placeChatResult:ChatResult) async throws
    func didTap(chatResult:ChatResult, selectedPlaceSearchResponse:PlaceSearchResponse?, selectedPlaceSearchDetails:PlaceDetailsResponse?) async
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool) async throws
    func didUpdateQuery(with parameters:AssistiveChatHostQueryParameters) async throws
    func updateLastIntentParameter(for placeChatResult:ChatResult) async throws
}

open class AssistiveChatHost : AssistiveChatHostDelegate, ChatHostingViewControllerDelegate, ObservableObject {
    
    public enum Intent : String {
        case Search
        case Autocomplete
    }
    
    weak public var messagesDelegate:AssistiveChatHostMessagesDelegate?
    public var languageDelegate:LanguageGeneratorDelegate = LanguageGenerator()
    public var placeSearchSession = PlaceSearchSession()
    @Published public var queryIntentParameters = AssistiveChatHostQueryParameters()
    public var categoryCodes:[[String:[[String:String]]]] = [[String:[[String:String]]]]()
    
    let geocoder = CLGeocoder()
    var lastGeocodedPlacemark:CLPlacemark?
    
    required public init(delegate:AssistiveChatHostMessagesDelegate? = nil) {
        self.messagesDelegate = delegate
        do {
            try organizeCategoryCodeList()
        } catch {
            print(error)
        }
    }
    
    public func organizeCategoryCodeList() throws {
        if let path = Bundle.main.path(forResource: "integrated_category_taxonomy", ofType: "json")
        {
            var retval = Set<[String:[[String:String]]]>()
            let url = URL(filePath: path)
            let data = try Data(contentsOf: url)
            let result = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            if let dict = result as? NSDictionary {
                for key in dict.allKeys as! [String] {
                    if let valueDict = dict[key] as? NSDictionary {
                        if let labelsDict = valueDict["full_label"] as? [String], let englishLabel = labelsDict.last, let parentCategory = labelsDict.first {
                            
                            let newCategoryDict = [parentCategory: [["category":englishLabel, "code":key]]]
                            
                            let candidate = retval.first { checkValue in
                                return checkValue.keys.contains(parentCategory)
                            }
                            
                            guard let candidate = candidate else {
                                retval.insert(newCategoryDict)
                                continue
                            }
                            
                            for key in candidate.keys {
                                if key == parentCategory {
                                    retval.remove(candidate)
                                    let values = candidate.values
                                    var allCategoryDicts = [[String:String]]()
                                    
                                    for value in values {
                                        allCategoryDicts.append(contentsOf: value)
                                    }
                                    for newCategoryDictValue in newCategoryDict.values {
                                        allCategoryDicts.append(contentsOf: newCategoryDictValue)
                                    }
                                    
                                    retval.insert([parentCategory : allCategoryDicts])
                                }
                            }
                        }
                    }
                }
            }
        
            var retvalArray = Array(retval)
            
            retvalArray = retvalArray.sorted(by: { codes, checkCodes in
                
                var alpha = false
                for codeKey in codes.keys {
                    for checkCodeKey in checkCodes.keys {
                        if codeKey < checkCodeKey {
                            alpha = true
                        }
                    }
                }
                
                return alpha
            })
            
            var finalArray = [[String:[[String:String]]]]()
            
            for codes in retvalArray {
                for key in codes.keys {
                    if let values = codes[key] {
                        let sortedValues = values.sorted { value, checkValue in
                            if let valueCategory = value["category"], let checkValueCategory = checkValue["category"] {
                                return valueCategory < checkValueCategory
                            } else {
                                return false
                            }
                        }
                        finalArray.append([key:sortedValues])
                    }
                }
            }
            
            categoryCodes = finalArray
        }
    }
    
    public func didTap(chatResult: ChatResult) async {
        print("Did tap result:\(chatResult.title) for place:")
        await messagesDelegate?.didTap(chatResult: chatResult, selectedPlaceSearchResponse: chatResult.placeResponse, selectedPlaceSearchDetails:chatResult.placeDetailsResponse)
    }
    
    
    public func determineIntent(for caption:String) -> Intent
    {
        let components = caption.components(separatedBy: "near")
        if let prefix = components.first {
            for code in categoryCodes {
                if code.keys.contains(prefix) {
                    return .Search
                }
                
                for values in code.values {
                    for value in values {
                        if value["category"] == caption.lowercased().trimmingCharacters(in: .whitespaces) {
                            return .Search
                        }
                    }
                }
            }
            
            if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: prefix) {
                return .Search
            }
        }
        
        if let lastCharacter = caption.last, lastCharacter.isWhitespace || lastCharacter.isPunctuation {
            return .Search
        }
        
        return .Autocomplete
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
                
                if let categories = categoryCodes(for: query, tags: tags) {
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
    
    @MainActor
    public func updateLastIntent(caption:String) async throws {
        if let lastIntent = queryIntentParameters.queryIntents.last {
            let queryParamters = try await defaultParameters(for: caption)
            let intent = determineIntent(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent:intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, placeDetailsResponses: lastIntent.placeDetailsResponses, queryParameters: queryParamters)
            updateLastIntentParameters(intent: newIntent)
        }
    }
    
    @MainActor
    public func updateLastIntentParameters(intent:AssistiveChatHostIntent) {
        if queryIntentParameters.queryIntents.count > 0 {
            queryIntentParameters.queryIntents.removeLast()
        }
        queryIntentParameters.queryIntents.append(intent)
    }
    
    @MainActor
    public func appendIntentParameters(intent:AssistiveChatHostIntent) {
        queryIntentParameters.queryIntents.append(intent)
    }
    
    @MainActor
    public func resetIntentParameters() {
        queryIntentParameters.queryIntents = [AssistiveChatHostIntent]()
    }
    
    public func receiveMessage(caption:String, isLocalParticipant:Bool ) async throws {
        try await messagesDelegate?.addReceivedMessage(caption: caption, parameters: queryIntentParameters, isLocalParticipant: isLocalParticipant)
    }
    
    public func nearLocation(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil) -> String? {
        guard rawQuery.contains("near") else {
            return nil
        }
        
        let components = rawQuery.lowercased().components(separatedBy: "near")
        
        guard let lastComponent = components.last else {
            return nil
        }
        
        guard lastComponent.count > 0 else {
            return nil
        }
        
        if let lastCharacter = lastComponent.last, lastCharacter.isLetter || lastCharacter.isWhitespace || lastCharacter.isPunctuation {
            return lastComponent
        }
        
        return nil
    }
    
    public func nearLocationCoordinate(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil) async throws -> CLLocation? {
        guard rawQuery.contains("near") else {
            return nil
        }
        
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
        
        let components = rawQuery.lowercased().components(separatedBy: "near")
        
        guard let lastComponent = components.last else {
            return nil
        }
        
        guard lastComponent.count > 0 else {
            return nil
        }
        
        let placemarks = try await geocoder.geocodeAddressString(lastComponent)
        lastGeocodedPlacemark = placemarks.first
        return placemarks.first?.location
    }
    
    public func tags(for rawQuery:String) throws ->AssistiveChatHostTaggedWord? {
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
    
    @objc func fireTimer() {
        print("Timer fired!")
    }
}

extension AssistiveChatHost {
    public func searchQueryDescription(nearLocation:CLLocation) async throws -> String {
        return try await languageDelegate.searchQueryDescription(nearLocation:nearLocation)
    }
    
    public func placeDescription(chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        try await languageDelegate.placeDescription(chatResult: chatResult, delegate: delegate)
    }
}

extension AssistiveChatHost {
    internal func parsedQuery(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil)->String {
        guard let tags = tags else { return rawQuery }
        
        var revisedQuery = [String]()
        var includedWords = Set<String>()
        
        for taggedWord in tags.keys {
            if let taggedValues = tags[taggedWord] {
                if taggedValues.contains("NONE"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("TASTE"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("CATEGORY"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("PLACE"), !taggedValues.contains("PlaceName"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("Noun"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("Adjective"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    print(taggedWord)
                    print(taggedValues)
                    print(taggedValues.count)
                    revisedQuery.append(taggedWord)
                }
            }
        }
        print("Revised query")
        
        var parsedQuery = ""
        let rawQueryComponents = rawQuery.components(separatedBy: .whitespacesAndNewlines)
        for component in rawQueryComponents {
            if revisedQuery.contains(component) {
                parsedQuery.append(component)
                parsedQuery.append(" ")
            }
            
            if component.contains(where: { character in
                character.isPunctuation
            }) {
                parsedQuery.append(component)
                parsedQuery.append(" ")
            }
        }
        
        
        parsedQuery = parsedQuery.trimmingCharacters(in: .whitespaces)
        if parsedQuery.count == 0 {
            parsedQuery = rawQuery
        }
        
        let locationComponents = parsedQuery.components(separatedBy: "near")
        
        print(locationComponents.first ?? "")
        return locationComponents.first ?? parsedQuery
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
    
    internal func openAt(for rawQuery:String)->String? {
        return nil
    }
    
    internal func openNow(for rawQuery:String)->Bool? {
        if rawQuery.contains("open now") {
            return true
        }
        return nil
    }
    
    
    internal func categoryCodes(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil)->[String]? {
        
        var query = rawQuery
        
        var NAICSCodes = [String]()
        
        let components = query.components(separatedBy: "near")
        if let prefix = components.first {
            query = prefix.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for categoryCode in self.categoryCodes {
            let candidateKeys = categoryCode.keys.filter { key in
                return rawQuery.contains(key)
            }
            
            if candidateKeys.isEmpty {
                return nil
            } else {
                
                let candidates = categoryCode.filter { categoryDict in
                    let key = categoryDict.key
                    return candidateKeys.contains(key)
                }
                
                for candidate in candidates.values {
                    for values in candidate {
                        if let code = values["code"] {
                            NAICSCodes.append(code)
                        }
                    }
                }
            }
        }
        
        return NAICSCodes
    }
}
