//
//  AssistiveChatHost.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/21/23.
//

import SwiftUI
import NaturalLanguage
import CoreLocation
import CoreML
import Segment


public typealias AssistiveChatHostTaggedWord = [String: [String]]

public final class AssistiveChatHostService : AssistiveChatHost {
    public let analyticsManager:AnalyticsService
    public enum Intent : String {
        case Search
        case Place
        case AutocompleteSearch
        case AutocompleteTastes
        case Location
    }
    
    weak public var messagesDelegate:AssistiveChatHostMessagesDelegate?
    public var placeSearchSession = PlaceSearchSession()

    public var queryIntentParameters:AssistiveChatHostQueryParameters?
    public var categoryCodes:[[String:[[String:String]]]] = [[String:[[String:String]]]]()
    
    let geocoder = CLGeocoder()
    public var lastGeocodedPlacemarks:[CLPlacemark]?
    
    required public init(analyticsManager:AnalyticsService, messagesDelegate: AssistiveChatHostMessagesDelegate? = nil, lastGeocodedPlacemarks: [CLPlacemark]? = nil) {
        self.analyticsManager = analyticsManager
        self.messagesDelegate = messagesDelegate
        self.lastGeocodedPlacemarks = lastGeocodedPlacemarks
        self.queryIntentParameters = AssistiveChatHostQueryParameters()
    }
    
    public func organizeCategoryCodeList() async throws {
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
                                if parentCategory != "Foursquare Places" {
                                    retval.insert(newCategoryDict)
                                }
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
                                    
                                    if !allCategoryDicts.isEmpty {
                                        retval.insert([parentCategory : allCategoryDicts])
                                    }
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
    
    public func determineIntent(for caption:String, override:Intent? = nil) -> Intent
    {
        let components = caption.components(separatedBy: "near")
        if let prefix = components.first {
            for code in categoryCodes {
                if code.keys.contains(prefix.capitalized) {
                    return .Search
                }
                
                for values in code.values {
                    for value in values {
                        if ((value["category"]?.lowercased().contains( caption.lowercased().trimmingCharacters(in: .whitespaces))) != nil) {
                            return .Search
                        }
                    }
                }
            }
            
            #if os(visionOS) || os(iOS)
            if UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: prefix) {
                return .Search
            }
            #endif
        }
                
        return .AutocompleteSearch
    }
    
    public func defaultParameters(for query:String) async throws -> [String:Any]? {
        let emptyParameters =
                """
                    {
                        "query":"",
                        "parameters":
                        {
                             "radius":20000,
                             "sort":"distance",
                             "limit":50,
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
                rawParameters["tags"] = tags
                
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
                
                if let categories = await categoryCodes(for: query, tags: tags) {
                    rawParameters["categories"] = categories
                }

                let section = section(for: query).rawValue
                rawParameters["section"] = section
                
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
            analyticsManager.trackError(error:error, additionalInfo:nil)
            return nil
        }
    }
    
    public func updateLastIntent(caption:String, selectedDestinationLocationID:LocationResult.ID, modelController:ModelController) async throws {
        if let queryIntentParameters = queryIntentParameters, let lastIntent = queryIntentParameters.queryIntents.last {
            let queryParamters = try await defaultParameters(for: caption)
            let intent = determineIntent(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent:intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocationID: selectedDestinationLocationID, placeDetailsResponses: lastIntent.placeDetailsResponses, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, queryParameters: queryParamters)
            await updateLastIntentParameters(intent: newIntent, modelController: modelController)
        }
    }
    
    public func updateLastIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        guard let queryIntentParameters = queryIntentParameters else {
            return
        }
        
        if queryIntentParameters.queryIntents.count > 0 {
            queryIntentParameters.queryIntents.removeLast()
        }
        queryIntentParameters.queryIntents.append(intent)
        await messagesDelegate?.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    public func appendIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        guard let queryIntentParameters = queryIntentParameters else {
            return
        }
        
        queryIntentParameters.queryIntents.append(intent)

        await messagesDelegate?.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    public func resetIntentParameters() {
        guard let queryIntentParameters = queryIntentParameters else {
            return
        }
        queryIntentParameters.queryIntents = [AssistiveChatHostIntent]()
    }
    
    public func receiveMessage(caption:String, isLocalParticipant:Bool, cacheManager:CacheManager, modelController:ModelController ) async throws {
        guard let queryIntentParameters = queryIntentParameters else {
            return
        }
        try await messagesDelegate?.addReceivedMessage(caption: caption, parameters: queryIntentParameters, isLocalParticipant: isLocalParticipant, cacheManager: cacheManager, modelController: modelController)
    }

    
    public func lastLocationIntent() -> AssistiveChatHostIntent? {
        return queryIntentParameters?.queryIntents.last(where: { intent in
            intent.intent == .Location
        })
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
            return lastComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    public func nearLocationCoordinate(for rawQuery:String, tags:AssistiveChatHostTaggedWord? = nil) async throws -> [CLPlacemark]? {
        
        if geocoder.isGeocoding {
            return lastGeocodedPlacemarks
        }
        
        let components = rawQuery.lowercased().components(separatedBy: "near")
        
        var addressString = rawQuery
        if let lastComponent = components.last {
            addressString = lastComponent
        }
        
        guard addressString.count > 0 else {
            return nil
        }
        
        let placemarks = try? await geocoder.geocodeAddressString(addressString)

        lastGeocodedPlacemarks  = placemarks
        return lastGeocodedPlacemarks
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

    
    public func section(for title: String) -> PersonalizedSearchSection {
        var retval = PersonalizedSearchSection(rawValue: title)
        if let retval = retval {
            return retval
        }
        
        var predictedSection: String = ""
        
        do {
            // Load the Core ML model
            let model = try FoursquareSectionClassifier(configuration: MLModelConfiguration())
            
            // Prepare the input for the model
            // Assuming your model accepts 'title' as an input feature
            let input = FoursquareSectionClassifierInput(text: title)
            
            // Make a prediction using the model
            let output = try model.prediction(input: input)
            
            predictedSection = output.label
            // Extract the predicted section from the model's output
            
        } catch {
            analyticsManager.trackError(error:error, additionalInfo:nil)
            return .none
        }
        
        retval = PersonalizedSearchSection(rawValue: predictedSection.capitalized) ?? PersonalizedSearchSection.none
        
        return retval!
    }
    
    public func section(place:String)->PersonalizedSearchSection {
        return .location
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
    
    
    internal func categoryCodes(for rawQuery: String, tags: AssistiveChatHostTaggedWord? = nil) async -> [String]? {
        let query = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var NAICSCodes = [String]()


        // Use a task group to process categories concurrently
        return await withTaskGroup(of: [String].self, returning: [String]?.self) { taskGroup in
            for categoryCode in self.categoryCodes {
                taskGroup.addTask {
                    let codes = await self.checkCategoriesAndSubcategories(categoryCode: categoryCode, query: query, embedding: NLEmbedding.sentenceEmbedding(for: .english)!)
                    return codes
                }
            }

            for await codes in taskGroup {
                NAICSCodes.append(contentsOf: codes)
            }

            // Remove duplicates
            NAICSCodes = Array(Set(NAICSCodes))

            return NAICSCodes.isEmpty ? nil : NAICSCodes
        }
    }
    
    func checkCategoriesAndSubcategories(categoryCode: [String: [[String: String]]], query: String, embedding: NLEmbedding) async -> [String] {
        var codes = [String]()

        await withTaskGroup(of: [String].self) { taskGroup in
            for (categoryName, subcategories) in categoryCode {
                // Check main category
                taskGroup.addTask {
                    var localCodes = [String]()
                    let categorySimilarity = query.lowercased() == categoryName.lowercased()
                    if categorySimilarity{
                        // Add all subcategory codes if main category matches
                        for subcategory in subcategories {
                            if let code = subcategory["code"] {
                                localCodes.append(code)
                            }
                        }
                    } else {
                        // Check subcategories
                        for subcategory in subcategories {
                            if let subcategoryName = subcategory["category"]?.lowercased() {
                                let subcategorySimilarity = query.lowercased() == subcategoryName.lowercased()
                                if subcategorySimilarity, let code = subcategory["code"] {
                                    print("Adding subcategory:\(subcategoryName)\t\(subcategorySimilarity)")
                                    localCodes.append(code)
                                }
                            }
                        }
                    }
                    return localCodes
                }
            }

            // Collect results from all tasks
            for await result in taskGroup {
                codes.append(contentsOf: result)
            }
        }

        return codes
    }
}
