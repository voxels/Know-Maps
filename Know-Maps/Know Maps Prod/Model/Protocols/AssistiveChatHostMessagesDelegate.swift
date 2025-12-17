//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import Segment
import ConcurrencyExtras

public protocol AssistiveChatHostMessagesDelegate : AnyObject, Sendable {
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, filters:Dictionary<String, String>, modelController:ModelController, overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters, modelController:ModelController) async // This is fine
}
