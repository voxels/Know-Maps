//
//  LanguageGenerator.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/3/23.
//

import Foundation
import CoreLocation

public protocol LanguageGeneratorDelegate {
    func searchQueryDescription(nearLocation:CLLocation) async throws -> String
    func placeDescription(searchResponse:PlaceSearchResponse, detailsResponse:PlaceDetailsResponse, delegate:AssistiveChatHostStreamResponseDelegate) async throws
    func placeDescription(chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws
}


open class LanguageGenerator : LanguageGeneratorDelegate {
    
    private var session:LanguageGeneratorSession = LanguageGeneratorSession()
    
    public func searchQueryDescription(nearLocation:CLLocation) async throws -> String {
        let retval = "Sorted by distance"
        
        let placemark = await withUnsafeContinuation { continuation in
            lookUpLocation(location: nearLocation) { placemark in
                continuation.resume(returning: placemark)
            }
        }
        
        if let name = placemark?.name {
            return retval.appending(" from \(name):")
        } else {
            return retval.appending(":")
        }
    }
    
    public func placeDescription(searchResponse:PlaceSearchResponse, detailsResponse:PlaceDetailsResponse, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        
        let result = ChatResult(title: searchResponse.name, placeResponse: searchResponse, placeDetailsResponse: detailsResponse)
        
        if let tips = detailsResponse.tipsResponses, tips.count > 0 {
            let tipsText = tips.compactMap { response in
                return response.text
            }
            
            try await fetchTipsSummary(with:searchResponse.name,tips:tipsText, chatResult: result,delegate: delegate)
            return
        }
        
        if let tastes = detailsResponse.tastes, tastes.count > 0 {
            try await fetchTastesSummary(with: searchResponse.name, tastes: tastes, chatResult: result, delegate: delegate)
        }
    }
    
    public func placeDescription(chatResult: ChatResult, delegate: AssistiveChatHostStreamResponseDelegate) async throws {
        if let tips = chatResult.placeDetailsResponse?.tipsResponses, tips.count > 0, let name = chatResult.placeResponse?.name {
            let tipsText = tips.compactMap { response in
                return response.text
            }
            
            try await fetchTipsSummary(with:name,tips:tipsText, chatResult: chatResult,delegate: delegate)
            return
        }
        
        if let tastes = chatResult.placeDetailsResponse?.tastes, tastes.count > 0, let name = chatResult.placeResponse?.name  {
            try await fetchTastesSummary(with: name, tastes: tastes, chatResult: chatResult, delegate: delegate)
        }
    }

    
    
    public func fetchTastesSummary(with placeName:String, tastes:[String], chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws{
        var prompt = "Write a description of \(placeName) that is known for "
        for taste in tastes {
            prompt.append(" \(taste),")
        }
        prompt.append("\(placeName) is")
        let request = LanguageGeneratorRequest(chatResult: chatResult, model: "gpt-4-1106-preview", prompt: prompt, maxTokens: 200, temperature: 0, stop: nil, user: nil)
        guard let dict = try await session.query(languageGeneratorRequest: request, delegate: delegate) else {
            return
        }
        if let choicesArray = dict["choices"] as? [NSDictionary], let choices = choicesArray.first {
            if let message = choices["message"] as? [String:String] {
                if let content = message["content"] {
                    delegate.didReceiveStreamingResult(with: content, for: chatResult)
                }
            }
        }
    }
    
    public func fetchTipsSummary(with placeName:String, tips:[String], chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        if tips.count == 1, let firstTip = tips.first {
            delegate.didReceiveStreamingResult(with: firstTip, for:chatResult)
            return
        }
        
        var prompt = "Combine these reviews into an honest description:"
        for tip in tips {
            prompt.append("\n\(tip)")
        }
        prompt.append("\(placeName) is")
        let request = LanguageGeneratorRequest(chatResult: chatResult, model: "gpt-4-1106-preview", prompt: prompt, maxTokens: 200, temperature: 0, stop: nil, user: nil)
        guard let dict = try await session.query(languageGeneratorRequest: request, delegate: delegate) else {
            return
        }
        if let choicesArray = dict["choices"] as? [NSDictionary], let choices = choicesArray.first {
            if let message = choices["message"] as? [String:String] {
                if let content = message["content"] {
                    delegate.didReceiveStreamingResult(with: content, for: chatResult)
                }
            }
        }
    }
}

extension LanguageGenerator {
    func lookUpLocation(location:CLLocation, completionHandler: @escaping (CLPlacemark?)
                        -> Void ) {
        // Use the last reported location.
        let geocoder = CLGeocoder()
        
        // Look up the location and pass it to the completion handler
        geocoder.reverseGeocodeLocation(location,
                                        completionHandler: { (placemarks, error) in
            if error == nil {
                let firstLocation = placemarks?[0]
                completionHandler(firstLocation)
            }
            else {
                // An error occurred during geocoding.
                completionHandler(nil)
            }
        })
    }
}
