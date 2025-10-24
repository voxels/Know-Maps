//
//  AssistiveChatHost.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 3/21/23.
//

import SwiftUI
import NaturalLanguage
@preconcurrency import CoreLocation
import CoreML
import Segment


public typealias AssistiveChatHostTaggedWord = [String: [String]]

public final class AssistiveChatHostService : AssistiveChatHost {
    public let analyticsManager:AnalyticsService
    public enum Intent : String, Sendable {
        case Search
        case Place
        case AutocompleteTastes
        case Location
    }
    
    public let messagesDelegate:AssistiveChatHostMessagesDelegate
    public let placeSearchSession = PlaceSearchSession()

    public let queryIntentParameters:AssistiveChatHostQueryParameters
    public let categoryCodes:[[String:[[String:String]]]]
    
    private let geocoder = CLGeocoder()
    
    required public init(analyticsManager:AnalyticsService, messagesDelegate: AssistiveChatHostMessagesDelegate) {
        self.analyticsManager = analyticsManager
        self.messagesDelegate = messagesDelegate
        self.queryIntentParameters = AssistiveChatHostQueryParameters()
        do {
            categoryCodes = try AssistiveChatHostService.organizeCategoryCodeList()
        }catch {
            categoryCodes = []
            analyticsManager.trackError(error: error, additionalInfo: nil)
        }
    }
    
    static func organizeCategoryCodeList() throws -> [[String:[[String:String]]]] {
        var retval = Set<[String:[[String:String]]]>()

        if let path = Bundle.main.path(forResource: "integrated_category_taxonomy", ofType: "json")
        {
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
            return finalArray
        }
        return Array(retval)
    }
    
    public func determineIntent(for caption:String, override:Intent? = nil) -> Intent
    {
        if let override = override {
            return override
        }
        let lower = caption.lowercased()
        // Quick location check first
        if override == .Location {
            return .Location
        }
        // Extract tags from our ML + NLTagger pipeline
        let tagDict = (try? tags(for: caption)) ?? nil
        // Helpers to inspect tag values
        let containsTag: (String) -> Bool = { tag in
            guard let tagDict = tagDict else { return false }
            for values in tagDict.values {
                if values.contains(tag) { return true }
            }
            return false
        }
        // Place intent if we clearly have a place entity
        if containsTag("PLACE") || containsTag("PlaceName") {
            return .Place
        }
        // Taste/category intent for autocompletion of categories
        if containsTag("TASTE") || containsTag("CATEGORY") {
            return .AutocompleteTastes
        }
        // Heuristics based on words
        if lower.contains("near ") || lower.contains("around ") || lower.contains("close to ") {
            return .Location
        }
        if lower.contains("category") || lower.contains("type of") || lower.contains("kinds of") {
            return .AutocompleteTastes
        }
        // Fallback to search
        return .Search
    }
    
    public func defaultParameters(for query:String, filters:[String:Any]) async throws -> [String:Any]? {
        var radius:Double = 20000
        var open:Bool? = nil
        
        if let filterDistance = filters["distance"] as? Double {
            radius = filterDistance * 1000
        }
        
        if let openNow = filters["open_now"] as? Bool {
            open = openNow
        }
        
        let emptyParameters =
                """
                    {
                        "query":"",
                        "parameters":
                        {
                             "radius":\(radius),
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
                                
                if let minPrice = minPrice(for: query) {
                    rawParameters["min_price"] = minPrice
                }
                
                if let maxPrice = maxPrice(for: query) {
                    rawParameters["max_price"] = maxPrice
                }
                
                if let openAt = openAt(for: query) {
                    rawParameters["open_at"] = openAt
                }
                
                if let openNow = open {
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
    
    public func updateLastIntent(caption:String, selectedDestinationLocation:LocationResult, filters:[String:Any], modelController:ModelController) async throws {
        if  let lastIntent = queryIntentParameters.queryIntents.last {
            let queryParameters = try await defaultParameters(for: caption, filters:filters)
            let intent = determineIntent(for: caption)
            let newIntent = AssistiveChatHostIntent(caption: caption, intent:intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocation: selectedDestinationLocation, placeDetailsResponses: lastIntent.placeDetailsResponses, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, relatedPlaceSearchResponses: lastIntent.relatedPlaceSearchResponses, queryParameters: queryParameters)
            await updateLastIntentParameters(intent: newIntent, modelController: modelController)
        }
    }
    
    public func updateLastIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        queryIntentParameters.queryIntents.append(intent)
        await messagesDelegate.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    public func appendIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        
        queryIntentParameters.queryIntents.append(intent)

        await messagesDelegate.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    public func resetIntentParameters() {
        queryIntentParameters.queryIntents = [AssistiveChatHostIntent]()
    }
    
    public func receiveMessage(caption:String, isLocalParticipant:Bool, filters:[String:Any], modelController:ModelController, overrideIntent: AssistiveChatHostService.Intent? = nil, selectedDestinationLocation: LocationResult? = nil ) async throws {
        try await messagesDelegate.addReceivedMessage(caption: caption, parameters: queryIntentParameters, isLocalParticipant: isLocalParticipant, filters: filters, modelController: modelController, overrideIntent: overrideIntent, selectedDestinationLocation: selectedDestinationLocation)
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
        
        guard !title.isEmpty else {
            return .topPicks
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
            return .topPicks
        }
        
        retval = PersonalizedSearchSection(rawValue: predictedSection.capitalized) ?? .topPicks
        
        return retval!
    }
    
    public func section(place:String)->PersonalizedSearchSection {
        return .topPicks
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
        // Use a task group to process categories concurrently
        return await withTaskGroup(of: [String].self, returning: [String]?.self) { taskGroup in
            let query = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            var NAICSCodes = [String]()
            
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

