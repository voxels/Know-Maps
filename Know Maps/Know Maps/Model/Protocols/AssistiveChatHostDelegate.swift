//
//  AssistiveChatHostDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/16/23.
//

import Foundation
import CoreLocation

public protocol AssistiveChatHostDelegate:AnyObject {
    
    var delegate:AssistiveChatHostMessagesDelegate? { get set}
    var languageDelegate:LanguageGeneratorDelegate { get }
    var placeSearchSession:PlaceSearchSession { get }
    var queryIntentParameters:AssistiveChatHostQueryParameters { get }
    var categoryCodes:[String:String] { get }
    
    init(delegate:AssistiveChatHostMessagesDelegate?)
    func didTap(chatResult: ChatResult)
    func determineIntent(for caption:String, placeSearchResponse:PlaceSearchResponse?) throws -> AssistiveChatHost.Intent
    func appendIntentParameters(intent:AssistiveChatHostIntent)
    func resetIntentParameters()
    func receiveMessage(caption:String, isLocalParticipant:Bool, nearLocation:CLLocation ) async throws
}
