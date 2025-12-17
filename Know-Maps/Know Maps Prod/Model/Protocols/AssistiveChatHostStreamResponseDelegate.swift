//
//  AssistiveChatHostStreamResponseDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation

@MainActor
public protocol AssistiveChatHostStreamResponseDelegate : Sendable {
    func willReceiveStreamingResult(for chatResultID:ChatResult.ID) async
    func didReceiveStreamingResult(with string:String, for result:ChatResult, promptTokens:Int, completionTokens:Int) async
    func didFinishStreamingResult() async
}
