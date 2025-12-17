//
//  LanguageGenerator.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 10/8/24.
//

public protocol LanguageGenerator {
    func placeDescription(chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async throws
    func placeDescription(with description:String, chatResult:ChatResult, delegate:AssistiveChatHostStreamResponseDelegate) async
}
