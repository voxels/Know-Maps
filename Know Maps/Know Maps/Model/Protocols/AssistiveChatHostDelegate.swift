//
//  AssistiveChatHostDelegate.swift
//  Know Maps
//
//  Created by Michael A Edgcumbe on 11/16/23.
//

import Foundation
import CoreLocation

public protocol AssistiveChatHostDelegate:AnyObject {
    
    var messagesDelegate:AssistiveChatHostMessagesDelegate? { get set}
    var languageDelegate:LanguageGeneratorDelegate { get }
    var placeSearchSession:PlaceSearchSession { get }
    var queryIntentParameters:AssistiveChatHostQueryParameters { get }
    var categoryCodes:[[String:[[String:String]]]] { get }
    
    init(delegate:AssistiveChatHostMessagesDelegate?)
    func organizeCategoryCodeList() throws
    func didTap(chatResult: ChatResult) async
    func determineIntent(for caption:String) -> AssistiveChatHost.Intent
    func updateLastIntentParameters(intent:AssistiveChatHostIntent)
    func appendIntentParameters(intent:AssistiveChatHostIntent)
    func resetIntentParameters()
    func receiveMessage(caption:String, isLocalParticipant:Bool ) async throws
    func defaultParameters(for query:String) async throws -> [String:Any]?
    func nearLocation(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> String?
    func nearLocationCoordinate(for rawQuery:String, tags:AssistiveChatHostTaggedWord?) async throws -> CLLocation?
    func tags(for rawQuery:String) throws ->AssistiveChatHostTaggedWord?
}
