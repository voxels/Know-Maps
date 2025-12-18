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
import ConcurrencyExtras

public typealias AssistiveChatHostTaggedWord = [String: [String]]

@MainActor
public final class AssistiveChatHostService : AssistiveChatHost {
    
    public let analyticsManager:AnalyticsService
    public enum Intent : String, Sendable {
        case Search
        case Place
        case AutocompleteTastes
        case Location
        case Define
    }
    
    public let messagesDelegate:AssistiveChatHostMessagesDelegate
    public let placeSearchSession = PlaceSearchSession()

    public let queryIntentParameters:AssistiveChatHostQueryParameters
    public let categoryCodes:[[String:[[String:String]]]]
    
    private let geocoder = CLGeocoder()
    
    // MARK: - Foundation Models Integration
    private let intentClassifier: FoundationModelsIntentClassifier
    private let vectorService: VectorEmbeddingService
    
    required public init(analyticsManager:AnalyticsService, messagesDelegate: AssistiveChatHostMessagesDelegate) {
        self.analyticsManager = analyticsManager
        self.messagesDelegate = messagesDelegate
        self.queryIntentParameters = AssistiveChatHostQueryParameters()
        self.intentClassifier = FoundationModelsIntentClassifier()
        self.vectorService = VectorEmbeddingService()
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
    
    public func determineIntentEnhanced(for caption: String, override: AssistiveChatHostService.Intent? = nil) async throws -> AssistiveChatHostService.Intent {
        if let override = override {
            return override
        }
        
        // Detect 'Define' or 'Track' for dynamic taxonomy
        let lowerCaption = caption.lowercased()
        if lowerCaption.hasPrefix("define ") || lowerCaption.hasPrefix("track ") {
            return .Define
        }
        
        // Use Foundation Models classifier
        let unifiedIntent = try await intentClassifier.classify(query: caption)
        
        // Map UnifiedSearchIntent.SearchType to existing Intent enum
        switch unifiedIntent.searchType {
        case .category:
            return .Search
        case .taste:
            return .AutocompleteTastes
        case .place:
            return .Place
        case .location:
            return .Location
        case .mixed:
            // For mixed intents, prefer Search as it's most flexible
            return .Search
        }
    }
    
    public func defaultParameters(for query:String, filters:[String:String]) async throws -> [String:String]? {
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
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            if let encodedEmptyParameters = json as? [String:String] {
                var encodedParameters = encodedEmptyParameters
                var typedParameters = [String: String]()
                
                if var rawParameters = encodedParameters["parameters"] as? [String:String] {
                    if let tags = try tags(for: query) {
                        var tagsString = ""
                        for tag in tags.keys {
                            tagsString.append("\(tag),")
                        }
                        rawParameters["tags"] = tagsString
                        
                        if let categories = await categoryCodes(for: query, tags: tags) {
                            rawParameters["categories"] = categories.joined(separator: ",")
                        }
                    }
                                    
                    if let minPrice = minPrice(for: query) {
                        rawParameters["min_price"] = String(describing: minPrice)
                    }
                    
                    if let maxPrice = maxPrice(for: query) {
                        rawParameters["min_price"] = String(describing: maxPrice)
                    }
                    
                    if let openAt = openAt(for: query) {
                        rawParameters["open_at"] = "\(openAt)"
                    }
                    
                    if let openNow = open {
                        rawParameters["open_now"] = "\(openNow)"
                    }
                    

                    let section = section(for: query).rawValue
                    rawParameters["section"] = "\(section)"

                    return rawParameters
                }
                else {
                    return encodedParameters
                }
                
            } else {
                return nil
            }
        } catch {
            analyticsManager.trackError(error:error, additionalInfo:nil)
            return nil
        }
    }
    
    @MainActor
    public func updateLastIntent(caption:String, selectedDestinationLocation:LocationResult, filters:Dictionary<String, String>, modelController:ModelController) async throws {
        if  let lastIntent = queryIntentParameters.queryIntents.last {
            let queryParameters = try await defaultParameters(for: caption, filters:filters)
            let intent = try await determineIntentEnhanced(for: caption)
            let newIntent = await AssistiveChatHostIntent(caption: caption, intent:intent, selectedPlaceSearchResponse: lastIntent.selectedPlaceSearchResponse, selectedPlaceSearchDetails: lastIntent.selectedPlaceSearchDetails, placeSearchResponses: lastIntent.placeSearchResponses, selectedDestinationLocation: selectedDestinationLocation, placeDetailsResponses: lastIntent.placeDetailsResponses, recommendedPlaceSearchResponses: lastIntent.recommendedPlaceSearchResponses, relatedPlaceSearchResponses: lastIntent.relatedPlaceSearchResponses, queryParameters: queryParameters)
            await updateLastIntentParameters(intent: newIntent, modelController: modelController)
        }
    }
    
    @MainActor
    public func updateLastIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        queryIntentParameters.queryIntents.append(intent)
        await messagesDelegate.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    @MainActor
    public func appendIntentParameters(intent:AssistiveChatHostIntent, modelController:ModelController) async {
        
        queryIntentParameters.queryIntents.append(intent)

        await messagesDelegate.updateQueryParametersHistory(with:queryIntentParameters, modelController: modelController)
    }
    
    @MainActor
    public func resetIntentParameters() {
        queryIntentParameters.queryIntents = [AssistiveChatHostIntent]()
    }
    
    public func receiveMessage(caption:String, isLocalParticipant:Bool, filters:Dictionary<String, String>, modelController:ModelController, overrideIntent: AssistiveChatHostService.Intent? = nil, selectedDestinationLocation: LocationResult? = nil ) async throws {
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

extension AssistiveChatHostService {
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
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("Noun"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                }
                
                if taggedValues.contains("Adjective"), !includedWords.contains(taggedWord) {
                    includedWords.insert(taggedWord)
                    revisedQuery.append(taggedWord)
                }
            }
        }
        
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
        let finalString = locationComponents.first ?? parsedQuery
        return finalString
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
    
    // MARK: - Semantic Re-ranking
    
    /// Re-ranks place search responses using semantic similarity
    /// - Parameters:
    ///   - query: The original search query
    ///   - responses: Array of place search responses to rank
    ///   - semanticWeight: Weight for semantic score (0.0-1.0, default 0.7)
    /// - Returns: Re-ranked array of responses
    public func semanticRerank(
        query: String,
        responses: [PlaceSearchResponse],
        semanticWeight: Double = 0.7
    ) -> [PlaceSearchResponse] {
        guard !responses.isEmpty, !query.isEmpty else {
            return responses
        }
        
        let distanceWeight = 1.0 - semanticWeight
        
        // Build descriptions for each place
        let descriptions = responses.map { response in
            vectorService.buildPlaceDescription(
                name: response.name,
                categories: response.categories,
                description: nil
            )
        }
        
        // Calculate semantic scores
        let semanticScores = vectorService.batchSemanticScores(
            query: query,
            placeDescriptions: descriptions
        )

        // Combine scores and sort
        let paired: [(response: PlaceSearchResponse, semanticScore: Double)] = zip(responses, semanticScores).map { (response: PlaceSearchResponse, semanticScore: Double) in
            (response: response, semanticScore: semanticScore)
        }
        let rankedResults: [PlaceSearchResponse] = paired
            .sorted(by: { (a: (response: PlaceSearchResponse, semanticScore: Double),
                           b: (response: PlaceSearchResponse, semanticScore: Double)) -> Bool in
                return a.semanticScore > b.semanticScore
            })
            .map { $0.response }

        return rankedResults
    }
    
    /// Creates a new search intent from a generic ChatResult.
    /// This centralizes the logic for handling taps on different kinds of items.
    /// - Parameters:
    ///   - result: The `ChatResult` that was selected.
    ///   - filters: Any active search filters.
    ///   - selectedDestination: The current location to search near.
    /// - Returns: A fully configured `AssistiveChatHostIntent`.
    public func createIntent(
        for result: ChatResult,
        filters:Dictionary<String, String>,
        selectedDestination: LocationResult
    ) async throws -> AssistiveChatHostIntent {
        
        let caption = result.title
        let queryParameters = try await defaultParameters(for: caption, filters: filters)
        
        // If the result is a specific place, create a .Place intent.
        if let placeResponse = result.placeResponse {
            return await AssistiveChatHostIntent(
                caption: caption,
                intent: .Place,
                selectedPlaceSearchResponse: placeResponse,
                selectedPlaceSearchDetails: result.placeDetailsResponse,
                placeSearchResponses: [placeResponse],
                selectedDestinationLocation: selectedDestination,
                placeDetailsResponses: result.placeDetailsResponse != nil ? [result.placeDetailsResponse!] : nil,
                queryParameters: queryParameters
            )
        }
        
        // Otherwise, create a generic .Search intent.
        return await AssistiveChatHostIntent(caption: caption, intent: .Search, selectedPlaceSearchResponse: nil, selectedPlaceSearchDetails: nil, placeSearchResponses: [], selectedDestinationLocation: selectedDestination, placeDetailsResponses: nil, queryParameters: queryParameters)
    }
}

