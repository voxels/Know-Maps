//
//  AssistiveChatHostMessagesDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/30/23.
//

import Foundation
import Segment

public protocol AssistiveChatHostMessagesDelegate : AnyObject, Sendable {
    func addReceivedMessage(caption:String, parameters:AssistiveChatHostQueryParameters, isLocalParticipant:Bool, filters:[String:AnyObject], modelController:ModelController, overrideIntent: AssistiveChatHostService.Intent?, selectedDestinationLocation: LocationResult?) async throws
    func updateQueryParametersHistory(with parameters: AssistiveChatHostQueryParameters, modelController:ModelController) async // This is fine
}
