//
//  LanguageGenerator.swift
//  No Maps
//
//  Created by Michael A Edgcumbe on 4/3/23.
//

import Foundation

public protocol LanguageGeneratorDelegate {
    func placeDescription(chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws
    func placeDescription(with description:String, chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async
}


open class LanguageGenerator : LanguageGeneratorDelegate {
    private var session:LanguageGeneratorSession = LanguageGeneratorSession()
    
    public func placeDescription(with description:String, chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async {
        await delegate.willReceiveStreamingResult(for: chatResult.id)
        await delegate.didReceiveStreamingResult(with: description, for: chatResult, promptTokens: 0, completionTokens: 0)
        await delegate.didFinishStreamingResult()

    }
    
    public func placeDescription(chatResult: ChatResult, delegate: AssistiveChatHostStreamResponseDelegate) async throws {
        await delegate.willReceiveStreamingResult(for: chatResult.id)
        
            if let tips = chatResult.placeDetailsResponse?.tipsResponses, tips.count > 0, let name = chatResult.placeResponse?.name {
                let tipsText = tips.compactMap { response in
                    return response.text
                }
                
                try? await fetchTipsSummary(with:name,tips:tipsText, chatResult: chatResult,delegate: delegate)
                await delegate.didFinishStreamingResult()
                return
            }
            
            if let tastes = chatResult.placeDetailsResponse?.tastes, tastes.count > 0, let name = chatResult.placeResponse?.name  {
                try? await fetchTastesSummary(with: name, tastes: tastes, chatResult: chatResult, delegate: delegate)
            }
        
        await delegate.didFinishStreamingResult()
    }

    
    
    public func fetchTastesSummary(with placeName:String, tastes:[String], chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws{
        var prompt = "Write a description of \(placeName) that is known for "
        for taste in tastes {
            prompt.append(" \(taste),")
        }
        prompt.append("\(placeName) is")
        let request = LanguageGeneratorRequest(chatResult: chatResult, model: "gpt-4-turbo-preview", prompt: prompt, maxTokens: 200, temperature: 0, stop: nil, user: nil)
        guard let dict = try await session.query(languageGeneratorRequest: request, delegate: delegate) else {
            return
        }
        if let choicesArray = dict["choices"] as? [NSDictionary], let choices = choicesArray.first {
            if let message = choices["message"] as? [String:String] {
                if let content = message["content"] {
                    var promptTokens = 0
                    var completionTokens = 0
                    if let usageDict = dict["usage"] as? NSDictionary {
                        if let prompt = usageDict["prompt_tokens"] as? Int {
                            promptTokens = prompt
                        }
                        
                        if let completion = usageDict["completion_tokens"] as? Int {
                            completionTokens = completion
                        }
                    }
                    await delegate.didReceiveStreamingResult(with: content, for: chatResult, promptTokens: promptTokens, completionTokens: completionTokens)
                }
            }
        }
    }
    
    public func fetchTipsSummary(with placeName:String, tips:[String], chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws {
        if tips.count == 1, let firstTip = tips.first {
            await delegate.didReceiveStreamingResult(with: firstTip, for:chatResult, promptTokens: 0, completionTokens: 0)
            return
        }
        
        var prompt = "Combine these reviews into an honest description:"
        for tip in tips {
            prompt.append("\n\(tip)")
        }
        prompt.append("\(placeName) is")
        let request = LanguageGeneratorRequest(chatResult: chatResult, model: "gpt-4-turbo-preview", prompt: prompt, maxTokens: 200, temperature: 0, stop: nil, user: nil)
        guard let dict = try await session.query(languageGeneratorRequest: request, delegate: delegate) else {
            return
        }
        if let choicesArray = dict["choices"] as? [NSDictionary], let choices = choicesArray.first {
            if let message = choices["message"] as? [String:String] {
                if let content = message["content"] {
                    var promptTokens = 0
                    var completionTokens = 0
                    if let usageDict = dict["usage"] as? NSDictionary {
                        if let prompt = usageDict["prompt_tokens"] as? Int {
                            promptTokens = prompt
                        }
                        
                        if let completion = usageDict["completion_tokens"] as? Int {
                            completionTokens = completion
                        }
                    }

                    
                    await delegate.didReceiveStreamingResult(with: content, for: chatResult, promptTokens: promptTokens, completionTokens: completionTokens)
                }
            }
        }
    }
}
